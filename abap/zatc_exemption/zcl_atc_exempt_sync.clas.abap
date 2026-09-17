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
"! 확인된 컨트롤러 메소드
"!   create_exemption( i_object_type, i_object_name, i_check_class,
"!                     i_check_code, i_contact_person )   <- 이 5개가 필수
"!   approve_exemptions_by_if( exemptions_for_approval )  <- 테이블 일괄 승인
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

    " 확인된 필수 파라미터 (기존 샘플 프로그램이 쓰는 컨트롤러와 동일)
    "   i_object_type / i_object_name / i_check_class / i_check_code / i_contact_person
    "
    " 여기서 드러나는 두 가지
    "   1) 오브젝트가 필수다. 즉 표준 예외는 오브젝트 단위로 만들어진다.
    "   2) 체크 클래스와 체크 코드가 필수다. "변형 전체 면제" 같은 건 없고
    "      어느 체크의 어느 메시지인지를 반드시 지정해야 한다.
    "      -> 우리 신청서에서도 CheckId / MessageId 를 필수로 받는다.

    DATA(lo_controller) = get_controller( ).

    CASE is_exemption-scopetype.

      WHEN zif_atc_exemption=>scope-obj.
        " 오브젝트 1건 -> 표준 예외 1건. 파라미터가 그대로 대응된다.

        " TODO 실제 호출로 교체. 남은 확인 사항은 선택 파라미터다.
        "   유효기간 / 사유 / 승인자 / 적용범위를 넘기는 선택 파라미터가 있는지,
        "   그리고 반환값에서 예외 ID 를 어떻게 받는지.
        "
        " lo_controller->create_exemption(
        "   i_object_type    = is_exemption-objecttype
        "   i_object_name    = is_exemption-objectname
        "   i_check_class    = is_exemption-checkid
        "   i_check_code     = is_exemption-messageid
        "   i_contact_person = is_exemption-requester
        "   " + 선택 파라미터: validto / reasoncode / reasontext / approver / scope
        " ).

      WHEN zif_atc_exemption=>scope-pckg.
        " 미확정 지점.
        "
        " 필수 파라미터에 패키지가 없고 오브젝트가 필수라는 것은, 표준 예외가
        " 오브젝트 단위로 만들어진다는 뜻이다. 패키지 스코프를 표준에 넘기는
        " 방법은 둘 중 하나다.
        "
        "   (a) 선택 파라미터로 적용범위(PCKG)를 넘길 수 있다
        "       -> 표준 예외 1건으로 끝난다. 향후 생성 오브젝트도 표준이 알아서 덮는다.
        "       -> 지금 구조 그대로 (헤더에 예외 ID 1개)
        "
        "   (b) 넘길 수 없다 (오브젝트 단위 생성만 가능)
        "       -> 승인 시 그 패키지의 위반 오브젝트마다 예외를 N건 만들어야 한다.
        "       -> 그러면 예외 ID 가 아이템으로 내려가고,
        "          향후 생성되는 오브젝트는 덮이지 않으므로 주기 배치로 재전개해야 한다.
        "       -> 기존 샘플이 아이템마다 exemption_id / item_state / failure_id 를
        "          들고 있는 이유가 이것일 수 있다.
        "
        " 선택 파라미터 목록을 확인해 (a)/(b) 를 확정한 뒤 구현한다.
        " i_object_type 에 'DEVC'(패키지)를 넣는 방식이 가능한지도 같이 본다.

      WHEN zif_atc_exemption=>scope-fnd.
        " Phase 2. 아이템의 checksum 을 넘기는 선택 파라미터가 있는지 확인 후 구현.

    ENDCASE.

    rs_result = VALUE #(
      success = abap_false
      message = |표준 예외 반영 보류: 선택 파라미터 확인 필요. | &&
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
