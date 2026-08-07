"! 엑셀 업로드(xlsx 바이너리) -> 임의 테이블 동적 INSERT.
"! 화이트리스트/권한체크/백그라운드 잡 예약 등은 넣지 않은 단순 버전이다.
"! iv_tabname은 호출부에서 신뢰할 수 있는 값만 넘겨야 한다 - 이 클래스는 검증하지 않는다.
"!
"! 엑셀 파싱은 XCO_CP_XLSX를 쓴다. CL_FDT_XL_SPREADSHEET와 달리 ABAP Cloud에
"! 릴리즈된 API라서, RAP 액션에서 이 클래스를 직접 호출할 수 있고 Standard ABAP
"! 패키지 분리나 래퍼 FM이 필요 없다. (PCE/on-prem은 2020 이상부터 사용 가능)
"!
"! 엑셀 형식 전제: 1행 = 헤더(대상 테이블 필드명), 2행부터 = 데이터.
"! 헤더 이름으로 필드를 매칭하므로 컬럼 순서는 테이블 필드 순서와 달라도 되고,
"! 일부 컬럼만 있어도 된다 (대상 테이블에 없는 헤더는 무시).
CLASS zcl_excel_table_migrator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! 업로드 템플릿의 헤더 컬럼. 여기 이름이 곧 대상 테이블 필드명이 되고,
    "! migrate( )가 헤더 이름으로 필드를 매칭하므로 둘이 자동으로 맞아떨어진다.
    "! 템플릿을 바꾸려면 이 상수만 고치면 된다.
    CONSTANTS:
      BEGIN OF gc_template,
        filename TYPE string VALUE 'migration_template.xlsx',
        mimetype TYPE string VALUE 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      END OF gc_template.

    "! @parameter iv_tabname      | 데이터를 넣을 대상 테이블명
    "! @parameter iv_file_content | 업로드된 xlsx 파일 바이너리
    "! @parameter rv_inserted     | INSERT된 행 수
    METHODS migrate
      IMPORTING
        iv_tabname         TYPE tabname
        iv_file_content    TYPE xstring
      RETURNING
        VALUE(rv_inserted) TYPE i.

    "! 헤더 행만 채워진 빈 업로드 템플릿(xlsx)을 만들어 돌려준다.
    "! @parameter rv_file_content | 다운로드용 xlsx 바이너리
    METHODS get_template
      RETURNING
        VALUE(rv_file_content) TYPE xstring.

  PRIVATE SECTION.

    "! 대상 테이블에 없는 헤더 컬럼에 붙일 이름. 어떤 필드와도 매칭되지 않아
    "! MOVE-CORRESPONDING에서 자연스럽게 무시된다.
    CONSTANTS gc_unmapped_prefix TYPE string VALUE 'X_UNMAPPED_'.

    "! 시트를 지정한 컴포넌트 이름들로 읽어 내부테이블(ref)로 돌려준다.
    "! 컴포넌트는 전부 string이고, 엑셀 컬럼이 순서대로 그 자리에 들어간다.
    METHODS read_sheet
      IMPORTING
        io_worksheet     TYPE REF TO if_xco_xlsx_ra_worksheet
        it_column_names  TYPE string_table
      RETURNING
        VALUE(rr_rows)   TYPE REF TO data.

    "! 헤더 행을 읽어 컬럼마다 쓸 컴포넌트 이름을 정한다.
    "! 대상 테이블에 있는 필드명이면 그 이름 그대로, 없으면 더미 이름.
    "! 이 이름으로 시트를 다시 읽으면 대상 구조와 이름이 맞아떨어져서,
    "! 값 복사는 MOVE-CORRESPONDING 한 줄로 끝난다.
    METHODS derive_column_names
      IMPORTING
        ir_rows              TYPE REF TO data
        io_target_struct     TYPE REF TO cl_abap_structdescr
      RETURNING
        VALUE(rt_column_names) TYPE string_table.

    "! 템플릿 헤더 컬럼 목록. 실제 업로드 대상 필드명으로 바꿔 쓸 것.
    METHODS get_template_columns
      RETURNING
        VALUE(rt_columns) TYPE string_table.

ENDCLASS.


