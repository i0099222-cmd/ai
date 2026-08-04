"! 템플릿 다운로드용 HTTP 서비스 핸들러.
"!
"! RAP 액션 결과로 xstring을 돌려줘도 Fiori Elements가 브라우저 다운로드를 걸어주지 않기 때문에,
"! 실제 파일 스트리밍은 이 HTTP 서비스가 담당한다. Content-Disposition 헤더를 직접 세팅할 수 있어
"! 파일명(ZCBO_XXX_TEMPLATE.xls)까지 원하는 대로 나온다.
"!
"! 설정:
"!   ADT에서 "HTTP Service" 오브젝트를 ZDYN_UPLOAD_TEMPLATE 이름으로 만들고
"!   handler class를 이 클래스로 지정한다. 호출 URL은 아래 형태가 된다.
"!     /sap/bc/http/sap/zdyn_upload_template?table=ZCBO_CUSTOMER
"!
"! 보안:
"!   이 엔드포인트는 RAP behavior의 instance feature 통제를 받지 않고 URL로 직접 호출되므로,
"!   테이블명 검증을 여기서 독립적으로 다시 수행한다. 검증이 없으면 임의 테이블의 구조를
"!   외부에 노출하는 메타데이터 유출 경로가 된다.
CLASS zcl_dyn_upload_http_service DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_service_extension.

  PRIVATE SECTION.

    METHODS is_allowed
      IMPORTING
        iv_table_name TYPE tabname
      RETURNING
        VALUE(rv_ok)  TYPE abap_bool.

ENDCLASS.


CLASS zcl_dyn_upload_http_service IMPLEMENTATION.

  METHOD is_allowed.

    " behavior handler(lhc_tadirobject~is_upload_candidate)와 동일한 정책을 적용한다.
    " 고객 네임스페이스(CBO)만 허용.
    IF NOT ( iv_table_name CP 'Z*' OR iv_table_name CP 'Y*' OR iv_table_name CP '/*/*' ).
      RETURN.
    ENDIF.

    " 기술 판정(실존하는 쓰기 가능 DB 테이블인가)은 엔진에 위임.
    DATA(lo_engine) = NEW zcl_dynamic_table_upload( ).
    rv_ok = lo_engine->zif_dynamic_table_upload~is_uploadable( iv_table_name ).

  ENDMETHOD.


  METHOD if_http_service_extension~handle_request.

    DATA(lv_table) = CONV tabname( to_upper( request->get_form_field( 'table' ) ) ).

    IF lv_table IS INITIAL.
      response->set_status( i_code = 400 i_reason = 'Bad Request' ).
      response->set_text( 'Query parameter "table" is required.' ).
      RETURN.
    ENDIF.

    IF is_allowed( lv_table ) = abap_false.
      " 존재 여부와 권한 거부를 구분해서 알려주지 않는다(테이블 존재 여부 probing 방지).
      response->set_status( i_code = 403 i_reason = 'Forbidden' ).
      response->set_text( 'Not an allowed CBO table.' ).
      RETURN.
    ENDIF.

    TRY.
        DATA(lo_engine) = NEW zcl_dynamic_table_upload( ).
        DATA(lv_file)   = lo_engine->zif_dynamic_table_upload~create_excel_template( lv_table ).

        response->set_header_field(
          i_name  = 'content-disposition'
          i_value = |attachment; filename="{ lv_table }_TEMPLATE.xls"| ).

        " SpreadsheetML(.xls) MIME 타입
        response->set_content_type( 'application/vnd.ms-excel' ).
        response->set_binary_data( lv_file ).
        response->set_status( i_code = 200 i_reason = 'OK' ).

      CATCH zcx_dynamic_table_upload INTO DATA(lx_error).

        response->set_status( i_code = 500 i_reason = 'Internal Server Error' ).
        response->set_text( lx_error->get_text( ) ).

    ENDTRY.

  ENDMETHOD.

ENDCLASS.
