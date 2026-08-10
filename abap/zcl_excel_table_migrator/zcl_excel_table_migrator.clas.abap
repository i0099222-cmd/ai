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

    xco_cp_xlsx=>document->for_file_content( iv_file_content
      )->read_access( )->get_workbook( )->worksheet->at_position( 1
      )->select( xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( )
      )->row_stream( )->operation->write_to( lr_rows
      )->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
      )->execute( ).

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
