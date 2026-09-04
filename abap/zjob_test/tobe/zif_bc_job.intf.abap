"! <p class="shorttext synchronized">배치잡 스케줄링 공통 타입 (TO-BE)</p>
"!
"! AS-IS 인터페이스(ZBCS0011 헤더 + ZBCS0012 스텝)를 그대로 받되,
"! BDC 대신 표준 FM(JOB_OPEN / JOB_SUBMIT / JOB_CLOSE)으로 처리하기 위한 계약.
"!
"! 언어버전: ABAP for Cloud Development.
"! 실제 JOB_* 호출은 Standard ABAP FM(Z_BC_JOB_*)에 있고, 이 인터페이스는
"! 양쪽이 공유하는 타입만 정의한다.
INTERFACE zif_bc_job
  PUBLIC.

*----------------------------------------------------------------------*
* 요청자 정보 - AS-IS 의 reqid / reqname / reqdatetime
* SAP 잡의 개념이 아니라 이 인터페이스가 추가한 감사 필드다.
* 잡 자체에는 안 들어가고 로그 테이블(ZTJOB_RUN)에만 남는다.
*----------------------------------------------------------------------*
  TYPES:
    BEGIN OF ty_requester,
      req_id       TYPE c LENGTH 12,   "! 요청자 사번
      req_name     TYPE c LENGTH 40,   "! 요청자 이름
      req_datetime TYPE timestampl,    "! 요청 시각
      req_reason   TYPE c LENGTH 255,  "! 요청사유
    END OF ty_requester.

*----------------------------------------------------------------------*
* 잡 헤더 - AS-IS ZBCS0011
*----------------------------------------------------------------------*
  TYPES:
    BEGIN OF ty_header,
      "--- 대상 지정. 표준 잡 개념이 아님 (아래 NOTE 참고)
      sys_id        TYPE c LENGTH 8,   "! 시스템 - 대상 SAP 시스템 (RFC destination 선택용)
      client        TYPE c LENGTH 3,   "! 클라이언트
      biz_area      TYPE c LENGTH 20,  "! 업무구분

      "--- JOB_OPEN
      jobname       TYPE c LENGTH 32,  "! 배치잡 명        -> JOBNAME
      jobclass      TYPE c LENGTH 1,   "! 배치잡 클래스    -> JOBCLASS (A/B/C)
      jobgroup      TYPE c LENGTH 20,  "! 업무구분 매핑    -> JOBGROUP

      "--- 스텝 기본 사용자 (스텝별로 덮어쓸 수 있음)
      jobuser       TYPE c LENGTH 12,  "! 배치유저명       -> JOB_SUBMIT-AUTHCKNAM

      "--- JOB_CLOSE : 시작 조건
      start_immed   TYPE abap_bool,    "! 즉시 시작        -> STRTIMMED
      sdlstrtdt     TYPE d,            "! 시작일           -> SDLSTRTDT
      sdlstrttm     TYPE t,            "! 시작시각         -> SDLSTRTTM
      laststrtdt    TYPE d,            "! close 일         -> LASTSTRTDT
      laststrttm    TYPE t,            "! close 시각       -> LASTSTRTTM
      timezone      TYPE c LENGTH 6,   "! 시스템 zone시간  -> 표준 대응 없음. 호출 전 변환

      "--- JOB_CLOSE : 반복 주기 (하나만 채운다)
      prd_mins      TYPE i,            "! -> PRDMINS
      prd_hours     TYPE i,            "! -> PRDHOURS
      prd_days      TYPE i,            "! 일반복주기 -> PRDDAYS
      prd_weeks     TYPE i,            "! -> PRDWEEKS
      prd_months    TYPE i,            "! -> PRDMONTHS

      "--- JOB_CLOSE : 팩토리 캘린더
      calendar_id   TYPE c LENGTH 2,   "! 공장시간         -> CALENDAR_ID
      workday_nr    TYPE i,            "! 공장근무일수     -> START_ON_WORKDAY_NR
      workday_time  TYPE t,            "! 공장근무시간     -> START_ON_WORKDAY_NOT_BEFORE
      workday_dir   TYPE c LENGTH 1,   "! 근무일 카운트 방향 -> WORKDAY_COUNT_DIRECTION
    END OF ty_header.

*----------------------------------------------------------------------*
* 잡 스텝 - AS-IS ZBCS0012 (lt_pg). 다중 스텝이므로 테이블.
*----------------------------------------------------------------------*
  TYPES:
    BEGIN OF ty_step,
      step_no   TYPE i,
      pg_type   TYPE c LENGTH 4,   "! 'PROG' = ABAP 리포트 (그 외: 외부 커맨드/프로그램)
      jobuser   TYPE c LENGTH 12,  "! 스텝 실행 사용자 -> AUTHCKNAM
      pg_id     TYPE c LENGTH 40,  "! 실행할 리포트    -> REPORT
      pg_variant TYPE c LENGTH 14, "! 배리언트         -> VARIANT
      pg_lang   TYPE c LENGTH 1,   "! 실행 언어        -> LANGUAGE
    END OF ty_step,
    tt_step TYPE STANDARD TABLE OF ty_step WITH EMPTY KEY.

*----------------------------------------------------------------------*
* 결과 - AS-IS 의 status / message
*----------------------------------------------------------------------*
  TYPES:
    BEGIN OF ty_result,
      jobname  TYPE c LENGTH 32,
      jobcount TYPE c LENGTH 8,
      success  TYPE abap_bool,
      status   TYPE c LENGTH 1,   "! ZIF_BC_JOB=>GC_STATUS
      message  TYPE string,
    END OF ty_result.

  "! TBTCO-STATUS 값 (SM37 잡 상태)
  CONSTANTS:
    BEGIN OF gc_status,
      scheduled TYPE c LENGTH 1 VALUE 'P',  "! Scheduled (릴리즈 전)
      released  TYPE c LENGTH 1 VALUE 'S',  "! Released
      ready     TYPE c LENGTH 1 VALUE 'Y',  "! Ready
      running   TYPE c LENGTH 1 VALUE 'R',  "! Active
      finished  TYPE c LENGTH 1 VALUE 'F',  "! Finished
      cancelled TYPE c LENGTH 1 VALUE 'A',  "! Cancelled / Aborted
      unknown   TYPE c LENGTH 1 VALUE '?',
    END OF gc_status.

  "! 스텝 종류
  CONSTANTS:
    BEGIN OF gc_pgtype,
      abap_program TYPE c LENGTH 4 VALUE 'PROG',
      ext_command  TYPE c LENGTH 4 VALUE 'CMD',
      ext_program  TYPE c LENGTH 4 VALUE 'EXT',
    END OF gc_pgtype.

ENDINTERFACE.
