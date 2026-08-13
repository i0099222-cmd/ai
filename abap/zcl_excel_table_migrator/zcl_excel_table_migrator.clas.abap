"! 엑셀 업로드(xlsx 바이너리) -> 임의 테이블 동적 INSERT.
"! iv_tabname은 호출부에서 신뢰할 수 있는 값만 넘겨야 한다 - 이 클래스는 검증하지 않는다.
"!
"! 엑셀 형식 전제: 1행 = 헤더(대상 테이블 필드명), 2행부터 = 데이터.
"! 헤더 이름으로 필드를 매칭하므로 컬럼 순서는 달라도 되고, 일부 컬럼만 있어도 된다.
"! 대상 테이블에 없는 헤더는 무시한다.
CLASS zcl_excel_table_migrator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! 업로드 템플릿의 헤더 컬럼. 여기 이름이 곧 대상 테이블 필드명이 된다.
    "! TODO: 실제 대상 테이블 필드명으로 교체할 것.
    CONSTANTS:
      BEGIN OF gc_template,
        filename TYPE string VALUE 'migration_template.xlsx',
        mimetype TYPE string VALUE 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      END OF gc_template.

    "! errors가 비어 있지 않으면 아무것도 INSERT하지 않는다.
    "! 일부만 들어가면 파일을 고쳐 다시 올릴 때 무엇이 반영됐는지 알 수 없다.
    TYPES:
      BEGIN OF ty_result,
        inserted TYPE i,
        errors   TYPE string_table,
      END OF ty_result.

    "! xlsx와 CSV를 모두 받는다. 파일 종류는 내용으로 판별하므로 호출부는 신경 쓸 게 없다.
    "! CSV는 UTF-8만 읽는다. 엑셀에서 그냥 "CSV"로 저장하면 로컬 코드페이지(한국은 CP949)로
    "! 나오므로, 사용자에게 "CSV UTF-8"로 저장하도록 안내해야 한다.
    METHODS migrate
      IMPORTING
        iv_tabname       TYPE tabname
        iv_file_content  TYPE xstring
      RETURNING
        VALUE(rs_result) TYPE ty_result.

    "! 헤더 행만 채워진 빈 업로드 템플릿(xlsx)
    METHODS get_template
      RETURNING
        VALUE(rv_file_content) TYPE xstring.

  PRIVATE SECTION.

    "! CSV를 xlsx와 같은 모양(COL1..COLn 문자열 테이블)으로 읽어 넣는다.
    METHODS read_csv
      IMPORTING
        iv_file_content TYPE xstring
      CHANGING
        ct_rows         TYPE INDEX TABLE.

ENDCLASS.


