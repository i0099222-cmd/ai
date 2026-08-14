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
    "! @parameter iv_codepage | CSV 인코딩. 비우면 UTF-8 -> 8500(한국어) 순으로 시도한다.
    "!                          엑셀의 "CSV(쉼표로 분리)"는 한국 환경에서 8500으로 저장된다.
    METHODS migrate
      IMPORTING
        iv_tabname       TYPE tabname
        iv_file_content  TYPE xstring
        iv_codepage      TYPE string OPTIONAL
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
        iv_codepage     TYPE string
      CHANGING
        ct_rows         TYPE INDEX TABLE.

    "! 바이트를 문자열로 바꾼다. 후보 코드페이지를 순서대로 시도한다.
    METHODS decode
      IMPORTING
        iv_bytes       TYPE xstring
        iv_codepage    TYPE string
      RETURNING
        VALUE(rv_text) TYPE string.

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

      read_csv( EXPORTING iv_file_content = iv_file_content
                          iv_codepage     = iv_codepage
                CHANGING  ct_rows         = <lt_rows> ).

      IF <lt_rows> IS INITIAL.
        " 후보 코드페이지로 전부 읽히지 않은 경우. 형식이 아니라 인코딩 문제다.
        APPEND |파일 인코딩을 인식하지 못했습니다. iv_codepage에 코드페이지를 지정해 주세요|
               TO rs_result-errors.
        RETURN.
      ENDIF.

    ENDIF.

    IF lines( <lt_rows> ) < 2.
      RETURN.   " 헤더만 있거나 빈 시트
    ENDIF.

    " ── 3) 우리가 채우는 필드 ────────────────────────────────────────
    "      UUID 데이터엘리먼트(SYSUUID_X16, GUID_16, OS_GUID)는 전부 RAW16이다.
    DATA lt_uuid_fields TYPE string_table.
    LOOP AT lo_struct->components INTO DATA(ls_field)
         WHERE type_kind = cl_abap_typedescr=>typekind_hex
           AND length    = 16.
      APPEND CONV string( ls_field-name ) TO lt_uuid_fields.
    ENDLOOP.

    "      모든 대상 테이블이 같은 이름으로 이 여섯 필드를 가지므로 목록을 고정한다.
    "      RAP BO를 거치면 determination이 채우지만 여기서는 직접 INSERT라 아무도
    "      안 채운다. 타임스탬프는 전부 TSTMPL(=TIMESTAMPL)이라 값이 하나로 통일된다.
    DATA(lt_admin_user) = VALUE string_table( ( `CREATEDBY` )
                                              ( `LOCALLASTCHANGEDBY` )
                                              ( `LASTCHANGEDBY` ) ).

    DATA(lt_admin_time) = VALUE string_table( ( `CREATEDAT` )
                                              ( `LOCALLASTCHANGEDAT` )
                                              ( `LASTCHANGEDAT` ) ).

    " 파일이 반드시 담고 있어야 할 필드. 우리가 채우는 것들만 빼고 전부다.
    " 몇 개만 맞아도 통과시키면, 모든 테이블이 공통으로 갖는 CREATEDBY 같은
    " 필드 때문에 엉뚱한 테이블에 올려도 넘어가 버린다.
    DATA lt_required TYPE string_table.

    LOOP AT lo_struct->components INTO ls_field.

      DATA(lv_name) = to_upper( CONV string( ls_field-name ) ).

      IF lv_name = 'MANDT' OR lv_name = 'CLIENT'
         OR line_exists( lt_uuid_fields[ table_line = lv_name ] )
         OR line_exists( lt_admin_user[ table_line = lv_name ] )
         OR line_exists( lt_admin_time[ table_line = lv_name ] ).
        CONTINUE.
      ENDIF.

      APPEND lv_name TO lt_required.

    ENDLOOP.

    " ── 4) 헤더 행으로 "컬럼 -> 필드명" 매핑 ─────────────────────────
    READ TABLE <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_header>) INDEX 1.

    TYPES: BEGIN OF ty_map,
             col   TYPE string,
             field TYPE string,
           END OF ty_map.
    DATA lt_map TYPE STANDARD TABLE OF ty_map WITH EMPTY KEY.

    FIELD-SYMBOLS: <lv_source> TYPE any,
                   <lv_target> TYPE any.

    " 대상 테이블에 없는 헤더는 잘못된 템플릿을 올렸다는 신호다.
    " 조용히 버리면 사용자는 그 컬럼이 왜 안 들어갔는지 알 수 없으므로 모아서 알려준다.
    DATA lt_unknown TYPE string_table.

    LOOP AT lt_components INTO DATA(ls_component).

      " ASSIGN이 실패하면 필드심볼은 미할당으로 남는다. IS ASSIGNED로 확인해야 한다.
      UNASSIGN <lv_source>.
      ASSIGN COMPONENT ls_component-name OF STRUCTURE <ls_header> TO <lv_source>.
      CHECK <lv_source> IS ASSIGNED.

      DATA(lv_field) = to_upper( condense( CONV string( <lv_source> ) ) ).

      " 헤더 칸이 비어 있는 건 컬럼 수가 대상 테이블보다 적다는 뜻이라 오류가 아니다.
      IF lv_field IS INITIAL.
        CONTINUE.
      ENDIF.

      IF NOT line_exists( lo_struct->components[ name = lv_field ] ).
        APPEND lv_field TO lt_unknown.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( col = ls_component-name field = lv_field ) TO lt_map.

    ENDLOOP.

    IF lt_map IS INITIAL.
      APPEND |파일의 헤더가 { iv_tabname } 필드명과 하나도 맞지 않습니다. | &&
             |1행에 대상 테이블의 필드명이 들어있는지 확인해 주세요|
             TO rs_result-errors.
      RETURN.
    ENDIF.

    IF lt_unknown IS NOT INITIAL.
      APPEND |{ iv_tabname }에 없는 컬럼입니다: | &&
             |{ concat_lines_of( table = lt_unknown sep = `, ` ) }|
             TO rs_result-errors.
      RETURN.
    ENDIF.

    " 대상 테이블 필드가 파일에 빠져 있는 경우. 위의 unknown 검사와 짝을 이뤄
    " "파일 컬럼 = 대상 테이블 필드"가 정확히 일치할 때만 통과시킨다.
    DATA lt_missing TYPE string_table.

    LOOP AT lt_required INTO DATA(lv_required).
      IF NOT line_exists( lt_map[ field = lv_required ] ).
        APPEND lv_required TO lt_missing.
      ENDIF.
    ENDLOOP.

    IF lt_missing IS NOT INITIAL.
      APPEND |파일에 없는 필드입니다: | &&
             |{ concat_lines_of( table = lt_missing sep = `, ` ) }|
             TO rs_result-errors.
      RETURN.
    ENDIF.

    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).
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

      LOOP AT lt_admin_time INTO lv_admin_field.
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


  METHOD decode.

    " ABAP Cloud에서 쓸 수 있는 변환기는 XCO뿐이고 XCO는 UTF-8만 다룬다.
    " CL_ABAP_CONV_CODEPAGE는 RAP/ABAP Cloud에서 허용되지 않는다.
    "
    " UTF-8을 먼저 시도하는 이유: 한국어 코드페이지 바이트는 UTF-8로 읽으면 대개
    " 실패하지만, UTF-8 바이트는 한국어 코드페이지로 읽으면 실패하지 않고 조용히
    " 깨진 글자가 된다. 실패하는 쪽을 먼저 걸러야 오해석이 통과하지 않는다.
    TRY.
        rv_text = xco_cp=>xstring( iv_bytes
          )->as_string( xco_cp_character=>code_page->utf_8 )->value.
        RETURN.

      CATCH cx_root.
        " UTF-8이 아니다. 아래 FM으로 넘어간다.
    ENDTRY.

    " 한국어 코드페이지는 클라우드 API로 읽을 수 없어 Standard ABAP FM에 위임한다.
    " (Local API로 릴리즈해야 여기서 호출된다 - z_csv_to_string.abap 참고)
    DATA(lv_codepage) = COND string( WHEN iv_codepage IS INITIAL
                                     THEN `8500`          " SAP 한국어 코드페이지
                                     ELSE iv_codepage ).

    CALL FUNCTION 'Z_CSV_TO_STRING'
      EXPORTING
        iv_bytes          = iv_bytes
        iv_codepage       = lv_codepage
      IMPORTING
        ev_text           = rv_text
      EXCEPTIONS
        conversion_failed = 1
        OTHERS            = 2.

    IF sy-subrc <> 0.
      CLEAR rv_text.   " 호출부가 빈 값을 보고 오류로 처리한다
    ENDIF.

  ENDMETHOD.


  METHOD read_csv.

    DATA(lv_bytes) = iv_file_content.

    " UTF-8 BOM은 떼지 않으면 첫 헤더 이름에 안 보이는 문자가 붙어 매칭이 실패한다.
    IF xstrlen( lv_bytes ) >= 3 AND lv_bytes(3) = 'EFBBBF'.
      lv_bytes = lv_bytes+3.
    ENDIF.

    DATA(lv_text) = decode( iv_bytes    = lv_bytes
                            iv_codepage = iv_codepage ).

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
