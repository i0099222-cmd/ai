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
"!          set_reason( )            i_reason(코드, 필수) / i_comment(서술)
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

    "! 상신된 예외를 표준 저장소에 **승인대기 상태로** 생성한다.
    "! 표준의 모델이 "신청 시점에 행이 생기고 승인은 그 행의 상태를 바꾸는 것"
    "! 이므로 우리도 같은 시점에 만든다. 그래야 승인자에게 표준 알림이 가고,
    "! 개발자가 ADT/표준 앱에서도 자기 신청 건을 볼 수 있다.
    METHODS create_exemption
      IMPORTING is_exemption     TYPE ztatcexempt
      RETURNING VALUE(rs_result) TYPE ty_result.

    "! 표준 저장소의 예외를 승인한다. 이 시점에 ATC 차단이 실제로 풀린다.
    METHODS approve_exemption
      IMPORTING iv_extexemptid   TYPE sysuuid_c32
                iv_assessment    TYPE string OPTIONAL
      RETURNING VALUE(rs_result) TYPE ty_result.

    "! 신청자가 상신을 철회한다.
    "!
    "! 승인자의 반려가 아니라 신청자의 삭제다.
    "!   controller->get_exemption( <예외 ID> )->delete( )
    "!
    "! 앞서 두 번 틀렸다. 남겨 둔다 - 같은 길로 다시 가지 않기 위해서다.
    "!   1) reject_exemptions_by_id( ) : 오류도 없고 아무 일도 없었다.
    "!      state 는 OPEN 그대로, assessment 도 기록되지 않았다. 승인자의
    "!      동사이고, 승인자가 집어들지 않은 건에는 걸리지 않는 것으로 보인다.
    "!   2) create_exemption( <같은 자연키> )->delete( ) : 핸들은 열렸지만
    "!      delete( ) 가 "the operation cannot be executed in the current
    "!      state" 로 거부됐다. create 는 기존 행을 여는 것이 아니라 새
    "!      전이 객체를 만든다. 저장된 적 없는 객체는 지울 것이 없다.
    "!
    "! 그래서 컨트롤러에 create_exemption 과 get_exemption 이 따로 있다.
    "! 기존 건은 예외 ID 로 열어야 하고, 그 ID 는 상신 때 ztatcexempt-
    "! extexemptid 에 받아 두었다.
    METHODS withdraw_exemption
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

    "! 예외 ID 로 표준 예외를 열어 삭제한다.
    "!
    "! 철회(신청자)와 무효화(대장 철회/만료)가 같은 동작이다. 어느 쪽이든
    "! 그 예외는 더 이상 존재해서는 안 되고, 감사 흔적은 CBO 이력이 든다 -
    "! 표준 쪽에 반려 상태로 남겨 두는 것은 우리 대장과 이중 기록이 된다.
    METHODS delete_by_id
      IMPORTING iv_extexemptid   TYPE sysuuid_c32
                iv_note          TYPE string
      RETURNING VALUE(rs_result) TYPE ty_result.

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

    " 승인자를 TRY 밖에서 정한다. 안에서 정하면 그 줄 이전에 예외가 났을 때
    " 실패 메시지가 "승인자 비어 있음" 으로 잘못 나온다.
    DATA(lv_approver) = COND syuname(
      WHEN is_exemption-approver IS NOT INITIAL THEN is_exemption-approver
      ELSE ls_config-defapprover ).

    TRY.

        " 신청서의 checkclass / checkcode 는 표준 예외 뷰
        " SATC_CI_R_EXEMPTION 과 같은 형태의 값이다 (CL_CI_TEST_DB / DBREAD).
        " 여기서는 그대로 넘긴다.
        "
        " 두 값은 findings 뷰에 없어서 ZCL_ATC_CHECK_RESOLVER 가 환산하거나,
        " 환산되지 않으면 사용자가 신청 화면에서 직접 채운다. 어느 쪽이든
        " 저장 시점의 필수 검증을 통과한 뒤에만 이 메서드에 도달한다.
        DATA(lo_exemption) = lo_controller->create_exemption(
          i_object_type    = is_exemption-objecttype
          i_object_name    = is_exemption-objectname
          i_check_class    = is_exemption-checkclass
          i_check_code     = is_exemption-checkcode
          i_contact_person = is_exemption-requester ).

        " SATC_CI_OBJ_SCOPE 의 고정값이 우리 scopetype( FND / OBJ / PCKG )과
        " 같음을 확인했으므로 변환 없이 넘긴다.
        lo_exemption->set_object_scope( CONV #( is_exemption-scopetype ) ).

        " 체크 축은 MSG / CHK / ALL / FND 중 하나다. 신청서는 MSG / CHK 만 쓴다.
        lo_exemption->set_check_scope( CONV #( is_exemption-rulescope ) ).

        " set_reason 은 코드와 서술을 따로 받는다.
        "   i_reason  (필수) 사유 코드
        "   i_comment        자유 서술
        " 위치 인자로 넘기면 서술이 코드 자리로 들어간다. 이름으로 넘긴다.
        "
        " 🔴 확인 필요: i_reason 의 타입과 고정값 목록.
        "   우리 reasoncode 는 CHAR4 이지만 값 목록을 정한 곳이 없다.
        "   표준에 고정값이 있으면 그 값을 그대로 ztatcexempt-reasoncode 의
        "   도메인 고정값으로 삼는다. 그래야 매핑 없이 양쪽이 같은 값을 쓰고,
        "   Fiori 화면에도 별도 값 도움 뷰 없이 드롭다운이 생긴다.
        lo_exemption->set_reason( i_reason  = CONV #( is_exemption-reasoncode )
                                  i_comment = is_exemption-reasontext ).
        lo_exemption->set_validity_date( is_exemption-validto ).
        " 표준은 승인자 1명을 필수로 요구한다. 상신 시점에는 아직 결재자가
        " 정해지지 않았으므로(우리 앱은 권한으로 판정한다) 설정의 기본 승인자를
        " 쓴다. 승인이 끝나면 approve_exemption_by_id( ) 가 실제 결재자를 남긴다.
        lo_exemption->set_approver( i_approver = lv_approver ).

        " 알림 유형은 조직 정책이므로 컨트롤 테이블에서 읽는다.
        lo_exemption->set_notification_type(
          COND #( WHEN ls_config-notiftype IS NOT INITIAL
                  THEN ls_config-notiftype
                  ELSE zif_atc_exemption=>notification-never ) ).

        " 승인 요청을 보낸 뒤 잠금을 푼다. 여기서 끝이다 - 승인은 별도다.
        " 결재가 끝나기 전에 승인해 버리면 표준의 알림도 승인 상태도 무의미해진다.
        lo_exemption->send_to_approver( ).
        lo_exemption->unlock( ).

        " SATC_CI_EXEMPTION_ID (SYSUUID_C32)
        DATA(lv_exemption_id) = lo_exemption->get_exemption_id( ).

        rs_result = VALUE #( success     = abap_true
                             extexemptid = lv_exemption_id
                             message     = |표준 예외 { lv_exemption_id } 생성(승인대기)| ).

      CATCH cx_root INTO DATA(lo_error).
        " 실패 경로에서도 잠금을 푼다. 열어 놓고 나가면 그 예외는 잠긴 채로
        " 남고, 다음 시도는 상태가 아니라 잠금 때문에 실패한다. 무엇 때문에
        " 실패했는지 두 번 헷갈리게 된다.
        IF lo_exemption IS BOUND.
          TRY.
              lo_exemption->unlock( ).
            CATCH cx_root ##NO_HANDLER.
          ENDTRY.
        ENDIF.

        " 표준 반영이 실패해도 CBO 기록은 남긴다. 대장이 원천이고 표준 반영은
        " 뒤따르는 구조이기 때문이다. 실패 사유는 이력에 적힌다.
        "
        " 승인자를 메시지에 같이 남긴다. 표준 오류 대부분이 승인자 때문인데,
        " 값이 안 넘어간 것인지 그 사용자에게 권한이 없는 것인지를 로그만
        " 보고 구분할 수 없으면 매번 디버깅해야 한다.
        rs_result = VALUE #(
          success = abap_false
          message = |{ lo_error->get_text( ) } | &&
                    |[승인자: { COND string( WHEN lv_approver IS INITIAL
                                             THEN '(비어 있음)' ELSE lv_approver ) }]| ).
    ENDTRY.

  ENDMETHOD.


  METHOD approve_exemption.

    " 표준 예외를 승인한다. CBO 대장에서 결재가 끝난 뒤 그 결과를 표준에
    " 반영하는 단계이고, ATC 가 실제로 이 건을 면제하기 시작하는 지점이다.

    DATA(lo_controller) = get_controller( ).

    TRY.

        lo_controller->approve_exemption_by_id(
          exemption_id = iv_extexemptid
          assessment   = iv_assessment ).

        rs_result = VALUE #( success     = abap_true
                             extexemptid = iv_extexemptid
                             message     = |표준 예외 { iv_extexemptid } 승인| ).

      CATCH cx_root INTO DATA(lo_error).
        rs_result = VALUE #( success = abap_false
                             message = lo_error->get_text( ) ).
    ENDTRY.

  ENDMETHOD.


  METHOD withdraw_exemption.

    " 상신이 표준까지 가지 못한 건이면 지울 표준 건도 없다. 실패로 두면
    " CBO 쪽 철회까지 막혀서, 표준에 없는 신청을 영구히 철회할 수 없게 된다.
    IF is_exemption-extexemptid IS INITIAL.
      rs_result = VALUE #( success = abap_true
                           message = |표준 예외 없음 - CBO 철회만 수행| ).
      RETURN.
    ENDIF.

    rs_result = delete_by_id( iv_extexemptid = is_exemption-extexemptid
                              iv_note        = |신청자 철회| ).

  ENDMETHOD.


  METHOD revoke_exemption.

    " 표준 쪽 예외도 함께 없애야 한다. CBO 만 철회하면 대장은 철회인데
    " 실제로는 계속 면제되는 상태로 남는다.
    "
    " reject_exemptions_by_id( ) 를 쓰던 자리다. 그 메서드는 오류 없이
    " 아무 일도 하지 않는다(철회 테스트에서 확인). 삭제로 바꾼다.
    IF iv_extexemptid IS INITIAL.
      rs_result = VALUE #( success = abap_true
                           message = |표준 예외 없음 - CBO 무효화만 수행| ).
      RETURN.
    ENDIF.

    rs_result = delete_by_id(
      iv_extexemptid = iv_extexemptid
      iv_note        = COND string( WHEN iv_reason IS NOT INITIAL
                                    THEN |무효화: { iv_reason }|
                                    ELSE |무효화| ) ).

  ENDMETHOD.


  METHOD delete_by_id.

    DATA(lo_controller) = get_controller( ).

    TRY.

        " 파라미터가 예외 ID 하나뿐이라 위치 인자로 넘긴다.
        DATA(lo_exemption) = lo_controller->get_exemption( iv_extexemptid ).

      CATCH cx_root INTO DATA(lo_open_error).
        rs_result = VALUE #(
          success = abap_false
          message = |표준 예외 { iv_extexemptid } 열기 실패: | &&
                    lo_open_error->get_text( ) ).
        RETURN.
    ENDTRY.

    " 여기서부터는 무엇이 실패하든 잠금을 풀고 나간다. 열어 놓고 나가면
    " 그 예외는 잠긴 채로 남고, 다음 시도는 상태가 아니라 잠금 때문에
    " 실패한다. 무엇 때문에 실패했는지 두 번 헷갈리게 된다.
    TRY.

        DATA(lv_state) = lo_exemption->get_exemption_state( ).

        lo_exemption->delete( ).

        rs_result = VALUE #( success     = abap_true
                             extexemptid = iv_extexemptid
                             message     = |표준 예외 삭제({ iv_note }, state={ lv_state })| ).

      CATCH cx_root INTO DATA(lo_del_error).
        " state 를 같이 남긴다. 여기서 또 거부되면 원인은 "저장되지 않은
        " 객체"가 아니라 상태기계다 - OPEN(승인자에게 넘어간 상태)에서는
        " 신청자가 지울 수 없다는 뜻이고, 그러면 상신 시 send_to_approver( )
        " 를 승인 시점으로 미뤄 표준 행을 APPL 로 두는 쪽으로 바꿔야 한다.
        rs_result = VALUE #(
          success = abap_false
          message = |{ iv_note } 실패 [state={ COND string( WHEN lv_state IS INITIAL
                                                            THEN '(읽지 못함)'
                                                            ELSE lv_state ) }]: | &&
                    lo_del_error->get_text( ) ).
    ENDTRY.

    TRY.
        lo_exemption->unlock( ).
      CATCH cx_root ##NO_HANDLER.
        " 잠금 해제 실패는 결과를 뒤집지 않는다. 다음 접근에서 드러난다.
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
