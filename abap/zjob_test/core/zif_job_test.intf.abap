"! <p class="shorttext synchronized">배치잡 비교 테스트 공통 타입</p>
"!
"! Application Job(ZCL_APJ_JOB_TEST)과 클래식 리포트(ZR_JOB_TEST)가 동일한
"! 코어(ZCL_JOB_TEST_CORE)를 호출하기 위한 계약.
"! 두 스케줄링 방식의 "차이"만 보려면 실행되는 로직은 완전히 같아야 하므로
"! 파라미터/결과 타입을 여기 한 곳에만 둔다.
"!
"! 업무 로직은 일부러 없다. 잡이 하는 일은 "실행 컨텍스트를 ZTJOB_PROBE 에
"! 기록"하는 것뿐이고, 그 기록을 비교하는 게 테스트의 전부다.
INTERFACE zif_job_test
  PUBLIC.

  "! 잡 1회 실행 파라미터
  TYPES:
    BEGIN OF ty_run_params,
      run_tag    TYPE c LENGTH 20,  "! 테스트 케이스 식별 태그 (예: 'TC03-EVENT')
      rec_count  TYPE i,            "! 남길 프로브 레코드 건수
      sleep_secs TYPE i,            "! 레코드 사이 지연(초) - 취소/모니터링 테스트용
      force_fail TYPE abap_bool,    "! 'X' = 강제 오류 종료 - 상태값 비교용
    END OF ty_run_params.

  "! 호출자가 채워주는 실행 컨텍스트.
  "! sy-batch / sy-host 같은 필드는 ABAP Cloud 언어버전에서 못 읽으므로,
  "! 클래식 리포트(Standard ABAP)에서만 채워서 넘긴다. 그 자체가 비교 결과다.
  TYPES:
    BEGIN OF ty_context,
      schedule_mode TYPE c LENGTH 1,   "! A = Application Job, C = Classic(SM36)
      job_name      TYPE c LENGTH 32,
      job_count     TYPE c LENGTH 8,
      host          TYPE c LENGTH 32,  "! sy-host  (Standard ABAP 에서만)
      is_batch      TYPE abap_bool,    "! sy-batch (Standard ABAP 에서만)
    END OF ty_context.

  "! 프로브 1건 기록 결과
  TYPES:
    BEGIN OF ty_probe_result,
      seq_no  TYPE i,
      stamp   TYPE utclong,
      message TYPE string,
    END OF ty_probe_result,
    tt_probe_result TYPE STANDARD TABLE OF ty_probe_result WITH EMPTY KEY.

  "! 잡 실행 요약
  TYPES:
    BEGIN OF ty_run_summary,
      run_tag   TYPE c LENGTH 20,
      requested TYPE i,
      written   TYPE i,
      failed    TYPE abap_bool,
      started   TYPE utclong,
      finished  TYPE utclong,
      t_result  TYPE tt_probe_result,
    END OF ty_run_summary.

  "! Application Job 파라미터 이름(SELNAME, 최대 8자리).
  "! 클래식 리포트의 PARAMETERS 이름과 일부러 동일하게 맞춰뒀다.
  CONSTANTS:
    BEGIN OF gc_param,
      run_tag    TYPE c LENGTH 8 VALUE 'P_TAG',
      rec_count  TYPE c LENGTH 8 VALUE 'P_COUNT',
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
