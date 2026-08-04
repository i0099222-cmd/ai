"! CBO 등 임의의 커스텀 테이블(또는 릴리즈된 CDS 엔터티) 구조를 RTTI로 동적으로 읽어서
"! 1) 업로드용 Excel 템플릿을 생성하고, 2) 업로드된 파일을 JSON으로 변환한 뒤,
"! 3) 그 JSON을 다시 동적 내부테이블로 역직렬화해서 대상 테이블로 마이그레이션(MODIFY)하는
"! 범용 엔진 클래스.
"!
"! 전제/스코프(러프 프로토타입 - 실제 배포 전 재검토 필요):
"! - iv_table_name은 이미 알고 있는(예: CBO 관리 화면이나 자체 CBO 레지스트리 Z 테이블에서
"!   key user가 고른) DB 테이블 또는 릴리즈된 CDS 엔터티 이름이라고 가정한다.
"!   "시스템 내 모든 CBO 목록을 스캔"하는 기능 자체는 이 클래스 밖(레지스트리/조회 화면)에서
"!   구현하고, 그 결과로 나온 테이블 이름만 여기로 넘겨준다.
"! - 다운로드 템플릿은 abap2xlsx 같은 외부 라이브러리 없이 ABAP Cloud에서 바로 만들 수 있도록
"!   ZIP이 필요 없는 SpreadsheetML(.xls, Excel XML) 포맷으로 만든다.
"! - 업로드는 그 템플릿을 Excel에서 채운 뒤 "CSV UTF-8(세미콜론 구분)"로 저장한 파일을
"!   올리는 흐름을 가정한다. 진짜 .xlsx 바이너리(zip) 파싱은 스코프 밖이다.
"! - MODIFY (iv_table_name) ...은 ABAP Cloud 동적 Open SQL 문법이므로, 대상 테이블/엔터티가
"!   실행 컨텍스트에 릴리즈되어 접근 가능한 경우에만 동작한다. 배포 전 릴리즈 상태 확인 필요.
"! - RTTI DFIES 관련 필드명(SCRTEXT_M 등)이나 XCO JSON API(xco_cp_json)의 정확한 시그니처는
"!   시스템 버전에 따라 다를 수 있으므로 실제 개발 시스템에서 코드 컴플리션으로 재검증할 것.
"! - 대용량 업로드 시 행 단위 오류 격리/청크 처리는 하지 않는다(전체 배치 단위 성공/실패).
CLASS zcl_dynamic_table_upload DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_dynamic_table_upload.

  PRIVATE SECTION.

    CONSTANTS mc_delimiter   TYPE c LENGTH 1 VALUE ';'.
    "! 업로드 파일 상단에서 데이터가 아닌 헤더로 취급해 건너뛸 행 수
    "! (1행 = 기술 필드명, 2행 = 필드 설명)
    CONSTANTS mc_header_rows TYPE i VALUE 2.

    METHODS describe_table
      IMPORTING
        iv_table_name    TYPE tabname
      RETURNING
        VALUE(ro_struct) TYPE REF TO cl_abap_structdescr
      RAISING
        zcx_dynamic_table_upload.

    METHODS create_dynamic_table
      IMPORTING
        io_struct       TYPE REF TO cl_abap_structdescr
      RETURNING
        VALUE(rr_table) TYPE REF TO data.

    METHODS escape_xml
      IMPORTING
        iv_text        TYPE string
      RETURNING
        VALUE(rv_text) TYPE string.

ENDCLASS.


