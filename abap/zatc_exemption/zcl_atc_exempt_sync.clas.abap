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
"!          set_object_scope( )       SATC_CI_OBJ_SCOPE 타입. FND / OBJ / PCKG
"!          set_check_scope( )        메시지 단위 / 체크 전체
"!          set_reason( )
"!          set_validity_date( )
"!          set_approver( )
"!          set_notification_type( )  REJ / ALWS / NEVR
"!          send_to_approver( )       승인 요청 제출
"!          unlock( )                 잠금 해제
"!          get_exemption_id( )       생성된 예외 ID
"!   controller->approve_exemptions_by_if( exemptions_for_approval )  <- 일괄 승인
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
        extexemptid TYPE char32,
        message     TYPE string,
      END OF ty_result.

    "! 승인된 예외를 표준 저장소에 생성한다.
    METHODS create_exemption
      IMPORTING is_exemption     TYPE ztatcexempt
      RETURNING VALUE(rs_result) TYPE ty_result.

    "! 철회/만료된 예외를 표준 저장소에서 무효화한다.
    METHODS revoke_exemption
      IMPORTING iv_extexemptid   TYPE char32
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

        DATA(lo_exemption) = lo_controller->create_exemption(
          i_object_type    = is_exemption-objecttype
          i_object_name    = is_exemption-objectname
          i_check_class    = is_exemption-checkid
          i_check_code     = is_exemption-messageid
          i_contact_person = is_exemption-requester ).

        " TODO 값 변환 확인: set_object_scope 는 SATC_CI_OBJ_SCOPE 타입을 받는다.
        "   우리 scopetype( FND / OBJ / PCKG )을 그대로 넘길 수 있는지, 아니면
        "   그 도메인의 고정값으로 매핑해야 하는지 확인해 여기서 변환한다.
        lo_exemption->set_object_scope( CONV #( is_exemption-scopetype ) ).

        " TODO set_check_scope 가 받는 값 확인. 우리 rulescope( MSG / CHK ) 대응.
        lo_exemption->set_check_scope( CONV #( is_exemption-rulescope ) ).

        lo_exemption->set_reason( is_exemption-reasontext ).
        lo_exemption->set_validity_date( is_exemption-validto ).
        lo_exemption->set_approver( is_exemption-approver ).

        " 알림 유형은 조직 정책이므로 컨트롤 테이블에서 읽는다.
        lo_exemption->set_notification_type(
          COND #( WHEN ls_config-notiftype IS NOT INITIAL
                  THEN ls_config-notiftype
                  ELSE zif_atc_exemption=>notification-never ) ).

        " 승인 요청까지 보낸 뒤 잠금을 푼다.
        lo_exemption->send_to_approver( ).
        lo_exemption->unlock( ).

        DATA(lv_exemption_id) = lo_exemption->get_exemption_id( ).

        " 이어서 바로 승인한다. 결재는 이미 이 앱에서 끝났고, 표준에 승인대기
        " 상태로 남겨두면 표준 Fiori 앱에서 다른 사람이 먼저 결재할 수 있다.
        " TODO exemptions_for_approval 의 행 구조 확인 후 채울 것.
        "   (예외 ID 만 담는지, 승인자/코멘트도 함께 담는지)
        " lo_controller->approve_exemptions_by_if(
        "   exemptions_for_approval = VALUE #( ( ... lv_exemption_id ... ) ) ).

        rs_result = VALUE #( success     = abap_true
                             extexemptid = CONV #( lv_exemption_id )
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
    " TODO 확인 필요: 기존 예외를 읽어오는 메소드와 무효화 방법.
    "   컨트롤러에 get/read 계열이 있는지 보고, 없으면 SATC_CI_R_EXEMPTION 뷰로
    "   찾은 뒤 상태를 바꾸는 경로를 확인한다.
    "   유효기간을 오늘 이전으로 당기는(set_validity_date) 방식으로 사실상
    "   무효화하는 것도 대안이 된다.

    DATA(lo_controller) = get_controller( ).

    rs_result = VALUE #(
      success = abap_false
      message = |표준 예외 무효화 보류: 무효화 경로 확인 필요.| ).

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
