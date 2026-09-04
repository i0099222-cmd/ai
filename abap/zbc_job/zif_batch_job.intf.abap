"! <p class="shorttext synchronized">배치잡 공통 상수/타입</p>
INTERFACE zif_batch_job
  PUBLIC.

  "! APJ 실행 클래스 파라미터.
  "! 스케줄 행의 UUID 하나만 넘기고, 런처가 그 UUID 로 ZTBATCH_SCHED 을 읽는다.
  CONSTANTS:
    BEGIN OF gc_param,
      run_id TYPE c LENGTH 8 VALUE 'P_RUNID',
    END OF gc_param.

  "! APJ 잡 상태 (adapter 가 정규화해서 돌려주는 값)
  CONSTANTS:
    BEGIN OF gc_status,
      scheduled TYPE c LENGTH 1 VALUE 'S',
      running   TYPE c LENGTH 1 VALUE 'R',
      finished  TYPE c LENGTH 1 VALUE 'F',
      error     TYPE c LENGTH 1 VALUE 'E',
      cancelled TYPE c LENGTH 1 VALUE 'C',
      unknown   TYPE c LENGTH 1 VALUE '?',
    END OF gc_status.

  "! 런처가 실행을 건너뛴 사유
  CONSTANTS:
    BEGIN OF gc_skip,
      none        TYPE c LENGTH 1 VALUE ' ',
      after_close TYPE c LENGTH 1 VALUE 'C',  "! close 시각 초과
      not_workday TYPE c LENGTH 1 VALUE 'W',  "! 팩토리 캘린더 비작업일
      no_class    TYPE c LENGTH 1 VALUE 'N',  "! 실행 클래스 미지정
      run_missing TYPE c LENGTH 1 VALUE 'D',  "! 스케줄 행 없음
      bad_class   TYPE c LENGTH 1 VALUE 'X',  "! 클래스 생성 실패
    END OF gc_skip.

  "! ZTBATCH_SCHED-PARAM 에 JSON 으로 담기는 내용.
  "! cond = 런처가 읽는 실행 조건 / app = 스텝 클래스에 그대로 넘기는 업무 파라미터
  TYPES:
    BEGIN OF ty_condition,
      calendar_id     TYPE c LENGTH 2,   "! 공장시간 (팩토리 캘린더)
      workday_nr      TYPE i,            "! 공장근무일수
      workday_time    TYPE t,            "! 공장근무시간
      last_start_date TYPE d,            "! close 일
      last_start_time TYPE t,            "! close 시각
    END OF ty_condition.

  TYPES:
    BEGIN OF ty_param,
      cond TYPE ty_condition,   "! 런처가 읽는 실행 조건
      app  TYPE string,         "! 스텝 클래스에 넘길 업무 파라미터 (배리언트 대체)
    END OF ty_param.

  "! 스케줄 옵션. 액션 파라미터로만 존재하고 DB 에 저장하지 않는다.
  TYPES:
    BEGIN OF ty_start_option,
      start_immediately TYPE abap_bool,
      start_date        TYPE d,
      start_time        TYPE t,
      timezone          TYPE c LENGTH 6,
      prd_mins          TYPE i,
      prd_hours         TYPE i,
      prd_days          TYPE i,
      prd_weeks         TYPE i,
      prd_months        TYPE i,
    END OF ty_start_option.

  "! 런처 1회 실행 결과
  TYPES:
    BEGIN OF ty_run_result,
      run_uuid    TYPE sysuuid_x16,
      skipped     TYPE abap_bool,
      skip_reason TYPE c LENGTH 1,
      success     TYPE abap_bool,
      exec_class  TYPE c LENGTH 30,
      message     TYPE string,
    END OF ty_run_result.

ENDINTERFACE.
