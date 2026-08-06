"! 엑셀 업로드(xlsx 바이너리) -> 임의 테이블 동적 INSERT.
"! 화이트리스트/권한체크/백그라운드 잡 예약 등은 넣지 않은 단순 버전이다.
"! iv_tabname은 호출부에서 신뢰할 수 있는 값만 넘겨야 한다(예: 액션에서
"! 고정된 몇 개 테이블 중 하나만 고르게 하는 등) - 이 클래스 자체는 검증하지 않는다.
"!
"! 동적 테이블명 INSERT(INSERT (tabname) ...)와 엑셀 파싱(CL_FDT_XL_SPREADSHEET)은
"! ABAP Cloud 릴리즈 API가 아니므로, 이 클래스는 Standard ABAP 언어버전
"! 패키지에 둬야 한다. RAP 액션(ABAP Cloud)에서 직접 부르려면 이 클래스를
"! 감싸는 Local Release 함수모듈이 하나 더 필요하다 (zcl_parked_doc_poster가
"! CALL TRANSACTION을 FM으로 분리한 것과 같은 이유).
CLASS zcl_excel_table_migrator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! @parameter iv_tabname      | 데이터를 넣을 대상 테이블명
    "! @parameter iv_file_content | 업로드된 xlsx 파일 바이너리
    "! @parameter iv_header_row   | 헤더(필드명) 행 번호, 기본 1행
    "! @parameter rv_inserted     | INSERT된 행 수
    METHODS migrate
      IMPORTING
        iv_tabname       TYPE tabname
        iv_file_content  TYPE xstring
        iv_header_row    TYPE i DEFAULT 1
      RETURNING
        VALUE(rv_inserted) TYPE i
      RAISING
        cx_fdt_spreadsheet.

  PRIVATE SECTION.

    "! 엑셀 한 행을 STRING_TABLE(셀 값을 컬럼 순서대로)로 변환.
    "! GET_ITAB_FROM_WORKSHEET가 돌려주는 행 타입이 시스템마다 다를 수 있으므로,
    "! 실제 확인 후 이 메서드만 맞춰 고치면 된다 (호출부는 그대로 둬도 됨).
    METHODS row_to_strings
      IMPORTING
        is_row           TYPE any
      RETURNING
        VALUE(rt_values) TYPE string_table.

ENDCLASS.


CLASS zcl_excel_table_migrator IMPLEMENTATION.

  METHOD migrate.

    rv_inserted = 0.

    " 1) 엑셀 파싱.
    DATA(lo_excel) = NEW cl_fdt_xl_spreadsheet(
      document_name = 'upload.xlsx'
      xdocument     = iv_file_content ).

    lo_excel->if_fdt_doc_spreadsheet~get_worksheet_names(
      IMPORTING worksheet_names = DATA(lt_sheets) ).

    DATA(lt_raw) = lo_excel->if_fdt_doc_spreadsheet~get_itab_from_worksheet(
      worksheet_name = lt_sheets[ 1 ] ).

    IF lines( lt_raw ) <= iv_header_row.
      RETURN.
    ENDIF.

    " 2) 헤더 행 = 대상 테이블 필드명.
    READ TABLE lt_raw ASSIGNING FIELD-SYMBOL(<ls_header>) INDEX iv_header_row.
    DATA(lt_fieldnames) = row_to_strings( <ls_header> ).

    " 3) 대상 테이블 구조를 RTTI로 조회해서 동적 내부테이블 생성.
    DATA(lo_struct) = CAST cl_abap_structdescr(
      cl_abap_structdescr=>describe_by_name( iv_tabname ) ).
    DATA(lo_tabletype) = cl_abap_tabledescr=>create( lo_struct ).

    DATA lr_itab TYPE REF TO data.
    CREATE DATA lr_itab TYPE HANDLE lo_tabletype.
    ASSIGN lr_itab->* TO FIELD-SYMBOL(<lt_itab>).

    DATA lr_wa TYPE REF TO data.

    " 4) 데이터 행 -> 동적 워크에어리어에 필드명 매칭해서 채우고 append.
    LOOP AT lt_raw ASSIGNING FIELD-SYMBOL(<ls_row>) FROM iv_header_row + 1.

      DATA(lt_values) = row_to_strings( <ls_row> ).

      CREATE DATA lr_wa TYPE HANDLE lo_struct.
      ASSIGN lr_wa->* TO FIELD-SYMBOL(<ls_wa>).

      LOOP AT lt_fieldnames INTO DATA(lv_fieldname).
        ASSIGN COMPONENT lv_fieldname OF STRUCTURE <ls_wa> TO FIELD-SYMBOL(<lv_field>).
        IF sy-subrc = 0 AND sy-tabix <= lines( lt_values ).
          <lv_field> = lt_values[ sy-tabix ].
        ENDIF.
      ENDLOOP.

      INSERT <ls_wa> INTO TABLE <lt_itab>.

    ENDLOOP.

    " 5) 동적 INSERT. 대상 테이블명은 호출부 책임 하에 신뢰된 값이어야 한다.
    INSERT (iv_tabname) FROM TABLE <lt_itab>.

    IF sy-subrc = 0.
      rv_inserted = lines( <lt_itab> ).
    ENDIF.

  ENDMETHOD.


  METHOD row_to_strings.

    DATA(lo_descr) = cl_abap_typedescr=>describe_by_data( is_row ).

    IF lo_descr->kind = cl_abap_typedescr=>kind_table.
      FIELD-SYMBOLS <lt_cells> TYPE string_table.
      ASSIGN is_row TO <lt_cells> CASTING.
      rt_values = <lt_cells>.
    ELSE.
      DATA(lo_struct) = CAST cl_abap_structdescr( lo_descr ).
      LOOP AT lo_struct->components INTO DATA(ls_component).
        ASSIGN COMPONENT ls_component-name OF STRUCTURE is_row TO FIELD-SYMBOL(<lv_cell>).
        IF sy-subrc = 0.
          APPEND |{ <lv_cell> }| TO rt_values.
        ENDIF.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
