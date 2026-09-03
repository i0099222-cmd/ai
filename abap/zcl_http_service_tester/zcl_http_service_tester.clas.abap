"! ADT HTTP Service( + IF_HTTP_SERVICE_EXTENSION 핸들러 클래스 )를
"! 실제로 HTTP 호출해서 동작을 확인하기 위한 테스트 호출 클래스.
"!
"! S/4HANA Cloud Private Edition(PCE) / ABAP Cloud 언어버전에서 릴리즈된 API만 사용한다.
"!   - CL_HTTP_DESTINATION_PROVIDER  : 목적지(URL / Communication Arrangement) 생성
"!   - CL_WEB_HTTP_CLIENT_MANAGER    : HTTP 클라이언트 생성
"!   - IF_WEB_HTTP_REQUEST/RESPONSE  : 요청/응답 조작
"!
"! 사용 방법
"!   1) ADT에서 HTTP Service 오브젝트를 열면 상단에 URL이 표시된다. 그 URL을 복사한다.
"!      예) https://myhost.company.com:44300/sap/bc/http/sap/z_excel_service?sap-client=100
"!   2) 아래 IF_OO_ADT_CLASSRUN~MAIN 의 상수 3~4개만 본인 환경에 맞게 수정하고 F9 로 실행한다.
"!   3) 또는 다른 코드/ABAP Unit 에서 팩토리 메서드로 직접 사용한다.
"!
"!      DATA(ls_result) = zcl_http_service_tester=>create_by_url( lv_url
"!                          )->set_method( zcl_http_service_tester=>co_method-post
"!                          )->add_header( iv_name = 'Accept' iv_value = 'application/json'
"!                          )->set_body_text( '{ "bukrs": "1000" }'
"!                          )->execute( ).
"!
"! 주의: 운영 계정/암호를 소스에 하드코딩해서 커밋하지 말 것.
"!       가능하면 SET_BASIC_AUTH 대신 CREATE_BY_COMM_ARRANGEMENT( Communication Arrangement )를 사용한다.
CLASS zcl_http_service_tester DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun.

    TYPES:
      BEGIN OF ty_name_value,
        name  TYPE string,
        value TYPE string,
      END OF ty_name_value,
      tt_name_value TYPE STANDARD TABLE OF ty_name_value WITH EMPTY KEY.

    "! HTTP 호출 1건의 결과
    TYPES:
      BEGIN OF ty_result,
        url          TYPE string,
        method       TYPE string,
        status_code  TYPE i,
        reason       TYPE string,
        content_type TYPE string,
        t_header     TYPE tt_name_value,
        body_text    TYPE string,
        body_binary  TYPE xstring,
        body_size    TYPE i,
        is_xlsx      TYPE abap_bool,
        runtime_ms   TYPE i,
      END OF ty_result.

    CONSTANTS:
      BEGIN OF co_method,
        get    TYPE string VALUE 'GET',
        post   TYPE string VALUE 'POST',
        put    TYPE string VALUE 'PUT',
        patch  TYPE string VALUE 'PATCH',
        delete TYPE string VALUE 'DELETE',
      END OF co_method.

    CONSTANTS:
      "! xlsx(=OOXML) MIME 타입
      co_mime_xlsx TYPE string
        VALUE 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      co_mime_json TYPE string VALUE 'application/json',
      "! ZIP(=xlsx) 파일 시그니처 'PK'
      co_zip_magic TYPE x LENGTH 2 VALUE '504B'.

    "! 전체 URL로 호출 대상 생성 (가장 간단, ADT의 HTTP Service URL을 그대로 붙여넣기)
    CLASS-METHODS create_by_url
      IMPORTING
        iv_url           TYPE string
      RETURNING
        VALUE(ro_tester) TYPE REF TO zcl_http_service_tester
      RAISING
        cx_http_dest_provider_error.

    "! Communication Arrangement 기반 호출 대상 생성 (인증정보를 소스에 두지 않는 방식)
    CLASS-METHODS create_by_comm_arrangement
      IMPORTING
        iv_comm_scenario TYPE string
        iv_service_id    TYPE string OPTIONAL
      RETURNING
        VALUE(ro_tester) TYPE REF TO zcl_http_service_tester
      RAISING
        cx_http_dest_provider_error.

    METHODS set_method
      IMPORTING iv_method      TYPE string
      RETURNING VALUE(ro_self) TYPE REF TO zcl_http_service_tester.

    "! 목적지 URL 뒤에 붙일 경로. 지정하지 않으면 목적지 URL의 경로를 그대로 사용한다.
    METHODS set_path
      IMPORTING iv_path        TYPE string
      RETURNING VALUE(ro_self) TYPE REF TO zcl_http_service_tester.

    METHODS add_query
      IMPORTING iv_name        TYPE string
                iv_value       TYPE string
      RETURNING VALUE(ro_self) TYPE REF TO zcl_http_service_tester.

    METHODS add_header
      IMPORTING iv_name        TYPE string
                iv_value       TYPE string
      RETURNING VALUE(ro_self) TYPE REF TO zcl_http_service_tester.

    METHODS set_basic_auth
      IMPORTING iv_user        TYPE string
                iv_password    TYPE string
      RETURNING VALUE(ro_self) TYPE REF TO zcl_http_service_tester.

    METHODS set_body_text
      IMPORTING iv_text         TYPE string
                iv_content_type TYPE string DEFAULT co_mime_json
      RETURNING VALUE(ro_self)  TYPE REF TO zcl_http_service_tester.

    "! 엑셀 업로드 테스트처럼 바이너리 본문을 보낼 때 사용
    METHODS set_body_binary
      IMPORTING iv_data         TYPE xstring
                iv_content_type TYPE string DEFAULT co_mime_xlsx
      RETURNING VALUE(ro_self)  TYPE REF TO zcl_http_service_tester.

    "! POST/PUT 시 x-csrf-token 을 먼저 fetch 해서 붙인다(핸들러가 CSRF 보호를 켜둔 경우 필요).
    METHODS use_csrf_token
      IMPORTING iv_active      TYPE abap_bool DEFAULT abap_true
      RETURNING VALUE(ro_self) TYPE REF TO zcl_http_service_tester.

    "! 실제 HTTP 호출 실행
    METHODS execute
      RETURNING VALUE(rs_result) TYPE ty_result
      RAISING   cx_web_http_client_error.

    "! 결과를 콘솔/로그용 텍스트로 변환
    METHODS to_text
      IMPORTING is_result      TYPE ty_result
                iv_body_limit  TYPE i DEFAULT 3000
      RETURNING VALUE(rt_text) TYPE string_table.

  PRIVATE SECTION.

    DATA mo_destination TYPE REF TO if_http_destination.
    DATA mv_url         TYPE string.
    DATA mv_method      TYPE string.
    DATA mv_path        TYPE string.
    DATA mt_query       TYPE tt_name_value.
    DATA mt_header      TYPE tt_name_value.
    DATA mv_user        TYPE string.
    DATA mv_password    TYPE string.
    DATA mv_body_text   TYPE string.
    DATA mv_body_binary TYPE xstring.
    DATA mv_body_is_bin TYPE abap_bool.
    DATA mv_use_csrf    TYPE abap_bool.

    METHODS constructor
      IMPORTING io_destination TYPE REF TO if_http_destination
                iv_url         TYPE string.

    METHODS build_query_string
      RETURNING VALUE(rv_query) TYPE string.

    "! 요청 헤더/본문/인증 세팅 (CSRF fetch 와 실제 호출에서 공통으로 사용)
    METHODS prepare_request
      IMPORTING io_request TYPE REF TO if_web_http_request.

    METHODS fetch_csrf_token
      IMPORTING io_client         TYPE REF TO if_web_http_client
      RETURNING VALUE(rv_token)   TYPE string.

