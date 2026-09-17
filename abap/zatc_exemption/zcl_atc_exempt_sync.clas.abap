"! 승인된 예외를 표준 ATC 예외 저장소에 반영하는 어댑터.
"!
"! 설계 전제: 관리는 CBO, 실행은 표준.
"!   - 신청/승인/이력/권한은 CBO 테이블이 원천이다 (감사 대응, 자사 통제).
"!   - 억제 자체는 표준 메커니즘이 한다. 커스텀 체크 클래스는 만들지 않는다.
"!     표준 네이밍 체크를 대체하면 표준 개선/노트 수혜를 잃고 유지보수 책임만 넘어온다.
"!
"! TODO 확인 필요 (착수 전 최우선): 표준 예외 생성 API 존재 여부.
"!   찾는 방법
"!     1) 표준 Fiori 앱 "Approve ATC Exemptions" 의 OData 서비스를 추적한다.
"!        /IWFND/MAINT_SERVICE 에서 서비스명을 찾고, ADT 에서 구현 클래스를 연다.
"!        승인/반려 시 호출하는 클래스·메소드가 곧 여기서 호출할 API 다.
"!     2) ADT 에서 SATC_API* / CL_SATC_*API* / SATC*EXEMPT* 를 검색한다.
"!   결과에 따른 분기
"!     있음 -> 아래 create_exemption / revoke_exemption 을 그 API 로 구현한다.
"!     없음 -> 표준 반영을 포기하고 조회/거버넌스 전용으로 후퇴한다.
"!             (커스텀 체크 클래스로 우회하지 않는다 - 설계 원칙 위반)
"!
"! API 가 확인되기 전까지 이 클래스는 "미구현" 을 돌려준다. 그래도 승인 자체는
"! 정상 동작하며 CBO 대장에는 기록이 남는다. 표준 반영만 보류될 뿐이다.
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

ENDCLASS.


CLASS zcl_atc_exempt_sync IMPLEMENTATION.

  METHOD create_exemption.

    " TODO 표준 예외 생성 API 확인 후 구현.
    "   전달해야 할 값: scopetype, devclass, objecttype, objectname,
    "                   checkid, messageid, rulescope, reasoncode, reasontext,
    "                   validfrom, validto
    "   FND 스코프까지 열리면 finding 식별자(resultid/itemid)도 함께 넘겨야 한다.
    "   돌려받은 예외 ID 를 ztatcexempt-extexemptid 에 저장해야 철회/연장 시
    "   표준 쪽 레코드를 다시 찾을 수 있다.

    rs_result = VALUE #(
      success = abap_false
      message = |표준 예외 반영 보류: 예외 생성 API 미확인. | &&
                |CBO 대장에는 승인 기록이 저장되었습니다.| ).

  ENDMETHOD.


  METHOD revoke_exemption.

    " TODO create_exemption 과 동일한 API 확인 후 구현.

    rs_result = VALUE #(
      success = abap_false
      message = |표준 예외 무효화 보류: 예외 무효화 API 미확인.| ).

  ENDMETHOD.


  METHOD sync_from_standard.

    " TODO 표준 예외 조회 경로 확인 후 구현.
    "   1) 표준 저장소에서 예외 목록을 읽는다.
    "   2) ztatcexempt-extexemptid 에 없는 건을 CBO 대장에 등록한다
    "      (출처를 구분할 수 있게 이력에 SYNC 로 남긴다).
    "   3) CBO 에는 승인 상태인데 표준에 없는 건을 불일치로 리포트한다.

    rv_synced = 0.

  ENDMETHOD.

ENDCLASS.