CLASS zcl_dynamic_table_upload IMPLEMENTATION.

  METHOD describe_table.

    TRY.
        DATA(lo_type) = cl_abap_typedescr=>describe_by_name( iv_table_name ).
      CATCH cx_root INTO DATA(lx_error).
        RAISE EXCEPTION TYPE zcx_dynamic_table_upload EXPORTING previous = lx_error.
    ENDTRY.

    IF lo_type->kind <> cl_abap_typedescr=>kind_struct.
      RAISE EXCEPTION TYPE zcx_dynamic_table_upload.
    ENDIF.

    ro_struct = CAST cl_abap_structdescr( lo_type ).

  ENDMETHOD.


  METHOD create_dynamic_table.

    DATA(lo_table) = cl_abap_tabledescr=>create( p_line_type = io_struct ).
    CREATE DATA rr_table TYPE HANDLE lo_table.

  ENDMETHOD.


  METHOD escape_xml.

    rv_text = iv_text.
    REPLACE ALL OCCURRENCES OF '&' IN rv_text WITH '&amp;'.
    REPLACE ALL OCCURRENCES OF '<' IN rv_text WITH '&lt;'.
    REPLACE ALL OCCURRENCES OF '>' IN rv_text WITH '&gt;'.
    REPLACE ALL OCCURRENCES OF '"' IN rv_text WITH '&quot;'.

  ENDMETHOD.


  METHOD zif_dynamic_table_upload~is_uploadable.

    " XCO ABAP Dictionary API는 두 언어버전(ABAP Cloud / Standard ABAP) 모두에서 쓸 수 있고,
    " database_table( )->exists( )는 "진짜 DB 테이블"일 때만 abap_true를 준다.
    " 구조체(INTTAB)/뷰/CDS 엔터티는 여기서 걸러진다.
    " (Standard ABAP만 쓰는 환경이면 SELECT SINGLE tabclass FROM dd02l ... = 'TRANSP'로 대체 가능.
    "  XCO 메서드 시그니처는 시스템 버전에 따라 다를 수 있으니 코드 컴플리션으로 재확인할 것.)
    TRY.
        rv_ok = xco_cp_abap_dictionary=>database_table( iv_table_name )->exists( ).
      CATCH cx_root.
        rv_ok = abap_false.
    ENDTRY.

    CHECK rv_ok = abap_true.

    " RTTI로도 구조를 실제로 풀 수 있어야 템플릿/동적 내부테이블 생성이 가능하다.
    TRY.
        describe_table( iv_table_name ).
      CATCH zcx_dynamic_table_upload.
        rv_ok = abap_false.
    ENDTRY.

  ENDMETHOD.


  METHOD zif_dynamic_table_upload~get_table_fields.

    DATA(lo_struct) = describe_table( iv_table_name ).

    TRY.
        DATA(lt_dfies) = lo_struct->get_ddic_field_list( p_including_substructures = abap_true ).
      CATCH cx_root.
        CLEAR lt_dfies.
    ENDTRY.

    IF lt_dfies IS NOT INITIAL.

      rt_field = VALUE #(
        FOR ls_f IN lt_dfies
        ( fieldname = ls_f-fieldname
          rollname  = ls_f-rollname
          ddtext    = ls_f-scrtext_m
          is_key    = ls_f-keyflag
          datatype  = ls_f-datatype
          leng      = ls_f-leng
          decimals  = ls_f-decimals ) ).

    ELSE.

      " DDIC 필드 텍스트를 못 가져오는 구조(CDS 계산 필드 등)는 RTTI 컴포넌트 이름만으로 대체한다.
      rt_field = VALUE #(
        FOR ls_c IN lo_struct->get_components( )
        ( fieldname = CONV #( ls_c-name ) ) ).

    ENDIF.

  ENDMETHOD.


  METHOD zif_dynamic_table_upload~create_excel_template.

    DATA(lt_field) = zif_dynamic_table_upload~get_table_fields( iv_table_name ).

    DATA(lv_xml) =
      |<?xml version="1.0" encoding="UTF-8"?>\n| &&
      |<?mso-application progid="Excel.Sheet"?>\n| &&
      |<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"| &&
      | xmlns:o="urn:schemas-microsoft-com:office:office"| &&
      | xmlns:x="urn:schemas-microsoft-com:office:excel"| &&
      | xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">\n| &&
      |<Styles>\n| &&
      |<Style ss:ID="Header"><Font ss:Bold="1"/>| &&
      |<Interior ss:Color="#DCE6F1" ss:Pattern="Solid"/></Style>\n| &&
      |</Styles>\n| &&
      |<Worksheet ss:Name="{ escape_xml( CONV #( iv_table_name ) ) }">\n| &&
      |<Table>\n| &&
      |<Row>\n|.

    " 1행: 기술 필드명 - 업로드 시 이 값을 그대로 헤더로 사용하므로 값을 수정하면 안 된다.
    LOOP AT lt_field INTO DATA(ls_field).
      lv_xml = lv_xml &&
        |<Cell ss:StyleID="Header"><Data ss:Type="String">| &&
        |{ escape_xml( CONV #( ls_field-fieldname ) ) }</Data></Cell>\n|.
    ENDLOOP.
    lv_xml = lv_xml && |</Row>\n<Row>\n|.

    " 2행: 필드 설명(참고용). 업로드 파싱 시 mc_header_rows에 의해 자동으로 건너뛴다.
    LOOP AT lt_field INTO ls_field.
      DATA(lv_label) = COND string(
        WHEN ls_field-ddtext IS NOT INITIAL
        THEN |{ ls_field-ddtext } ({ ls_field-datatype }{ ls_field-leng })|
        ELSE '' ).
      lv_xml = lv_xml &&
        |<Cell><Data ss:Type="String">{ escape_xml( lv_label ) }</Data></Cell>\n|.
    ENDLOOP.
    lv_xml = lv_xml && |</Row>\n|.

    lv_xml = lv_xml && |</Table>\n</Worksheet>\n</Workbook>|.

    rv_file = cl_abap_codepage=>convert_to( lv_xml ).

  ENDMETHOD.


  METHOD zif_dynamic_table_upload~convert_upload_to_json.

    DATA(lo_struct) = describe_table( iv_table_name ).
    DATA(lr_table)  = create_dynamic_table( lo_struct ).
    ASSIGN lr_table->* TO FIELD-SYMBOL(<lt_table>).

    DATA(lv_content) = cl_abap_codepage=>convert_from( iv_file ).
    REPLACE ALL OCCURRENCES OF cl_abap_char_utilities=>cr_lf IN lv_content WITH cl_abap_char_utilities=>newline.
    SPLIT lv_content AT cl_abap_char_utilities=>newline INTO TABLE DATA(lt_line).

    DATA lt_header TYPE TABLE OF string.
    DATA lr_line   TYPE REF TO data.

    LOOP AT lt_line INTO DATA(lv_line).
      DATA(lv_row) = sy-tabix.

      IF lv_line IS INITIAL.
        CONTINUE.
      ENDIF.

      SPLIT lv_line AT mc_delimiter INTO TABLE DATA(lt_col).

      IF lv_row = 1.
        lt_header = lt_col.
        CONTINUE.
      ENDIF.

      IF lv_row <= mc_header_rows.
        CONTINUE.
      ENDIF.

      CREATE DATA lr_line TYPE HANDLE lo_struct.
      ASSIGN lr_line->* TO FIELD-SYMBOL(<ls_line>).

      LOOP AT lt_header INTO DATA(lv_fieldname).
        DATA(lv_col_idx) = sy-tabix.

        ASSIGN COMPONENT lv_fieldname OF STRUCTURE <ls_line> TO FIELD-SYMBOL(<fs_value>).
        CHECK sy-subrc = 0 AND lines( lt_col ) >= lv_col_idx.

        TRY.
            <fs_value> = lt_col[ lv_col_idx ].
          CATCH cx_sy_conversion_error.
            " 값 변환 실패 필드는 비운 채 다음 필드로 진행한다.
            " (러프 프로토타입: 셀 단위 상세 오류 로그/행 반려는 생략, 필요 시 확장)
            CLEAR <fs_value>.
        ENDTRY.
      ENDLOOP.

      INSERT <ls_line> INTO TABLE <lt_table>.

    ENDLOOP.

    " ABAP Cloud 표준 방식(XCO)으로 동적 내부테이블 -> JSON 직렬화.
    " xco_cp_json=>data->from_abap의 정확한 파라미터 시그니처는 시스템 버전에 따라
    " 다를 수 있으니 코드 컴플리션으로 재확인할 것.
    rv_json = xco_cp_json=>data->from_abap( <lt_table> )->to_string( ).

  ENDMETHOD.


  METHOD zif_dynamic_table_upload~migrate_json_to_table.

    " 동적 MODIFY는 호출자가 넘긴 이름대로 아무 테이블에나 쓰기 때문에, DB에 손대기 전에
    " 반드시 대상이 쓰기 가능한 DB 테이블인지 확인한다(구조체/뷰/오타 방어).
    IF zif_dynamic_table_upload~is_uploadable( iv_table_name ) = abap_false.
      RAISE EXCEPTION TYPE zcx_dynamic_table_upload.
    ENDIF.

    DATA(lo_struct) = describe_table( iv_table_name ).
    DATA(lr_table)  = create_dynamic_table( lo_struct ).
    ASSIGN lr_table->* TO FIELD-SYMBOL(<lt_table>).

    TRY.
        xco_cp_json=>data->from_string( iv_json )->apply( CHANGING data = <lt_table> ).
      CATCH cx_root INTO DATA(lx_json).
        RAISE EXCEPTION TYPE zcx_dynamic_table_upload EXPORTING previous = lx_json.
    ENDTRY.

    rs_result-total_rows = lines( <lt_table> ).

    IF rs_result-total_rows = 0.
      RETURN.
    ENDIF.

    TRY.
        MODIFY (iv_table_name) FROM TABLE @<lt_table>.

        IF sy-subrc = 0.

          rs_result-success_rows = rs_result-total_rows.
          IF iv_commit = abap_true.
            COMMIT WORK.
          ENDIF.

        ELSE.

          rs_result-error_rows = rs_result-total_rows.
          IF iv_commit = abap_true.
            ROLLBACK WORK.
          ENDIF.
          APPEND VALUE #(
            msgty   = 'E'
            message = |MODIFY ({ iv_table_name }) 실패 (sy-subrc = { sy-subrc })| )
            TO rs_result-t_message.

        ENDIF.

      CATCH cx_root INTO DATA(lx_sql).

        rs_result-error_rows = rs_result-total_rows.
        IF iv_commit = abap_true.
          ROLLBACK WORK.
        ENDIF.
        APPEND VALUE #( msgty = 'E' message = lx_sql->get_text( ) ) TO rs_result-t_message.

    ENDTRY.

  ENDMETHOD.


  METHOD zif_dynamic_table_upload~upload_and_migrate.

    DATA(lv_json) = zif_dynamic_table_upload~convert_upload_to_json(
                       iv_table_name = iv_table_name
                       iv_file       = iv_file ).

    rs_result = zif_dynamic_table_upload~migrate_json_to_table(
                       iv_table_name = iv_table_name
                       iv_json       = lv_json
                       iv_commit     = iv_commit ).

  ENDMETHOD.

ENDCLASS.
