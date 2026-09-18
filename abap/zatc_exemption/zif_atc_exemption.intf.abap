"! ATC 예외 관리 앱 공통 상수/타입.
"! 코드값 리터럴은 전부 여기로 모은다. 표준 도메인 고정값이 릴리즈마다
"! 달라질 수 있으므로, 값 변경 시 이 인터페이스만 고치면 되도록 한다.
INTERFACE zif_atc_exemption
  PUBLIC.

  "! 적용 범위 (set_object_scope, 타입 SATC_CI_OBJ_SCOPE).
  "! ADT "Apply exemption to" 와 1:1 대응하며 표준 고정값과 값이 같음을 확인했다.
  "!   fnd  = Finding                 - Phase 1 비활성 (ztatccfg 의 fndactive 로 제어)
  "!   obj  = ABAP Object
  "!   pckg = All Objects of Package
  "! 표준 도메인 고정값과 일치해야 한다. 'PCKG' 가 4자이므로 필드 길이는 char4 다.
  CONSTANTS:
    BEGIN OF scope,
      fnd  TYPE char4 VALUE 'FND',
      obj  TYPE char4 VALUE 'OBJ',
      pckg TYPE char4 VALUE 'PCKG',
    END OF scope.

  "! 규칙 적용 축 (set_check_scope). 표준 고정값 4종.
  "!   finding = 이 finding 한 건만
  "!   message = 이 메시지만          ADT 화면의 "Message"
  "!   check   = 이 체크의 모든 메시지  ADT 화면의 "Check"
  "!   all     = 모든 체크           <- 이 앱에서는 금지한다
  "!
  "! all 을 허용하면 대상 오브젝트/패키지의 ATC 체크가 통째로 꺼진다.
  "! 네이밍 예외를 신청했는데 성능·보안 체크까지 같이 면제되는 셈이라,
  "! 요건("네이밍 건만")을 정면으로 깬다. validateRuleScope 가 거부한다.
  CONSTANTS:
    BEGIN OF rulescope,
      finding TYPE char3 VALUE 'FND',
      message TYPE char3 VALUE 'MSG',
      check   TYPE char3 VALUE 'CHK',
      all     TYPE char3 VALUE 'ALL',
    END OF rulescope.

  "! 신청서 상태
  CONSTANTS:
    BEGIN OF status,
      draft    TYPE char2 VALUE '10',
      pending  TYPE char2 VALUE '20',
      approved TYPE char2 VALUE '30',
      rejected TYPE char2 VALUE '40',
      revoked  TYPE char2 VALUE '50',
      expired  TYPE char2 VALUE '60',
    END OF status.

  "! 표준 예외의 이메일 알림 유형 (set_notification_type)
  CONSTANTS:
    BEGIN OF notification,
      on_rejection TYPE char4 VALUE 'REJ',
      always       TYPE char4 VALUE 'ALWS',
      never        TYPE char4 VALUE 'NEVR',
    END OF notification.

  "! 이력 액션 코드
  CONSTANTS:
    BEGIN OF logaction,
      create   TYPE char10 VALUE 'CREATE',
      submit   TYPE char10 VALUE 'SUBMIT',
      withdraw TYPE char10 VALUE 'WITHDRAW',
      approve  TYPE char10 VALUE 'APPROVE',
      reject   TYPE char10 VALUE 'REJECT',
      revoke   TYPE char10 VALUE 'REVOKE',
      expire   TYPE char10 VALUE 'EXPIRE',
      sync     TYPE char10 VALUE 'SYNC',
    END OF logaction.

  "! 권한 오브젝트. 필드는 Phase 2 확장을 고려해 처음부터 4개를 모두 둔다.
  "! (권한 오브젝트 필드는 나중에 추가하면 PFCG 역할 전수 재작업이 발생한다)
  CONSTANTS:
    BEGIN OF authobject,
      name       TYPE char10 VALUE 'Z_ATCEXEM',
      actvt_disp TYPE char2  VALUE '03',
      actvt_crea TYPE char2  VALUE '01',
      actvt_chng TYPE char2  VALUE '02',
      actvt_appr TYPE char2  VALUE '43',
    END OF authobject.

  "! 근거 텍스트 최소 길이. 한 줄짜리 형식적 사유를 막는다.
  CONSTANTS min_reason_length TYPE i VALUE 20.

  "! ATC finding 1건
  TYPES:
    BEGIN OF ty_finding,
      checkvariant  TYPE char30,
      devclass      TYPE devclass,
      objecttype    TYPE trobjtype,
      objectname    TYPE sobj_name,
      "! 코드가 바뀌어도 같은 위반이면 유지되는 finding 식별자
      checksum      TYPE i,
      "! findings 뷰가 주는 체크 식별자. 표준 예외 API 가 받는 값과는 다르다.
      "!   moduleid     RAW16  = 체크 GUID
      "!   modulemsgkey CHAR25 = 메시지 키
      moduleid      TYPE sysuuid_x16,
      modulemsgkey  TYPE char25,
      priority      TYPE int1,
      msgtext       TYPE char255,
      contactperson TYPE syuname,
      responsible   TYPE syuname,
    END OF ty_finding,
    tt_finding TYPE STANDARD TABLE OF ty_finding WITH EMPTY KEY.

  "! finding 조회 조건
  TYPES:
    BEGIN OF ty_selection,
      "! 공란이면 활성 변형 전체를 대상으로 한다.
      checkvariant TYPE char30,
      devclass     TYPE devclass,
      inclsubpkg   TYPE abap_boolean,
      objecttype   TYPE trobjtype,
      objectname   TYPE sobj_name,
      moduleid     TYPE sysuuid_x16,
      modulemsgkey TYPE char25,
      "! X 이면 담당자 필터(경로 1). 공란이면 전체(경로 2, 승인자/조회용).
      only_mine    TYPE abap_boolean,
    END OF ty_selection.

  "! 컨트롤 테이블 1행 (ztatccfg). 키는 체크 변형이다.
  "! 승인 레벨은 여기 없다. 권한 오브젝트 Z_ATCEXEM 의 SCOPETYPE 필드가 담당한다.
  TYPES:
    BEGIN OF ty_config,
      checkvariant TYPE char30,
      checkgroup   TYPE char10,
      activeflg    TYPE abap_boolean,
      fndactive    TYPE abap_boolean,
      objactive    TYPE abap_boolean,
      pkgactive    TYPE abap_boolean,
      maxvalidmon  TYPE int2,
      reasonreq    TYPE abap_boolean,
      notiftype    TYPE char4,
      maxpriority  TYPE int1,
    END OF ty_config,
    tt_config TYPE STANDARD TABLE OF ty_config WITH EMPTY KEY.

  TYPES tt_devclass TYPE STANDARD TABLE OF devclass WITH EMPTY KEY.

  "! ABAP SQL 의 IN 은 range 테이블만 받는다.
  TYPES tt_devclass_range TYPE RANGE OF devclass.
  TYPES tt_variant_range  TYPE RANGE OF char30.

  TYPES tt_exempt TYPE STANDARD TABLE OF ztatcexempt WITH EMPTY KEY.

ENDINTERFACE.
