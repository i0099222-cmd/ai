"! ZCL_HTTP_SERVICE_TESTER 의 로컬 테스트 클래스 (Test Classes 인클루드).
"!
"! 실제 시스템으로 HTTP 요청을 보내는 통합 테스트이므로
"!   - DURATION LONG / RISK LEVEL DANGEROUS 로 선언한다.
"!   - 아래 CO_URL 이 설정되지 않으면 모든 테스트는 조용히 통과(스킵)한다.
"!     -> 다른 개발자가 이 클래스를 활성화하거나 전체 테스트를 돌려도 깨지지 않는다.
"!
"! 실행: ADT 에서 이 클래스 위에서 Ctrl+Shift+F10 (Run as ABAP Unit Test)
CLASS ltcl_excel_http_service DEFINITION FINAL FOR TESTING
  DURATION LONG
  RISK LEVEL DANGEROUS.

  PRIVATE SECTION.

    CONSTANTS:
      "! ADT 의 HTTP Service 오브젝트에 표시된 URL 로 바꾼다.
      "!   예) co_url TYPE string VALUE 'https://myhost:44300/sap/bc/http/sap/z_excel_service?sap-client=100'
      "! 비워두면 아래 테스트는 모두 스킵된다.
      co_url      TYPE string VALUE IS INITIAL,
      "! 테스트 계정. 비우면 인증정보 없이 호출한다(SSO/기본 인증). 운영 계정은 커밋 금지.
      co_user     TYPE string VALUE IS INITIAL,
      co_password TYPE string VALUE IS INITIAL.

    "! 엑셀 다운로드 요청 시 200 OK 가 오는지
    METHODS excel_download_returns_ok  FOR TESTING RAISING cx_static_check.
    "! 응답이 실제 xlsx(ZIP/PK 시그니처 + OOXML MIME) 인지
    METHODS excel_download_is_xlsx     FOR TESTING RAISING cx_static_check.
    "! 존재하지 않는 경로 호출 시 200 이 아닌 응답이 오는지(핸들러 라우팅 확인)
    METHODS unknown_path_is_not_ok     FOR TESTING RAISING cx_static_check.
    "! JSON 본문 POST 호출(엑셀 생성 요청 등)이 200 OK 로 처리되는지
    METHODS post_json_returns_ok       FOR TESTING RAISING cx_static_check.

    METHODS new_tester
      RETURNING VALUE(ro_tester) TYPE REF TO zcl_http_service_tester
      RAISING   cx_http_dest_provider_error.

    METHODS is_configured
      RETURNING VALUE(rv_configured) TYPE abap_bool.

ENDCLASS.


CLASS ltcl_excel_http_service IMPLEMENTATION.

  METHOD is_configured.
    rv_configured = xsdbool( co_url IS NOT INITIAL ).
  ENDMETHOD.


  METHOD new_tester.

    ro_tester = zcl_http_service_tester=>create_by_url( co_url ).

    IF co_user IS NOT INITIAL.
      ro_tester->set_basic_auth( iv_user = co_user iv_password = co_password ).
    ENDIF.

  ENDMETHOD.


  METHOD excel_download_returns_ok.

    IF is_configured( ) = abap_false.
      RETURN.
    ENDIF.

    DATA(ls_result) = new_tester( )->set_method( zcl_http_service_tester=>co_method-get
                                    )->execute( ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-status_code
      exp = 200
      msg = |HTTP 상태코드가 200 이 아닙니다. 응답: { ls_result-status_code } { ls_result-reason } / { ls_result-body_text }| ).

  ENDMETHOD.


  METHOD excel_download_is_xlsx.

    IF is_configured( ) = abap_false.
      RETURN.
    ENDIF.

    DATA(ls_result) = new_tester( )->set_method( zcl_http_service_tester=>co_method-get
                                    )->add_header( iv_name  = 'Accept'
                                                   iv_value = zcl_http_service_tester=>co_mime_xlsx
                                    )->execute( ).

    cl_abap_unit_assert=>assert_equals( act = ls_result-status_code
                                        exp = 200
                                        msg = |다운로드 호출이 실패했습니다: { ls_result-body_text }| ).

    cl_abap_unit_assert=>assert_true(
      act = ls_result-is_xlsx
      msg = |응답 본문이 xlsx(ZIP) 형식이 아닙니다. Content-Type={ ls_result-content_type }, size={ ls_result-body_size }| ).

    cl_abap_unit_assert=>assert_true(
      act = xsdbool( ls_result-content_type CS 'spreadsheetml'
                  OR ls_result-content_type CS 'octet-stream' )
      msg = |Content-Type 이 엑셀용이 아닙니다: { ls_result-content_type }| ).

    " 빈 워크북이라도 수 KB 는 나오므로, 사실상 빈 응답을 걸러낸다.
    cl_abap_unit_assert=>assert_true( act = xsdbool( ls_result-body_size > 1000 )
                                      msg = |엑셀 파일 크기가 너무 작습니다: { ls_result-body_size } bytes| ).

  ENDMETHOD.


  METHOD unknown_path_is_not_ok.

    IF is_configured( ) = abap_false.
      RETURN.
    ENDIF.

    DATA(ls_result) = new_tester( )->set_method( zcl_http_service_tester=>co_method-get
                                    )->set_path( '/zzz_not_existing_path'
                                    )->execute( ).

    cl_abap_unit_assert=>assert_differs(
      act = ls_result-status_code
      exp = 200
      msg = |존재하지 않는 경로인데 200 이 반환되었습니다. 핸들러의 경로 분기를 확인하세요.| ).

  ENDMETHOD.


  METHOD post_json_returns_ok.

    IF is_configured( ) = abap_false.
      RETURN.
    ENDIF.

    " 핸들러가 기대하는 요청 본문에 맞게 수정해서 사용한다.
    DATA(lv_body) = `{ "bukrs": "1000", "gjahr": "2026" }`.

    DATA(ls_result) = new_tester( )->set_method( zcl_http_service_tester=>co_method-post
                                    )->set_body_text( lv_body
                                    )->use_csrf_token( )->execute( ).

    cl_abap_unit_assert=>assert_equals(
      act = ls_result-status_code
      exp = 200
      msg = |POST 호출 실패: { ls_result-status_code } { ls_result-reason } / { ls_result-body_text }| ).

  ENDMETHOD.

ENDCLASS.