ENDCLASS.


CLASS zcl_http_service_tester IMPLEMENTATION.

  METHOD create_by_url.

    DATA(lo_destination) = cl_http_destination_provider=>create_by_url( iv_url ).

    ro_tester = NEW zcl_http_service_tester( io_destination = lo_destination
                                             iv_url         = iv_url ).

  ENDMETHOD.


  METHOD create_by_comm_arrangement.

    DATA(lo_destination) = cl_http_destination_provider=>create_by_comm_arrangement(
                             comm_scenario = CONV #( iv_comm_scenario )
                             service_id    = CONV #( iv_service_id ) ).

    ro_tester = NEW zcl_http_service_tester( io_destination = lo_destination
                                             iv_url         = |{ iv_comm_scenario }/{ iv_service_id }| ).

  ENDMETHOD.


  METHOD constructor.

    mo_destination = io_destination.
    mv_url         = iv_url.
    mv_method      = co_method-get.

  ENDMETHOD.


  METHOD set_method.
    mv_method = to_upper( iv_method ).
    ro_self   = me.
  ENDMETHOD.


  METHOD set_path.
    mv_path = iv_path.
    ro_self = me.
  ENDMETHOD.


  METHOD add_query.
    APPEND VALUE #( name = iv_name value = iv_value ) TO mt_query.
    ro_self = me.
  ENDMETHOD.


  METHOD add_header.
    APPEND VALUE #( name = iv_name value = iv_value ) TO mt_header.
    ro_self = me.
  ENDMETHOD.


  METHOD set_basic_auth.
    mv_user     = iv_user.
    mv_password = iv_password.
    ro_self     = me.
  ENDMETHOD.


  METHOD set_body_text.
    mv_body_text   = iv_text.
    mv_body_is_bin = abap_false.
    add_header( iv_name = 'Content-Type' iv_value = iv_content_type ).
    ro_self = me.
  ENDMETHOD.


  METHOD set_body_binary.
    mv_body_binary = iv_data.
    mv_body_is_bin = abap_true.
    add_header( iv_name = 'Content-Type' iv_value = iv_content_type ).
    ro_self = me.
  ENDMETHOD.


  METHOD use_csrf_token.
    mv_use_csrf = iv_active.
    ro_self     = me.
  ENDMETHOD.


  METHOD build_query_string.

    LOOP AT mt_query INTO DATA(ls_query).
      DATA(lv_pair) = |{ ls_query-name }={ cl_web_http_utility=>escape_url( ls_query-value ) }|.
      rv_query = COND #( WHEN rv_query IS INITIAL THEN lv_pair
                         ELSE |{ rv_query }&{ lv_pair }| ).
    ENDLOOP.

  ENDMETHOD.


  METHOD prepare_request.

    IF mv_path IS NOT INITIAL.
      io_request->set_uri_path( mv_path ).
    ENDIF.

    DATA(lv_query) = build_query_string( ).
    IF lv_query IS NOT INITIAL.
      io_request->set_uri_query( lv_query ).
    ENDIF.

    IF mv_user IS NOT INITIAL.
      io_request->set_authorization_basic( i_username = mv_user
                                           i_password = mv_password ).
    ENDIF.

    LOOP AT mt_header INTO DATA(ls_header).
      io_request->set_header_field( i_name  = to_lower( ls_header-name )
                                    i_value = ls_header-value ).
    ENDLOOP.

  ENDMETHOD.


  METHOD fetch_csrf_token.

    " 같은 클라이언트 인스턴스로 호출해야 세션 쿠키가 유지되어 토큰이 유효하다.
    DATA(lo_request) = io_client->get_http_request( ).
    prepare_request( lo_request ).
    lo_request->set_header_field( i_name = 'x-csrf-token' i_value = 'fetch' ).

    TRY.
        DATA(lo_response) = io_client->execute( co_method-get ).
        rv_token = lo_response->get_header_field( 'x-csrf-token' ).
      CATCH cx_root.
        " 토큰 조회 실패는 무시한다. 핸들러가 CSRF 보호를 쓰지 않는 경우도 많다.
        CLEAR rv_token.
    ENDTRY.

  ENDMETHOD.


  METHOD execute.

    rs_result-url    = mv_url.
    rs_result-method = mv_method.

    DATA(lo_client) = cl_web_http_client_manager=>create_by_http_destination( mo_destination ).

    DATA lv_csrf TYPE string.
    IF mv_use_csrf = abap_true AND mv_method <> co_method-get.
      lv_csrf = fetch_csrf_token( lo_client ).
    ENDIF.

    DATA(lo_request) = lo_client->get_http_request( ).
    prepare_request( lo_request ).

    IF lv_csrf IS NOT INITIAL.
      lo_request->set_header_field( i_name = 'x-csrf-token' i_value = lv_csrf ).
    ENDIF.

    IF mv_body_is_bin = abap_true.
      lo_request->set_binary( mv_body_binary ).
    ELSEIF mv_body_text IS NOT INITIAL.
      lo_request->set_text( mv_body_text ).
    ENDIF.

    DATA(lv_start) = utclong_current( ).

    DATA(lo_response) = lo_client->execute( mv_method ).

    rs_result-runtime_ms = CONV i( utclong_diff( high = utclong_current( )
                                                 low  = lv_start ) * 1000 ).

    DATA(ls_status) = lo_response->get_status( ).
    rs_result-status_code = ls_status-code.
    rs_result-reason      = ls_status-reason.

    DATA(lt_fields) = lo_response->get_header_fields( ).
    LOOP AT lt_fields INTO DATA(ls_field).
      APPEND VALUE #( name = ls_field-name value = ls_field-value ) TO rs_result-t_header.
      IF to_lower( ls_field-name ) = 'content-type'.
        rs_result-content_type = ls_field-value.
      ENDIF.
    ENDLOOP.

    TRY.
        rs_result-body_binary = lo_response->get_binary( ).
        rs_result-body_size   = xstrlen( rs_result-body_binary ).

        IF rs_result-body_size > 1 AND rs_result-body_binary(2) = co_zip_magic.
          " ZIP 시그니처 'PK' -> xlsx 다운로드 응답으로 간주하고 텍스트 변환은 하지 않는다.
          rs_result-is_xlsx = abap_true.
        ELSE.
          rs_result-body_text = lo_response->get_text( ).
        ENDIF.
      CATCH cx_root INTO DATA(lx_body).
        rs_result-body_text = |본문을 읽지 못했습니다: { lx_body->get_text( ) }|.
    ENDTRY.

    lo_client->close( ).

  ENDMETHOD.


  METHOD to_text.

    APPEND |{ is_result-method } { is_result-url }| TO rt_text.
    APPEND |HTTP { is_result-status_code } { is_result-reason } ({ is_result-runtime_ms } ms)| TO rt_text.
    APPEND |Content-Type : { is_result-content_type }| TO rt_text.
    APPEND |Body size    : { is_result-body_size } bytes| TO rt_text.
    APPEND |xlsx 여부    : { COND string( WHEN is_result-is_xlsx = abap_true
                                          THEN 'YES (ZIP/PK 시그니처 확인)'
                                          ELSE 'NO' ) }| TO rt_text.
    APPEND `--- response header ---` TO rt_text.

    LOOP AT is_result-t_header INTO DATA(ls_header).
      APPEND |{ ls_header-name }: { ls_header-value }| TO rt_text.
    ENDLOOP.

    IF is_result-is_xlsx = abap_false.
      APPEND `--- response body ---` TO rt_text.
      APPEND COND string( WHEN strlen( is_result-body_text ) > iv_body_limit
                          THEN |{ is_result-body_text(iv_body_limit) } ...(생략)|
                          ELSE is_result-body_text ) TO rt_text.
    ENDIF.

  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.

    " ▼▼▼ 본인 환경에 맞게 이 블록만 수정하고 F9 실행 ▼▼▼
    " ADT에서 HTTP Service 오브젝트를 열면 표시되는 URL을 그대로 붙여넣는다.
    DATA(lv_url)      = `https://<host>:<port>/sap/bc/http/sap/z_excel_service?sap-client=100`.
    DATA(lv_method)   = co_method-get.
    DATA(lv_user)     = ``.   " 비우면 SSO/기본 인증 없이 호출. 테스트 계정 사용 시에만 입력하고 커밋하지 말 것.
    DATA(lv_password) = ``.
    DATA(lv_body)     = ``.   " POST 테스트용 JSON 본문. 예) `{ "bukrs": "1000", "gjahr": "2026" }`
    " ▲▲▲ 여기까지 ▲▲▲

    TRY.
        DATA(lo_tester) = create_by_url( lv_url )->set_method( lv_method ).

        IF lv_user IS NOT INITIAL.
          lo_tester->set_basic_auth( iv_user = lv_user iv_password = lv_password ).
        ENDIF.

        IF lv_body IS NOT INITIAL.
          lo_tester->set_body_text( lv_body )->use_csrf_token( ).
        ENDIF.

        DATA(ls_result) = lo_tester->execute( ).

        out->write( lo_tester->to_text( ls_result ) ).

        IF ls_result-is_xlsx = abap_true.
          out->write( |엑셀 파일이 정상적으로 반환되었습니다. 내용 검증은 브라우저에서 같은 URL을 열어 다운로드해 확인하세요.| ).
        ENDIF.

      CATCH cx_root INTO DATA(lx_error).
        out->write( |호출 실패: { lx_error->get_text( ) }| ).
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
