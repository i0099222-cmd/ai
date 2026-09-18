"! 승인된 예외를 표준 ATC 예외 저장소에 반영하는 어댑터.
"!
"! 설계 전제: 관리는 CBO, 실행은 표준.
"!   - 신청/승인/이력/권한은 CBO 테이블이 원천이다 (감사 대응, 자사 통제).
"!   - 억제 자체는 표준 메커니즘이 한다. 커스텀 체크 클래스는 만들지 않는다.
"!
"! 표준 진입점: CL_SATC_API=>CREATE_API_FACTORY( )->GET_EXEMPTION_CONTROLLER( )
"!   표준 Fiori 앱 "Approve ATC Exemptions" 도 결국 이 경로로 예외의 state 와
"!   approver 를 바꾼다 (SATC_CI_R_EXEMPTION).
"!
"! 확인된 표준 API
"!   controller->create_exemption( i_object_type, i_object_name,
"!                                 i_check_class, i_check_code,
"!                                 i_contact_person )
"!     -> 예외 오브젝트를 돌려주고, 나머지는 setter 로 채운다
"!          set_object_scope( )       SATC_CI_OBJ_SCOPE. FND / OBJ / PCKG
"!          set_check_scope( )        MSG / CHK / ALL / FND
"!          set_reason( )
"!          set_validity_date( )
"!          set_approver( )
"!          set_notification_type( )  REJ / ALWS / NEVR
"!          send_to_approver( )       승인 요청 제출
"!          unlock( )                 잠금 해제
"!          get_exemption_id( )       생성된 예외 ID
"!   controller->approve_exemption_by_id( exemption_id, assessment )  <- 건별 승인
"!   controller->reject_exemptions_by_id( exemption_id, assessment ) <- 건별 반려
"!   controller->approve_exemptions_by_if( exemptions_for_approval ) <- 테이블 일괄 승인
"!
"! set_object_scope 가 있으므로 패키지 스코프를 표준 예외 1건으로 넘길 수 있다.
"! 오브젝트마다 예외를 전개할 필요가 없고, 예외 ID 는 신청서(헤더)에 1개면 된다.
"!
"! 생성은 곧바로 승인 상태가 되지 않는다. send_to_approver( ) 로 승인 요청까지
"! 간 뒤 approve_exemptions_by_if( ) 로 승인해야 한다. 그래서 두 호출을 한 번에
"! 이어서 수행한다 - 중간 상태로 남겨두면 표준 Fiori 승인 앱에서 다른 사람이
"! 먼저 결재할 수 있고, 그러면 CBO 대장을 거치지 않은 승인이 생긴다.
"!
"! 반영 시점을 "승인 시" 로 잡은 이유:
"!   상신 시점에 표준 예외를 만들면 그 예외가 표준 승인 대기 상태로 남는다.
"!   그러면 표준 Fiori 승인 앱에서 누군가 먼저 승인해 버릴 수 있고, CBO 대장을
"!   거치지 않은 결재가 생긴다. 승인이 끝난 뒤에 승인 상태로 만들어 넣으면
"!   표준 저장소에는 이미 결정된 예외만 존재하고, 결재 창구는 이 앱 하나로 남는다.
CLASS zcl_atc_exempt_sync DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_result,
        success     TYPE abap_boolean,
        "! SATC_CI_EXEMPTION_ID 와 같은 타입
        extexemptid TYPE sysuuid_c32,
        message     TYPE string,
      END OF ty_result.

    "! 승인된 예외를 표준 저장소에 생성한다.
    METHODS create_exemption
      IMPORTING is_exemption     TYPE ztatcexempt
      RETURNING VALUE(rs_result) TYPE ty_result.

    "! 철회/만료된 예외를 표준 저장소에서 무효화한다.
    METHODS revoke_exemption
      IMPORTING iv_extexemptid   TYPE sysuuid_c32
                iv_reason        TYPE string OPTIONAL
      RETURNING VALUE(rs_result) TYPE ty_result.

    "! ADT 에서 직접 올라온 신청을 CBO 대장으로 끌어온다.
    "!
    "! 신청 경로는 두 개이고 ADT 경로는 막을 수 없다. 동기화하지 않으면
    "! CBO 대장이 실제 시스템 상태와 어긋나고, 반년 뒤 감사에서 드러난다.
    "! 배치로 주기 실행한다.
    METHODS sync_from_standard
      RETURNING VALUE(rv_synced) TYPE i.

  PRIVATE SECTION.

    "! 표준 예외 컨트롤러. 최초 호출 시 한 번만 만든다.
    METHODS get_controller
      RETURNING VALUE(ro_controller) TYPE REF TO object.

    DATA mo_controller TYPE REF TO object.

ENDCLASS.