CLASS zcl_excel_table_migrator IMPLEMENTATION.

  METHOD migrate.

    DATA(lo_target_struct) = CAST cl_abap_structdescr(
      cl_abap_structdescr=>describe_by_name( iv_tabname ) ).

    DATA(lo_worksheet) = xco_cp_xlsx=>document->for_file_content( iv_file_content
      )->read_access( )->get_workbook( )->worksheet->at_position( 1 ).

    " 1차 읽기: 컬럼 이름을 아직 모르므로 COL1..COLn으로 읽어 헤더 행만 확인한다.
    DATA lt_generic_names TYPE string_table.
    DO lines( lo_target_struct->components ) TIMES.
      APPEND |COL{ sy-index }| TO lt_generic_names.
    ENDDO.

    DATA(lt_column_names) = derive_column_names(
      ir_rows          = read_sheet( io_worksheet    = lo_worksheet
                                     it_column_names = lt_generic_names )
      io_target_struct = lo_target_struct ).

    IF lt_column_names IS INITIAL.
      RETURN.   " 빈 시트이거나 매칭되는 헤더가 하나도 없음
    ENDIF.

    " 2차 읽기: 이번엔 컴포넌트 이름이 대상 테이블 필드명과 같으므로
    "           이후 값 복사에 필드심볼 조작이 필요 없다.
    DATA(lr_rows) = read_sheet( io_worksheet    = lo_worksheet
                                it_column_names = lt_column_names ).
    FIELD-SYMBOLS <lt_rows> TYPE INDEX TABLE.
    ASSIGN lr_rows->* TO <lt_rows>.

    DATA lr_itab TYPE REF TO data.
    CREATE DATA lr_itab TYPE TABLE OF (iv_tabname).
    FIELD-SYMBOLS <lt_itab> TYPE INDEX TABLE.
    ASSIGN lr_itab->* TO <lt_itab>.

    DATA lr_wa TYPE REF TO data.
    CREATE DATA lr_wa TYPE (iv_tabname).
    ASSIGN lr_wa->* TO FIELD-SYMBOL(<ls_wa>).

    " 1행은 헤더이므로 2행부터.
    LOOP AT <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_row>) FROM 2.
      CLEAR <ls_wa>.
      MOVE-CORRESPONDING <ls_row> TO <ls_wa>.
      INSERT <ls_wa> INTO TABLE <lt_itab>.
    ENDLOOP.

    " 대상 테이블명은 호출부 책임 하에 신뢰된 값이어야 한다.
    INSERT (iv_tabname) FROM TABLE @<lt_itab>.

    IF sy-subrc = 0.
      rv_inserted = lines( <lt_itab> ).
    ENDIF.

  ENDMETHOD.


  METHOD read_sheet.

    DATA lt_components TYPE cl_abap_structdescr=>component_table.
    LOOP AT it_column_names INTO DATA(lv_column_name).
      APPEND VALUE #( name = lv_column_name
                      type = cl_abap_elemdescr=>get_string( ) ) TO lt_components.
    ENDLOOP.

    DATA(lo_table_type) = cl_abap_tabledescr=>create(
      cl_abap_structdescr=>create( lt_components ) ).

    CREATE DATA rr_rows TYPE HANDLE lo_table_type.

    DATA(lo_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).

    io_worksheet->select( lo_pattern )->row_stream( )->operation->write_to( rr_rows
      )->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
      )->execute( ).

  ENDMETHOD.


  METHOD derive_column_names.

    FIELD-SYMBOLS <lt_rows> TYPE INDEX TABLE.
    ASSIGN ir_rows->* TO <lt_rows>.

    IF <lt_rows> IS NOT ASSIGNED OR lines( <lt_rows> ) < 2.
      RETURN.   " 헤더만 있거나 빈 시트
    ENDIF.

    READ TABLE <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_header>) INDEX 1.

    DATA(lo_header_struct) = CAST cl_abap_structdescr(
      cl_abap_typedescr=>describe_by_data( <ls_header> ) ).

    DATA(lv_matched) = abap_false.
    FIELD-SYMBOLS <lv_cell> TYPE any.

    LOOP AT lo_header_struct->components INTO DATA(ls_component).
      DATA(lv_index) = sy-tabix.

      " ASSIGN이 실패하면 필드심볼은 미할당으로 남으므로 값 접근 전에 확인한다.
      UNASSIGN <lv_cell>.
      ASSIGN COMPONENT ls_component-name OF STRUCTURE <ls_header> TO <lv_cell>.

      DATA lv_header_text TYPE string.
      CLEAR lv_header_text.
      IF <lv_cell> IS ASSIGNED.
        lv_header_text = to_upper( condense( CONV string( <lv_cell> ) ) ).
      ENDIF.

      " 대상 테이블에 같은 이름의 필드가 있을 때만 그 이름을 쓴다.
      IF lv_header_text IS NOT INITIAL
         AND line_exists( io_target_struct->components[ name = lv_header_text ] ).
        APPEND lv_header_text TO rt_column_names.
        lv_matched = abap_true.
      ELSE.
        APPEND |{ gc_unmapped_prefix }{ lv_index }| TO rt_column_names.
      ENDIF.
    ENDLOOP.

    IF lv_matched = abap_false.
      CLEAR rt_column_names.   " 쓸 만한 헤더가 하나도 없음
    ENDIF.

  ENDMETHOD.


  METHOD get_template_columns.

    " TODO: 실제 업로드 대상 테이블의 필드명으로 교체할 것.
    "       여기 적힌 이름이 그대로 엑셀 1행(헤더)에 들어간다.
    rt_columns = VALUE #(
      ( `MANDT` )
      ( `ID` )
      ( `NAME` )
      ( `AMOUNT` )
      ( `CURRENCY` ) ).

  ENDMETHOD.


  METHOD get_template.

    " 빈 워크북을 새로 만들어 1행에 헤더만 채운다.
    DATA(lo_write_access) = xco_cp_xlsx=>document->empty( )->write_access( ).
    DATA(lo_worksheet)    = lo_write_access->get_workbook( )->worksheet->at_position( 1 ).

    " A1에서 시작해서 컬럼 하나 쓸 때마다 오른쪽으로 한 칸씩 이동.
    DATA(lo_cursor) = lo_worksheet->cursor(
      io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
      io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( 1 ) ).

    LOOP AT get_template_columns( ) INTO DATA(lv_column).
      IF sy-tabix > 1.
        lo_cursor = lo_cursor->move_right( ).
      ENDIF.
      lo_cursor->get_cell( )->value->write_from( lv_column ).
    ENDLOOP.

    rv_file_content = lo_write_access->get_file_content( ).

  ENDMETHOD.

ENDCLASS.