CLASS zcl_excel_table_migrator IMPLEMENTATION.

  METHOD migrate.

    " ── 1) 대상 테이블 구조 ──────────────────────────────────────────
    DATA(lo_struct) = CAST cl_abap_structdescr(
      cl_abap_structdescr=>describe_by_name( iv_tabname ) ).

    " ── 2) 엑셀을 전부 string인 COL1..COLn 테이블로 읽는다 ───────────
    "      셀 값이 어떤 타입인지 모르므로 일단 string으로 받는다.
    DATA lt_components TYPE cl_abap_structdescr=>component_table.
    DO lines( lo_struct->components ) TIMES.
      APPEND VALUE #( name = |COL{ sy-index }|
                      type = cl_abap_elemdescr=>get_string( ) ) TO lt_components.
    ENDDO.

    DATA lr_rows TYPE REF TO data.
    CREATE DATA lr_rows TYPE HANDLE cl_abap_tabledescr=>create(
      cl_abap_structdescr=>create( lt_components ) ).

    FIELD-SYMBOLS <lt_rows> TYPE INDEX TABLE.
    ASSIGN lr_rows->* TO <lt_rows>.

    " xlsx는 ZIP이라 항상 'PK'로 시작한다. 아니면 CSV로 본다.
    IF xstrlen( iv_file_content ) >= 2 AND iv_file_content(2) = '504B'.

      xco_cp_xlsx=>document->for_file_content( iv_file_content
        )->read_access( )->get_workbook( )->worksheet->at_position( 1
        )->select( xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( )
        )->row_stream( )->operation->write_to( lr_rows
        )->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
        )->execute( ).

    ELSE.

      TRY.
          read_csv( EXPORTING iv_file_content = iv_file_content
                    CHANGING  ct_rows         = <lt_rows> ).

        CATCH cx_root.
          " UTF-8이 아닌 파일이면 여기로 온다. 덤프 대신 사용자가 할 수 있는 것을 알려준다.
          APPEND |CSV를 읽을 수 없습니다. 엑셀에서 "CSV UTF-8"로 저장해 다시 올려주세요|
                 TO rs_result-errors.
          RETURN.
      ENDTRY.

    ENDIF.

    IF lines( <lt_rows> ) < 2.
      RETURN.   " 헤더만 있거나 빈 시트
    ENDIF.

    " ── 3) 헤더 행으로 "컬럼 -> 필드명" 매핑 ─────────────────────────
    READ TABLE <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_header>) INDEX 1.

    TYPES: BEGIN OF ty_map,
             col   TYPE string,
             field TYPE string,
           END OF ty_map.
    DATA lt_map TYPE STANDARD TABLE OF ty_map WITH EMPTY KEY.

    FIELD-SYMBOLS: <lv_source> TYPE any,
                   <lv_target> TYPE any.

    LOOP AT lt_components INTO DATA(ls_component).

      " ASSIGN이 실패하면 필드심볼은 미할당으로 남는다. IS ASSIGNED로 확인해야 한다.
      UNASSIGN <lv_source>.
      ASSIGN COMPONENT ls_component-name OF STRUCTURE <ls_header> TO <lv_source>.
      CHECK <lv_source> IS ASSIGNED.

      DATA(lv_field) = to_upper( condense( CONV string( <lv_source> ) ) ).
      CHECK line_exists( lo_struct->components[ name = lv_field ] ).

      APPEND VALUE #( col = ls_component-name field = lv_field ) TO lt_map.

    ENDLOOP.

    IF lt_map IS INITIAL.
      RETURN.   " 매칭되는 헤더가 하나도 없음
    ENDIF.

    " ── 4) UUID 필드 목록 ───────────────────────────────────────────
    "      UUID 데이터엘리먼트(SYSUUID_X16, GUID_16, OS_GUID)는 전부 RAW16이다.
    DATA lt_uuid_fields TYPE string_table.
    LOOP AT lo_struct->components INTO ls_component
         WHERE type_kind = cl_abap_typedescr=>typekind_hex
           AND length    = 16.
      APPEND CONV string( ls_component-name ) TO lt_uuid_fields.
    ENDLOOP.

    " ── 4b) RAP 관리 필드 ───────────────────────────────────────────
    "       RAP BO를 거치면 determination이 채워주지만, 여기서는 직접 INSERT라
    "       아무도 안 채운다. 이름으로 찾아 우리가 넣는다.
    "       DB 필드는 CREATED_BY, CDS는 CreatedBy처럼 표기가 달라 밑줄을 지우고 비교한다.
    DATA lt_admin_user TYPE string_table.   " ...BY   - 사용자
    DATA lt_admin_ts   TYPE string_table.   " ...AT   - TIMESTAMPL(팩형)
    DATA lt_admin_utc  TYPE string_table.   " ...AT   - UTCLONG

    LOOP AT lo_struct->components INTO ls_component.

      DATA(lv_plain) = replace( val  = to_upper( CONV string( ls_component-name ) )
                                sub  = `_`
                                with = ``
                                occ  = 0 ).

      IF lv_plain = 'CREATEDBY' OR lv_plain = 'LASTCHANGEDBY' OR lv_plain = 'LOCALLASTCHANGEDBY'.
        APPEND CONV string( ls_component-name ) TO lt_admin_user.

      ELSEIF lv_plain = 'CREATEDAT' OR lv_plain = 'LASTCHANGEDAT' OR lv_plain = 'LOCALLASTCHANGEDAT'.
        " 같은 의미의 필드라도 테이블에 따라 UTCLONG이거나 TIMESTAMPL이라 대입할 값이 다르다.
        IF ls_component-type_kind = cl_abap_typedescr=>typekind_utclong.
          APPEND CONV string( ls_component-name ) TO lt_admin_utc.
        ELSE.
          APPEND CONV string( ls_component-name ) TO lt_admin_ts.
        ENDIF.
      ENDIF.

    ENDLOOP.

    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).
    DATA(lv_utclong) = utclong_current( ).
    GET TIME STAMP FIELD DATA(lv_timestamp).

    " ── 5) 행 복사 ──────────────────────────────────────────────────
    DATA lr_itab TYPE REF TO data.
    CREATE DATA lr_itab TYPE TABLE OF (iv_tabname).
    FIELD-SYMBOLS <lt_itab> TYPE INDEX TABLE.
    ASSIGN lr_itab->* TO <lt_itab>.

    DATA lr_wa TYPE REF TO data.
    CREATE DATA lr_wa TYPE (iv_tabname).
    ASSIGN lr_wa->* TO FIELD-SYMBOL(<ls_wa>).

    " 파일 안에 같은 데이터가 또 나왔는지 보기 위해, 매핑된 값을 이어붙인
    " 문자열을 기억해 둔다. UUID를 채우기 전 상태로 비교해야 한다 -
    " 채운 뒤에는 모든 행이 달라 보여서 아무것도 안 잡힌다.
    DATA lt_seen TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    LOOP AT <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_row>) FROM 2.

      DATA(lv_row_number) = sy-tabix.

      CLEAR <ls_wa>.

      " 값을 옮기면서 중복 비교용 문자열도 같이 만든다.
      DATA lv_line TYPE string.
      CLEAR lv_line.

      LOOP AT lt_map INTO DATA(ls_map).
        UNASSIGN: <lv_source>, <lv_target>.
        ASSIGN COMPONENT ls_map-col   OF STRUCTURE <ls_row> TO <lv_source>.
        ASSIGN COMPONENT ls_map-field OF STRUCTURE <ls_wa>  TO <lv_target>.

        IF <lv_source> IS ASSIGNED AND <lv_target> IS ASSIGNED.
          <lv_target> = <lv_source>.
          lv_line = |{ lv_line }~#~{ <lv_source> }|.
        ENDIF.
      ENDLOOP.

      " 엑셀 used range가 데이터보다 넓으면 뒤에 빈 행이 딸려온다.
      " UUID를 먼저 채우면 빈 행도 값이 있는 행이 되므로 반드시 이 위치에서 거른다.
      IF <ls_wa> IS INITIAL.
        CONTINUE.
      ENDIF.

      IF line_exists( lt_seen[ table_line = lv_line ] ).
        APPEND |{ lv_row_number }행: 중복된 데이터입니다| TO rs_result-errors.
        CONTINUE.
      ENDIF.

      INSERT lv_line INTO TABLE lt_seen.

      " 엑셀에서 값이 들어온 UUID는 그대로 두고, 비어 있을 때만 생성한다.
      LOOP AT lt_uuid_fields INTO DATA(lv_uuid_field).
        UNASSIGN <lv_target>.
        ASSIGN COMPONENT lv_uuid_field OF STRUCTURE <ls_wa> TO <lv_target>.

        IF <lv_target> IS ASSIGNED AND <lv_target> IS INITIAL.
          <lv_target> = cl_system_uuid=>create_uuid_x16_static( ).
        ENDIF.
      ENDLOOP.

      " 관리 필드는 시스템이 정하는 값이므로 엑셀에 뭐가 있든 덮어쓴다.
      LOOP AT lt_admin_user INTO DATA(lv_admin_field).
        UNASSIGN <lv_target>.
        ASSIGN COMPONENT lv_admin_field OF STRUCTURE <ls_wa> TO <lv_target>.
        IF <lv_target> IS ASSIGNED.
          <lv_target> = lv_user.
        ENDIF.
      ENDLOOP.

      LOOP AT lt_admin_utc INTO lv_admin_field.
        UNASSIGN <lv_target>.
        ASSIGN COMPONENT lv_admin_field OF STRUCTURE <ls_wa> TO <lv_target>.
        IF <lv_target> IS ASSIGNED.
          <lv_target> = lv_utclong.
        ENDIF.
      ENDLOOP.

      LOOP AT lt_admin_ts INTO lv_admin_field.
        UNASSIGN <lv_target>.
        ASSIGN COMPONENT lv_admin_field OF STRUCTURE <ls_wa> TO <lv_target>.
        IF <lv_target> IS ASSIGNED.
          <lv_target> = lv_timestamp.
        ENDIF.
      ENDLOOP.

      INSERT <ls_wa> INTO TABLE <lt_itab>.

    ENDLOOP.

    " ── 6) 한 번에 INSERT ───────────────────────────────────────────
    IF rs_result-errors IS NOT INITIAL OR <lt_itab> IS INITIAL.
      RETURN.
    ENDIF.

    INSERT (iv_tabname) FROM TABLE @<lt_itab>.

    IF sy-subrc = 0.
      rs_result-inserted = lines( <lt_itab> ).
    ELSE.
      " 키가 UUID가 아닌 테이블이면 DB에 이미 있는 키에서 여기로 떨어진다.
      APPEND |이미 등록된 데이터가 있어 INSERT에 실패했습니다| TO rs_result-errors.
    ENDIF.

  ENDMETHOD.


  METHOD read_csv.

    DATA(lv_bytes) = iv_file_content.

    " UTF-8 BOM은 떼지 않으면 첫 헤더 이름에 안 보이는 문자가 붙어 매칭이 실패한다.
    IF xstrlen( lv_bytes ) >= 3 AND lv_bytes(3) = 'EFBBBF'.
      lv_bytes = lv_bytes+3.
    ENDIF.

    " XCO는 릴리즈 API라 별도 래퍼 없이 쓸 수 있다.
    " 다른 코드페이지가 필요하면 ADT에서 xco_cp_character=>code_page-> 를 열어
    " 어떤 값이 제공되는지 확인할 것.
    DATA(lv_text) = xco_cp=>xstring( lv_bytes
      )->as_string( xco_cp_character=>code_page->utf_8 )->value.

    " 줄바꿈은 CRLF일 수도 LF일 수도 있다.
    REPLACE ALL OCCURRENCES OF |\r\n| IN lv_text WITH |\n|.
    SPLIT lv_text AT |\n| INTO TABLE DATA(lt_lines).

    " 구분자는 헤더 줄에서 가장 많이 나온 문자로 정한다.
    " 한국/유럽 로케일 엑셀은 CSV를 세미콜론으로, "유니코드 텍스트"는 탭으로 저장한다.
    READ TABLE lt_lines INTO DATA(lv_header) INDEX 1.

    DATA(lv_delimiter) = ','.
    DATA(lv_best) = count( val = lv_header sub = ',' ).

    IF count( val = lv_header sub = ';' ) > lv_best.
      lv_delimiter = ';'.
      lv_best      = count( val = lv_header sub = ';' ).
    ENDIF.

    IF count( val = lv_header sub = |\t| ) > lv_best.
      lv_delimiter = |\t|.
    ENDIF.

    FIELD-SYMBOLS <lv_cell> TYPE any.

    LOOP AT lt_lines INTO DATA(lv_line_text).

      " 파일 끝의 빈 줄은 건너뛴다.
      IF lv_line_text IS INITIAL.
        CONTINUE.
      ENDIF.

      APPEND INITIAL LINE TO ct_rows ASSIGNING FIELD-SYMBOL(<ls_new_row>).

      SPLIT lv_line_text AT lv_delimiter INTO TABLE DATA(lt_values).

      LOOP AT lt_values INTO DATA(lv_value).

        DATA(lv_column_index) = sy-tabix.

        UNASSIGN <lv_cell>.
        ASSIGN COMPONENT lv_column_index OF STRUCTURE <ls_new_row> TO <lv_cell>.

        " 대상 테이블 필드 수보다 컬럼이 많으면 초과분은 버린다.
        IF <lv_cell> IS ASSIGNED.
          <lv_cell> = lv_value.
        ENDIF.

      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.


  METHOD get_template.

    " 빈 워크북에 헤더 행만 채운다.
    DATA(lo_write) = xco_cp_xlsx=>document->empty( )->write_access( ).

    DATA(lo_cursor) = lo_write->get_workbook( )->worksheet->at_position( 1 )->cursor(
      io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
      io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( 1 ) ).

    " TODO: 실제 대상 테이블 필드명으로 교체할 것.
    LOOP AT VALUE string_table( ( `MANDT` ) ( `ID` ) ( `NAME` ) ( `AMOUNT` ) ( `CURRENCY` ) )
         INTO DATA(lv_column).

      IF sy-tabix > 1.
        lo_cursor = lo_cursor->move_right( ).
      ENDIF.
      lo_cursor->get_cell( )->value->write_from( lv_column ).

    ENDLOOP.

    rv_file_content = lo_write->get_file_content( ).

  ENDMETHOD.

ENDCLASS.