CLASS zcl_atc_exempt_sync IMPLEMENTATION.

  METHOD get_controller.

    IF mo_controller IS NOT BOUND.
      " TODO 반환 타입을 실제 인터페이스로 바꿀 것.
      "   ADT 에서 GET_EXEMPTION_CONTROLLER( ) 의 RETURNING 타입을 확인해
      "   REF TO object 대신 그 인터페이스로 선언하면 코드 완성과 구문 점검을
      "   받을 수 있다. 지금은 메소드 시그니처를 모르는 상태라 느슨하게 둔다.
      mo_controller = cl_satc_api=>create_api_factory( )->get_exemption_controller( ).
    ENDIF.

    ro_controller = mo_controller.

  ENDMETHOD.


  METHOD create_exemption.

    " 생성 -> 설정 -> 승인요청 -> 승인 까지를 한 번에 수행한다.
    " 패키지 스코프도 출발점 오브젝트로 만든 뒤 set_object_scope( ) 로 넓힌다.
    " ADT 에서 finding 을 우클릭해 "All Objects of Package" 를 고르는 것과 같은 순서다.

    DATA(lo_controller) = get_controller( ).

    DATA(ls_config) = zcl_atc_config=>get( )->get_config( is_exemption-checkvariant ).

    TRY.

        " 타입은 확정되었다. i_check_class 는 CSEQUENCE(문자열 클래스명),
        " i_check_code 는 CHAR10 이다. 따라서 신청서의 checkid(CHAR30) /
        " messageid(CHAR10) 를 그대로 넘긴다.
        "
        " 🔴 단, findings 뷰는 이 두 값을 주지 않는다. 그 뷰가 주는 것은
        "   moduleid(RAW16) 와 module_msg_key(CHAR25) 라 둘 다 타입이 맞지 않는다.
        "   그래서 현재는 finding 에서 신청서를 만들어도 checkid / messageid 가
        "   비어 있고, 그 상태로는 이 메서드까지 오지 못한다(필수 필드 검증에서 막힘).
        "   moduleid -> 클래스명 변환 경로를 찾기 전까지는 사용자가 체크 클래스와
        "   코드를 직접 입력해야 한다.
        DATA(lo_exemption) = lo_controller->create_exemption(
          i_object_type    = is_exemption-objecttype
          i_object_name    = is_exemption-objectname
          i_check_class    = is_exemption-checkid
          i_check_code     = is_exemption-messageid
          i_contact_person = is_exemption-requester ).

        " SATC_CI_OBJ_SCOPE 의 고정값이 우리 scopetype( FND / OBJ / PCKG )과
        " 같음을 확인했으므로 변환 없이 넘긴다.
        lo_exemption->set_object_scope( CONV #( is_exemption-scopetype ) ).

        " 체크 축은 MSG / CHK / ALL / FND 중 하나다. 신청서는 MSG / CHK 만 쓴다.
        lo_exemption->set_check_scope( CONV #( is_exemption-rulescope ) ).

        lo_exemption->set_reason( is_exemption-reasontext ).
        lo_exemption->set_validity_date( is_exemption-validto ).
        lo_exemption->set_approver( i_approver = is_exemption-approver ).

        " 알림 유형은 조직 정책이므로 컨트롤 테이블에서 읽는다.
        lo_exemption->set_notification_type(
          COND #( WHEN ls_config-notiftype IS NOT INITIAL
                  THEN ls_config-notiftype
                  ELSE zif_atc_exemption=>notification-never ) ).

        " 승인 요청까지 보낸 뒤 잠금을 푼다.
        lo_exemption->send_to_approver( ).
        lo_exemption->unlock( ).

        " SATC_CI_EXEMPTION_ID (SYSUUID_C32)
        DATA(lv_exemption_id) = lo_exemption->get_exemption_id( ).

        " 이어서 바로 승인한다. 결재는 이미 이 앱에서 끝났고, 표준에 승인대기
        " 상태로 남겨두면 표준 Fiori 앱에서 다른 사람이 먼저 결재할 수 있다.
        lo_controller->approve_exemption_by_id(
          exemption_id = lv_exemption_id
          assessment   = is_exemption-reasontext ).

        rs_result = VALUE #( success     = abap_true
                             extexemptid = lv_exemption_id
                             message     = |표준 예외 { lv_exemption_id } 생성| ).

      CATCH cx_root INTO DATA(lo_error).
        " 표준 반영이 실패해도 CBO 승인 기록은 남긴다. 대장이 원천이고
        " 표준 반영은 뒤따르는 구조이기 때문이다. 실패 사유는 이력에 적힌다.
        rs_result = VALUE #( success = abap_false
                             message = lo_error->get_text( ) ).
    ENDTRY.

  ENDMETHOD.


  METHOD revoke_exemption.

    " 표준 쪽 예외도 함께 무효화해야 한다. CBO 만 철회하면 대장은 철회인데
    " 실제로는 계속 면제되는 상태로 남는다.
    "
    " reject_exemptions_by_id( ) 로 이미 승인된 예외를 반려 상태로 돌린다.
    " assessment 에 철회 사유를 남겨 표준 쪽에서도 이유를 알 수 있게 한다.

    DATA(lo_controller) = get_controller( ).

    TRY.

        " TODO 동작 확인: 이미 승인(approved)된 예외에 reject 를 걸었을 때
        "   상태가 실제로 바뀌고 면제가 풀리는지 테스트할 것.
        "   승인 전 상태에서만 동작한다면, 대안은 기존 예외를 다시 읽어
        "   set_validity_date( ) 를 어제 날짜로 당기는 것이다.
        lo_controller->reject_exemptions_by_id(
          exemption_id = iv_extexemptid
          assessment   = iv_reason ).

        rs_result = VALUE #( success = abap_true
                             message = |표준 예외 { iv_extexemptid } 무효화| ).

      CATCH cx_root INTO DATA(lo_error).
        rs_result = VALUE #( success = abap_false
                             message = lo_error->get_text( ) ).
    ENDTRY.

  ENDMETHOD.


  METHOD sync_from_standard.

    " TODO 구현. 읽기는 SATC_CI_R_EXEMPTION 뷰로 가능하다.
    "   1) 표준 저장소에서 예외 목록을 읽는다.
    "   2) ztatcexempt-extexemptid 에 없는 건을 CBO 대장에 등록한다
    "      (출처를 구분할 수 있게 이력에 SYNC 로 남긴다).
    "   3) CBO 에는 승인 상태인데 표준에 없는 건을 불일치로 리포트한다.

    rv_synced = 0.

  ENDMETHOD.

ENDCLASS.
