"! <p class="shorttext synchronized">배치잡 비교 테스트 공통 타입</p>
"!
"! Application Job(ZCL_APJ_JOB_TEST)과 클래식 리포트(ZR_JOB_TEST)가 동일한
"! 코어(ZCL_JOB_TEST_CORE)를 호출하기 위한 계약.
"! 두 스케줄링 방식의 "차이"만 보려면 실행되는 로직은 완전히 같아야 하므로
"! 파라미터/결과 타입을 여기 한 곳에만 둔다.
"!
"! 잡이 하는 일은 잡 로그에 메시지를 찍는 것뿐이다.
"! 비교 대상은 그래서 "SM37 > Job log" vs "Application Jobs 앱의 로그" 가 된다.
INTERFACE zif_job_test
  PUBLIC.

  TYPES tt_message TYPE STANDARD TABLE OF string WITH EMPTY KEY.

  "! 잡 1회 실행 파라미터
  TYPES:
    BEGIN OF ty_run_params,
      run_tag    TYPE c LENGTH 20,  "! 테스트 케이스 식별 태그 (예: 'TC03-EVENT')
      msg_count  TYPE i,            "! 찍을 메시지 건수
      sleep_secs TYPE i,            "! 메시지 사이 지연(초) - 취소/모니터링 테스트용
      force_fail TYPE abap_bool,    "! 'X' = 강제 오류 종료 - 상태 표기 비교용
    END OF ty_run_params.

  "! 호출자가 채워주는 실행 컨텍스트.
  "! sy-batch / sy-host 는 ABAP Cloud 언어버전에서 못 읽으므로 클래식 리포트
  "! (Standard ABAP)만 채워서 넘긴다. 그 차이 자체가 비교 결과다.
  TYPES:
    BEGIN OF ty_context,
      schedule_mode TYPE c LENGTH 1,   "! A = Application Job, C = Classic(SM36)
      job_name      TYPE c LENGTH 32,
      job_count     TYPE c LENGTH 8,
      host          TYPE c LENGTH 32,  "! sy-host  (Standard ABAP 에서만)
      is_batch      TYPE abap_bool,    "! sy-batch (Standard ABAP 에서만)
    END OF ty_context.

  "! 실행 요약. t_message 는 찍은 메시지 그대로 - 클래식 리포트가
  "! 스풀 리스트로 한 번 더 뿌리는 데 쓴다.
  TYPES:
    BEGIN OF ty_run_summary,
      run_tag   TYPE c LENGTH 20,
      requested TYPE i,
      written   TYPE i,
      t_message TYPE tt_message,
    END OF ty_run_summary.

  "! Application Job 파라미터 이름(SELNAME, 최대 8자리).
  "! 클래식 리포트의 PARAMETERS 이름과 일부러 동일하게 맞춰뒀다.
  CONSTANTS:
    BEGIN OF gc_param,
      run_tag    TYPE c LENGTH 8 VALUE 'P_TAG',
      msg_count  TYPE c LENGTH 8 VALUE 'P_COUNT',
      sleep_secs TYPE c LENGTH 8 VALUE 'P_SLEEP',
      force_fail TYPE c LENGTH 8 VALUE 'P_FAIL',
    END OF gc_param.

  "! 스케줄 방식
  CONSTANTS:
    BEGIN OF gc_mode,
      app_job TYPE c LENGTH 1 VALUE 'A',
      classic TYPE c LENGTH 1 VALUE 'C',
    END OF gc_mode.

  "! 잡 실행 상태 (ZTJOB_RUN-JOB_STATUS)
  CONSTANTS:
    BEGIN OF gc_status,
      scheduled TYPE c LENGTH 1 VALUE 'S',
      running   TYPE c LENGTH 1 VALUE 'R',
      finished  TYPE c LENGTH 1 VALUE 'F',
      error     TYPE c LENGTH 1 VALUE 'E',
      cancelled TYPE c LENGTH 1 VALUE 'C',
      unknown   TYPE c LENGTH 1 VALUE '?',
    END OF gc_status.

  "! 잡 1회 실행. Application Job / 클래식 리포트 양쪽에서 동일하게 호출.
  METHODS run
    IMPORTING
      is_params         TYPE ty_run_params
      is_context        TYPE ty_context
    RETURNING
      VALUE(rs_summary) TYPE ty_run_summary
    RAISING
      cx_static_check.

ENDINTERFACE.
