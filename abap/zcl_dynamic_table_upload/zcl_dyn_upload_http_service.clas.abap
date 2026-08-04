"! 템플릿 다운로드용 HTTP 서비스 핸들러. **선택 사항이다.**
"!
"! 스테이징 테이블(ZTB_DYN_UPLOAD_STG)을 도입하면 템플릿을 그 테이블의 스트림 필드
"! (TemplateFile)에 담아 Fiori Elements 표준 다운로드 링크($value)로 내려받을 수 있으므로,
"! 이 HTTP 서비스는 없어도 된다. 다음 경우에만 쓰면 된다.
"!   - 템플릿을 DB에 저장하지 않고 매번 즉석 생성해서 바로 내려주고 싶을 때
"!   - "액션 실행 -> 링크 클릭" 2단계 대신 단일 클릭/북마크 가능한 URL이 필요할 때
"!   - Fiori 앱 밖(외부 도구, 배치 스크립트)에서 템플릿을 받아가야 할 때
"!
"! Content-Disposition 헤더를 직접 세팅하므로 파일명(ZCBO_XXX_TEMPLATE.xls)을 원하는 대로 준다.
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
