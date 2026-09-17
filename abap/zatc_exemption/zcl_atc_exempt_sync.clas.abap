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
"!                                 i_contact_person )   <- 이 5개가 필수
"!     -> 예외 오브젝트를 돌려주고, 나머지는 setter 로 채운다
"!          exemption->set_object_scope( )       FND / OBJ / PCKG
"!          exemption->set_check_scope( )        메시지 단위 / 체크 전체
"!          exemption->set_reason( )
"!          exemption->set_approver( )
"!          exemption->set_notification_type( )
"!   controller->approve_exemptions_by_if( exemptions_for_approval )  <- 일괄 승인
"!
"! set_object_scope 가 있으므로 패키지 스코프를 표준 예외 1건으로 넘길 수 있다.
"! 오브젝트마다 예외를 전개할 필요가 없고, 예외 ID 는 신청서(헤더)에 1개면 된다.
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

    " 생성은 두 단계다.
    "   1) create_exemption( ) 으로 예외 오브젝트를 만든다. 오브젝트와 체크가 필수다.
    "   2) setter 로 적용범위·사유·승인자를 채운다.
    "
    " 패키지 스코프도 오브젝트를 하나 넘겨서 만든 뒤 set_object_scope( ) 로 넓힌다.
    " ADT 에서 finding 을 우클릭해 "All Objects of Package" 를 고르는 것과 같은 순서다.
    " 그래서 헤더의 objecttype / objectname 은 패키지 스코프에서도 비워 두지 않고
    " "출발점 오브젝트" 로 보관한다.

    DATA(lo_controller) = get_controller( ).

    " TODO 실제 호출로 교체. 남은 확인 사항은 setter 의 파라미터 타입과 저장 메소드다.
    "
    " DATA(lo_exemption) = lo_controller->create_exemption(
    "   i_object_type    = is_exemption-objecttype
    "   i_object_name    = is_exemption-objectname
    "   i_check_class    = is_exemption-checkid
    "   i_check_code     = is_exemption-messageid
    "   i_contact_person = is_exemption-requester ).
    "
    " lo_exemption->set_object_scope( is_exemption-scopetype ).   " FND / OBJ / PCKG
    " lo_exemption->set_check_scope( is_exemption-rulescope ).    " 메시지 / 체크 전체
    " lo_exemption->set_reason( is_exemption-reasontext ).
    " lo_exemption->set_approver( is_exemption-approver ).
    "
    " TODO 확인 필요
    "   - set_object_scope / set_check_scope 가 받는 값의 타입.
    "     우리 scopetype( FND / OBJ / PCKG )을 그대로 넘길 수 있는지, 아니면
    "     표준 enum/상수로 변환해야 하는지.
    "   - 유효기간 setter 가 따로 있는지 (set_valid_until 류).
    "     없으면 우리 validto 를 표준에 반영할 방법이 없으므로, 만료 관리는
    "     CBO 쪽 배치가 전적으로 책임진다.
    "   - 저장/제출 메소드. create + setter 만으로 저장되는지, 별도 save/submit 이
    "     필요한지, 아니면 approve_exemptions_by_if( ) 가 그 역할을 겸하는지.
    "   - 생성된 예외 ID 를 어디서 받는지 -> rs_result-extexemptid 에 담아야 한다.
    "     이 값이 없으면 나중에 철회/연장할 때 표준 레코드를 찾을 수 없다.
    "   - set_notification_type( ) 의 선택지. 표준 알림이 어디까지 해 주는지에 따라
    "     CBO 쪽 만료 알림 배치와 역할이 겹칠 수 있다.

    rs_result = VALUE #(
      success = abap_false
      message = |표준 예외 반영 보류: setter 파라미터 타입과 저장 메소드 확인 필요. | &&
                |CBO 대장에는 승인 기록이 저장되었습니다.| ).

  ENDMETHOD.


  METHOD revoke_exemption.

    " TODO create_exemption 과 같은 컨트롤러로 구현.
    "   표준 쪽 예외도 함께 무효화해야 한다. CBO 만 철회하면 대장은 철회인데
    "   실제로는 계속 면제되는 상태가 된다.

    DATA(lo_controller) = get_controller( ).

    rs_result = VALUE #(
      success = abap_false
      message = |표준 예외 무효화 보류: 예외 컨트롤러 메소드 미구현.| ).

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
