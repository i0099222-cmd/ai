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

    "! 잘못된 셀 하나. 엑셀 행 번호를 그대로 담아 사용자가 파일에서 바로 찾을 수 있게 한다.
    TYPES:
      BEGIN OF ty_row_error,
        row_number TYPE i,
        fieldname  TYPE string,
        value      TYPE string,
        message    TYPE string,
      END OF ty_row_error,
      tt_row_error TYPE STANDARD TABLE OF ty_row_error WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_result,
        "! INSERT가 실제로 성공했는지. 커밋 여부는 호출부가 이 값으로 판단한다.
        "! 넣을 행이 없었거나 오류로 중단된 경우에도 abap_false다.
        db_ok    TYPE abap_bool,
        inserted TYPE i,
        failed   TYPE i,
        errors   TYPE tt_row_error,
      END OF ty_result.

    "! @parameter iv_tabname           | 데이터를 넣을 대상 테이블명
    "! @parameter iv_file_content      | 업로드된 xlsx 파일 바이너리
    "! @parameter it_keep_initial      | UUID여도 자동 생성하지 않을 필드명.
    "!                                   부모 참조 UUID처럼 값이 정해져 있어야 하는
    "!                                   필드에 임의 UUID가 박히는 것을 막는다.
    "! @parameter iv_skip_invalid_rows | abap_false(기본)면 잘못된 행이 하나라도 있을 때
    "!                                   아무것도 INSERT하지 않는다. 파일을 고쳐 다시 올리게
    "!                                   해서 부분 반영 상태를 피하기 위한 기본값이다.
    "!                                   abap_true면 정상 행만 넣고 나머지는 errors로 돌려준다.
    "! @parameter it_key_fields        | 파일 내 중복 판정에 쓸 업무 키.
    "!                                   비우면 DDIC 키를 쓰되, 우리가 생성하는 UUID 필드는
    "!                                   매번 값이 달라 판정에 쓸 수 없으므로 제외한다.
    "!                                   그래서 키가 UUID뿐인 테이블은 중복 검사가 불가능하고,
    "!                                   그때는 업무 키를 여기에 직접 넘겨야 한다.
    "! @parameter rs_result            | INSERT 건수, 실패 건수, 행/필드별 오류 목록
    METHODS migrate
      IMPORTING
        iv_tabname           TYPE tabname
        iv_file_content      TYPE xstring
        it_keep_initial      TYPE string_table OPTIONAL
        iv_skip_invalid_rows TYPE abap_bool DEFAULT abap_false
        it_key_fields        TYPE string_table OPTIONAL
      RETURNING
        VALUE(rs_result)     TYPE ty_result.

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

    "! 대상 구조에서 UUID 필드(RAW16)를 찾아 이름을 돌려준다.
    "! SYSUUID_X16 / GUID_16 / OS_GUID 등이 전부 RAW16이라 타입만으로 구분된다.
    METHODS find_uuid_fields
      IMPORTING
        io_struct       TYPE REF TO cl_abap_structdescr
        it_keep_initial TYPE string_table
      RETURNING
        VALUE(rt_fields) TYPE string_table.

    "! 비어 있는 UUID 필드를 새로 생성한 값으로 채운다.
    "! 엑셀에서 값이 들어온 필드는 건드리지 않는다.
    METHODS fill_uuid_fields
      IMPORTING
        it_fields TYPE string_table
      CHANGING
        cs_row    TYPE any.

    "! 키 값들을 이어붙일 때 쓰는 구분자. 값 안에 우연히 나타나기 어려운 문자를 쓴다.
    CONSTANTS gc_key_separator TYPE string VALUE '|#|'.

    TYPES tt_key_hash TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.

    "! 대상 테이블에 이미 있는 키들을 읽어 해시로 돌려준다.
    METHODS find_existing_keys
      IMPORTING
        iv_tabname     TYPE tabname
        it_key_fields  TYPE string_table
      RETURNING
        VALUE(rt_keys) TYPE tt_key_hash.

    "! DDIC 키 필드 이름을 돌려준다 (클라이언트 필드 제외).
    METHODS get_ddic_key_fields
      IMPORTING
        iv_tabname          TYPE tabname
      RETURNING
        VALUE(rt_key_fields) TYPE string_table.

    "! 한 행의 키 값들을 하나의 문자열로 만든다. 중복 판정용.
    METHODS build_key_string
      IMPORTING
        is_row         TYPE any
        it_key_fields  TYPE string_table
      RETURNING
        VALUE(rv_key)  TYPE string.

    "! 행 전체 복사가 실패했을 때, 그 행만 필드 단위로 다시 훑어
    "! 어느 필드의 어떤 값이 문제였는지 찾아낸다.
    "! 실패한 행에서만 호출되므로 느린 경로여도 전체 성능에 영향이 없다.
    METHODS describe_row_errors
      IMPORTING
        is_source        TYPE any
        is_target        TYPE any
        iv_row_number    TYPE i
      RETURNING
        VALUE(rt_errors) TYPE tt_row_error.

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

    DATA(lt_uuid_fields) = find_uuid_fields( io_struct       = lo_target_struct
                                             it_keep_initial = it_keep_initial ).

    " 중복 판정 키를 정한다. 호출부가 업무 키를 준 경우 그대로 쓰고,
    " 아니면 DDIC 키에서 우리가 생성하는 UUID 필드를 걷어낸 것을 쓴다.
    " (생성 UUID는 행마다 값이 달라 중복 판정 기준이 될 수 없다)
    DATA(lt_dup_key_fields) = it_key_fields.

    IF lt_dup_key_fields IS INITIAL.
      lt_dup_key_fields = get_ddic_key_fields( iv_tabname ).
      LOOP AT lt_uuid_fields INTO DATA(lv_uuid_field).
        DELETE lt_dup_key_fields WHERE table_line = lv_uuid_field.
      ENDLOOP.
    ENDIF.

    " 파일 안에서 이미 나온 키를 기억해 두고, 다시 나오면 몇 행과 겹치는지 알려준다.
    TYPES: BEGIN OF ty_seen_key,
             key        TYPE string,
             row_number TYPE i,
           END OF ty_seen_key.
    DATA lt_seen_keys TYPE HASHED TABLE OF ty_seen_key WITH UNIQUE KEY key.

    " DB에 이미 있는 키는 한 번만 읽어두고 행마다 메모리에서 대조한다.
    DATA lt_existing_keys TYPE tt_key_hash.
    IF lt_dup_key_fields IS NOT INITIAL.
      lt_existing_keys = find_existing_keys( iv_tabname    = iv_tabname
                                             it_key_fields = lt_dup_key_fields ).
    ENDIF.

    " 1행은 헤더이므로 2행부터. sy-tabix가 곧 엑셀 행 번호라 그대로 오류에 담는다.
    LOOP AT <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_row>) FROM 2.

      DATA(lv_row_number) = sy-tabix.

      CLEAR <ls_wa>.

      TRY.
          MOVE-CORRESPONDING <ls_row> TO <ls_wa>.

        CATCH cx_sy_conversion_error.
          " 행 전체 복사는 어느 필드가 문제인지 알려주지 않으므로,
          " 이 행만 필드 단위로 다시 훑어 위치를 특정한다.
          APPEND LINES OF describe_row_errors( is_source     = <ls_row>
                                               is_target     = <ls_wa>
                                               iv_row_number = lv_row_number )
                 TO rs_result-errors.
          rs_result-failed = rs_result-failed + 1.
          CONTINUE.
      ENDTRY.

      " 엑셀의 used range가 실제 데이터보다 넓으면 뒤에 빈 행이 딸려온다.
      " UUID를 먼저 채우면 그 빈 행도 값이 있는 행이 되어 UUID만 든 레코드가
      " 생기므로, 빈 행 판정을 반드시 UUID 채우기 앞에서 한다.
      IF <ls_wa> IS INITIAL.
        CONTINUE.
      ENDIF.

      " 중복 판정은 UUID를 채우기 전에 한다. 채운 뒤에는 모든 행의 키가
      " 달라져서 어떤 중복도 잡히지 않는다.
      IF lt_dup_key_fields IS NOT INITIAL.

        DATA(lv_key) = build_key_string( is_row        = <ls_wa>
                                         it_key_fields = lt_dup_key_fields ).

        DATA(lv_key_fields_text) = concat_lines_of( table = lt_dup_key_fields sep = `, ` ).

        DATA(ls_seen) = VALUE ty_seen_key( lt_seen_keys[ key = lv_key ] OPTIONAL ).

        IF ls_seen-row_number IS NOT INITIAL.
          APPEND VALUE #( row_number = lv_row_number
                          fieldname  = lv_key_fields_text
                          value      = lv_key
                          message    = |{ ls_seen-row_number }행과 키가 중복됩니다| )
                 TO rs_result-errors.
          rs_result-failed = rs_result-failed + 1.
          CONTINUE.
        ENDIF.

        IF line_exists( lt_existing_keys[ table_line = lv_key ] ).
          APPEND VALUE #( row_number = lv_row_number
                          fieldname  = lv_key_fields_text
                          value      = lv_key
                          message    = |이미 등록된 키입니다| )
                 TO rs_result-errors.
          rs_result-failed = rs_result-failed + 1.
          CONTINUE.
        ENDIF.

        INSERT VALUE #( key = lv_key row_number = lv_row_number ) INTO TABLE lt_seen_keys.

      ENDIF.

      fill_uuid_fields( EXPORTING it_fields = lt_uuid_fields
                        CHANGING  cs_row    = <ls_wa> ).

      INSERT <ls_wa> INTO TABLE <lt_itab>.

    ENDLOOP.

    " 기본값은 전부 아니면 전무다. 일부만 들어간 상태로 두면 사용자가 파일을 고쳐
    " 다시 올릴 때 무엇이 이미 반영됐는지 알 수 없어 중복이 생긴다.
    IF rs_result-errors IS NOT INITIAL AND iv_skip_invalid_rows = abap_false.
      RETURN.
    ENDIF.

    IF <lt_itab> IS INITIAL.
      RETURN.   " 넣을 행이 없음 - db_ok는 abap_false로 남는다
    ENDIF.

    " 대상 테이블명은 호출부 책임 하에 신뢰된 값이어야 한다.
    INSERT (iv_tabname) FROM TABLE @<lt_itab>.

    " sy-subrc는 다음 문장에서 덮이므로 INSERT 직후에 확정한다.
    rs_result-db_ok = xsdbool( sy-subrc = 0 ).

    IF rs_result-db_ok = abap_true.
      rs_result-inserted = lines( <lt_itab> ).
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


  METHOD find_uuid_fields.

    LOOP AT io_struct->components INTO DATA(ls_component).

      " UUID 데이터엘리먼트(SYSUUID_X16, GUID_16, OS_GUID ...)는 전부 RAW16이다.
      " 반대로 RAW16인데 UUID가 아닌 필드는 실무에서 거의 없다.
      IF ls_component-type_kind <> cl_abap_typedescr=>typekind_hex
         OR ls_component-length <> 16.
        CONTINUE.
      ENDIF.

      " 호출부가 제외하라고 지정한 필드는 건너뛴다 (부모 참조 UUID 등).
      IF line_exists( it_keep_initial[ table_line = CONV string( ls_component-name ) ] ).
        CONTINUE.
      ENDIF.

      APPEND CONV string( ls_component-name ) TO rt_fields.

    ENDLOOP.

  ENDMETHOD.


  METHOD fill_uuid_fields.

    FIELD-SYMBOLS <lv_uuid> TYPE any.

    LOOP AT it_fields INTO DATA(lv_fieldname).

      UNASSIGN <lv_uuid>.
      ASSIGN COMPONENT lv_fieldname OF STRUCTURE cs_row TO <lv_uuid>.

      " 엑셀에서 값이 들어온 경우는 그대로 두고, 비어 있을 때만 새로 만든다.
      IF <lv_uuid> IS ASSIGNED AND <lv_uuid> IS INITIAL.
        <lv_uuid> = cl_system_uuid=>create_uuid_x16_static( ).
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD get_ddic_key_fields.

    TRY.
        DATA(lo_table) = xco_cp_abap_dictionary=>database_table(
          CONV sxco_dbt_object_name( iv_tabname ) ).

        LOOP AT lo_table->fields->all->get( ) INTO DATA(lo_field).

          IF lo_field->content( )->get_key_indicator( ) <> abap_true.
            CONTINUE.
          ENDIF.

          " 클라이언트 필드는 모든 행이 같은 값이라 중복 판정에 의미가 없다.
          DATA(lv_name) = to_upper( CONV string( lo_field->name ) ).
          IF lv_name = 'MANDT' OR lv_name = 'CLIENT'.
            CONTINUE.
          ENDIF.

          APPEND lv_name TO rt_key_fields.

        ENDLOOP.

      CATCH cx_root.
        " 키를 못 읽으면 중복 검사만 건너뛴다. 마이그레이션 자체를 막을 이유는 없다.
        CLEAR rt_key_fields.
    ENDTRY.

  ENDMETHOD.


  METHOD find_existing_keys.

    " 대상 테이블과 키 필드가 모두 런타임에 정해지므로, 키 컬럼만 읽어와
    " 메모리에서 대조한다. 행마다 SELECT하면 5천 건에 5천 번이라 쓸 수 없고,
    " 동적 테이블에 FOR ALL ENTRIES를 거는 것보다 형태가 단순하고 예측 가능하다.
    "
    " 다만 대상 테이블 전체의 키 컬럼을 읽으므로, 테이블이 아주 크면
    " 이 SELECT가 무거워진다. 그 경우 업무 키 앞자리로 범위를 좁히는 식의
    " 보완이 필요하다.
    DATA lr_existing TYPE REF TO data.
    CREATE DATA lr_existing TYPE TABLE OF (iv_tabname).
    FIELD-SYMBOLS <lt_existing> TYPE INDEX TABLE.
    ASSIGN lr_existing->* TO <lt_existing>.

    TRY.
        SELECT DISTINCT (it_key_fields)
          FROM (iv_tabname)
          INTO CORRESPONDING FIELDS OF TABLE @<lt_existing>.

      CATCH cx_sy_dynamic_osql_error.
        " 조회에 실패하면 중복 검사만 포기한다. INSERT 시 DB 제약이 최종 방어선이다.
        RETURN.
    ENDTRY.

    LOOP AT <lt_existing> ASSIGNING FIELD-SYMBOL(<ls_existing>).
      INSERT build_key_string( is_row        = <ls_existing>
                               it_key_fields = it_key_fields )
        INTO TABLE rt_keys.
    ENDLOOP.

  ENDMETHOD.


  METHOD build_key_string.

    FIELD-SYMBOLS <lv_value> TYPE any.

    LOOP AT it_key_fields INTO DATA(lv_fieldname).

      UNASSIGN <lv_value>.
      ASSIGN COMPONENT lv_fieldname OF STRUCTURE is_row TO <lv_value>.

      IF <lv_value> IS ASSIGNED.
        rv_key = |{ rv_key }{ gc_key_separator }{ <lv_value> }|.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD describe_row_errors.

    " 대상과 같은 타입의 임시 구조에 한 필드씩 옮겨보며 실패 지점을 찾는다.
    " 호출부의 <ls_wa>를 건드리지 않으려고 별도 인스턴스를 쓴다.
    DATA lr_scratch TYPE REF TO data.
    CREATE DATA lr_scratch LIKE is_target.
    ASSIGN lr_scratch->* TO FIELD-SYMBOL(<ls_scratch>).

    DATA(lo_source_struct) = CAST cl_abap_structdescr(
      cl_abap_typedescr=>describe_by_data( is_source ) ).

    FIELD-SYMBOLS: <lv_source_cell> TYPE any,
                   <lv_target_field> TYPE any.

    LOOP AT lo_source_struct->components INTO DATA(ls_component).

      UNASSIGN: <lv_source_cell>, <lv_target_field>.
      ASSIGN COMPONENT ls_component-name OF STRUCTURE is_source    TO <lv_source_cell>.
      ASSIGN COMPONENT ls_component-name OF STRUCTURE <ls_scratch> TO <lv_target_field>.

      " 대상에 없는 컬럼은 애초에 복사 대상이 아니므로 오류가 아니다.
      IF <lv_source_cell> IS NOT ASSIGNED OR <lv_target_field> IS NOT ASSIGNED.
        CONTINUE.
      ENDIF.

      TRY.
          <lv_target_field> = <lv_source_cell>.

        CATCH cx_sy_conversion_error INTO DATA(lx_conversion).
          APPEND VALUE #( row_number = iv_row_number
                          fieldname  = CONV string( ls_component-name )
                          value      = <lv_source_cell>
                          message    = lx_conversion->get_text( ) ) TO rt_errors.
      ENDTRY.

    ENDLOOP.

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
