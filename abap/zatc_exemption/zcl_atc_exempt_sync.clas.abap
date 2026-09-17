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

    " TODO 컨트롤러의 메소드 시그니처 확인 후 실제 호출로 교체.
    "   확인 방법: ADT 에서 위 get_controller 의 반환 타입을 열고 메소드 목록을 본다.
    "              (또는 표준 Fiori 승인 앱의 구현 클래스가 어떤 메소드를 쓰는지 본다)
    "
    "   넘겨야 할 값
    "     적용범위   is_exemption-scopetype   FND / OBJ / PCKG
    "     대상       is_exemption-devclass / objecttype / objectname
    "     규칙       is_exemption-checkid / messageid / rulescope
    "     사유       is_exemption-reasoncode / reasontext
    "     유효기간   is_exemption-validfrom / validto
    "     상태       승인 상태로 바로 생성한다 (위 클래스 주석의 이유)
    "     승인자     is_exemption-approver
    "
    "   FND 스코프까지 열리면 아이템의 checksum 도 함께 넘겨야 한다.
    "
    "   돌려받은 예외 ID 를 rs_result-extexemptid 에 담아야 한다. 이 값이 없으면
    "   나중에 철회/연장할 때 표준 쪽 레코드를 다시 찾을 수 없다.

    DATA(lo_controller) = get_controller( ).

    rs_result = VALUE #(
      success = abap_false
      message = |표준 예외 반영 보류: 예외 컨트롤러 메소드 미구현. | &&
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
