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

    "! 템플릿 헤더 컬럼 목록. 실제 업로드 대상 필드명으로 바꿔 쓸 것.
    METHODS get_template_columns
      RETURNING
        VALUE(rt_columns) TYPE string_table.

ENDCLASS.


CLASS zcl_excel_table_migrator IMPLEMENTATION.

  METHOD migrate.

    " 1) 대상 테이블 구조를 RTTI로 조회.
    DATA(lo_target_struct) = CAST cl_abap_structdescr(
      cl_abap_structdescr=>describe_by_name( iv_tabname ) ).

    " 2) 엑셀을 받아둘 "전부 STRING" 중간 테이블을 만든다.
    "    XCO의 row_stream->write_to( )는 엑셀 컬럼을 대상 구조의 컴포넌트에
    "    순서대로 밀어넣기 때문에, 헤더 이름으로 매칭하려면 일단 타입 변환 없이
    "    string으로 받아놓고 우리가 직접 매칭해야 한다.
    "    컬럼 수는 대상 테이블 필드 수만큼 잡는다 (엑셀 컬럼이 그보다 적으면
    "    남는 건 빈 값, 많으면 초과분은 버려진다 - 마이그레이션 템플릿 기준 정상).
    DATA lt_string_comp TYPE cl_abap_structdescr=>component_table.
    LOOP AT lo_target_struct->components INTO DATA(ls_target_comp).
      APPEND VALUE #( name = |COL{ sy-tabix }|
                      type = cl_abap_elemdescr=>get_string( ) ) TO lt_string_comp.
    ENDLOOP.

    DATA(lo_string_table) = cl_abap_tabledescr=>create(
      cl_abap_structdescr=>create( lt_string_comp ) ).

    DATA lr_string_itab TYPE REF TO data.
    CREATE DATA lr_string_itab TYPE HANDLE lo_string_table.
    FIELD-SYMBOLS <lt_string_itab> TYPE INDEX TABLE.
    ASSIGN lr_string_itab->* TO <lt_string_itab>.

    " 3) XCO로 엑셀 파싱 -> 중간 테이블에 통째로 적재.
    "    첫 번째 워크시트 전체를 읽고, 셀 값은 전부 string으로 받는다.
    DATA(lo_worksheet) = xco_cp_xlsx=>document->for_file_content( iv_file_content
      )->read_access( )->get_workbook( )->worksheet->at_position( 1 ).

    DATA(lo_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->get_pattern( ).

    lo_worksheet->select( lo_pattern )->row_stream( )->operation->write_to( lr_string_itab
      )->set_value_transformation( xco_cp_xlsx_read_access=>value_transformation->string_value
      )->execute( ).

    IF lines( <lt_string_itab> ) < 2.
      RETURN.   " 헤더만 있거나 빈 시트
    ENDIF.

    " 4) 1행 = 헤더. 컬럼 위치 -> 대상 테이블 필드명 매핑을 만든다.
    READ TABLE <lt_string_itab> ASSIGNING FIELD-SYMBOL(<ls_header>) INDEX 1.

    TYPES: BEGIN OF ty_map,
             col_index TYPE i,
             fieldname TYPE fieldname,
           END OF ty_map.
    DATA lt_map TYPE STANDARD TABLE OF ty_map WITH EMPTY KEY.

    FIELD-SYMBOLS <lv_header_cell> TYPE any.

    LOOP AT lt_string_comp INTO DATA(ls_string_comp).
      DATA(lv_col_index) = sy-tabix.

      " ASSIGN이 실패하면 필드심볼은 할당되지 않은 채로 남는다.
      " sy-subrc와 값 검사를 한 조건에 묶으면 미할당 상태로 접근하게 되므로 분리한다.
      UNASSIGN <lv_header_cell>.
      ASSIGN COMPONENT ls_string_comp-name OF STRUCTURE <ls_header> TO <lv_header_cell>.

      IF <lv_header_cell> IS NOT ASSIGNED OR <lv_header_cell> IS INITIAL.
        CONTINUE.
      ENDIF.

      " 헤더 텍스트가 대상 테이블의 실제 필드명일 때만 매핑에 넣는다.
      DATA(lv_fieldname) = CONV fieldname( to_upper( condense( CONV string( <lv_header_cell> ) ) ) ).

      IF NOT line_exists( lo_target_struct->components[ name = lv_fieldname ] ).
        CONTINUE.
      ENDIF.

      APPEND VALUE #( col_index = lv_col_index fieldname = lv_fieldname ) TO lt_map.
    ENDLOOP.

    IF lt_map IS INITIAL.
      RETURN.   " 매칭되는 헤더가 하나도 없음 - 잘못된 파일
    ENDIF.

    " 5) 2행부터 데이터 -> 대상 테이블 타입의 내부테이블로 옮긴다.
    DATA lr_itab TYPE REF TO data.
    CREATE DATA lr_itab TYPE TABLE OF (iv_tabname).
    FIELD-SYMBOLS <lt_itab> TYPE INDEX TABLE.
    ASSIGN lr_itab->* TO <lt_itab>.

    DATA lr_wa TYPE REF TO data.
    CREATE DATA lr_wa TYPE (iv_tabname).
    ASSIGN lr_wa->* TO FIELD-SYMBOL(<ls_wa>).

    FIELD-SYMBOLS: <lv_cell>  TYPE any,
                   <lv_field> TYPE any.

    LOOP AT <lt_string_itab> ASSIGNING FIELD-SYMBOL(<ls_string_row>) FROM 2.

      CLEAR <ls_wa>.

      LOOP AT lt_map INTO DATA(ls_map).

        " 앞 반복에서 붙어있던 할당이 남지 않도록 매번 끊고 다시 붙인다.
        " 실패한 ASSIGN은 필드심볼을 그냥 미할당으로 두므로, 대입 직전에
        " 양쪽 다 할당됐는지 확인해야 한다.
        UNASSIGN: <lv_cell>, <lv_field>.

        ASSIGN COMPONENT ls_map-col_index OF STRUCTURE <ls_string_row> TO <lv_cell>.
        ASSIGN COMPONENT ls_map-fieldname OF STRUCTURE <ls_wa>         TO <lv_field>.

        IF <lv_cell> IS ASSIGNED AND <lv_field> IS ASSIGNED.
          <lv_field> = <lv_cell>.
        ENDIF.

      ENDLOOP.

      INSERT <ls_wa> INTO TABLE <lt_itab>.

    ENDLOOP.

    " 6) 동적 INSERT. 대상 테이블명은 호출부 책임 하에 신뢰된 값이어야 한다.
    INSERT (iv_tabname) FROM TABLE @<lt_itab>.

    IF sy-subrc = 0.
      rv_inserted = lines( <lt_itab> ).
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
