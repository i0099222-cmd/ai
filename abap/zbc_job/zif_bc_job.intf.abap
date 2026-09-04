"! <p class="shorttext synchronized">배치잡 공통 상수/타입</p>
INTERFACE zif_bc_job
  PUBLIC.

  "! APJ 실행 클래스 파라미터.
  "! 스케줄 행의 UUID 하나만 넘기고, 런처가 그 UUID 로 ZTJOB_RUN 을 읽어
  "! 무엇을 어떤 조건으로 실행할지 판단한다.
  CONSTANTS:
    BEGIN OF gc_param,
      run_id TYPE c LENGTH 8 VALUE 'P_RUNID',
    END OF gc_param.

  "! 실행 대상 종류 (AS-IS pgtype)
  CONSTANTS:
    BEGIN OF gc_pgtype,
      abap_program TYPE c LENGTH 4 VALUE 'PROG',
      ext_command  TYPE c LENGTH 4 VALUE 'CMD',
      ext_program  TYPE c LENGTH 4 VALUE 'EXT',
    END OF gc_pgtype.

  "! ZTJOB_RUN-JOB_STATUS
  CONSTANTS:
    BEGIN OF gc_status,
      initial   TYPE c LENGTH 1 VALUE ' ',   "! 아직 스케줄 안 함
      scheduled TYPE c LENGTH 1 VALUE 'S',
      running   TYPE c LENGTH 1 VALUE 'R',
      finished  TYPE c LENGTH 1 VALUE 'F',
      error     TYPE c LENGTH 1 VALUE 'E',
      cancelled TYPE c LENGTH 1 VALUE 'C',
      skipped   TYPE c LENGTH 1 VALUE 'K',   "! 실행 조건 불충족
      unknown   TYPE c LENGTH 1 VALUE '?',
    END OF gc_status.

  "! 런처가 실행을 건너뛴 사유
  CONSTANTS:
    BEGIN OF gc_skip,
      none        TYPE c LENGTH 1 VALUE ' ',
      after_close TYPE c LENGTH 1 VALUE 'C',  "! last_start 시각 초과
      not_workday TYPE c LENGTH 1 VALUE 'W',  "! 팩토리 캘린더 비작업일
      no_program  TYPE c LENGTH 1 VALUE 'N',  "! 실행 대상 없음
      run_missing TYPE c LENGTH 1 VALUE 'D',  "! 스케줄 행 없음
      unsupported TYPE c LENGTH 1 VALUE 'U',  "! APJ 로 실행 불가한 종류
    END OF gc_skip.

  "! 런처 1회 실행 결과
  TYPES:
    BEGIN OF ty_run_result,
      run_uuid    TYPE sysuuid_x16,
      skipped     TYPE abap_bool,
      skip_reason TYPE c LENGTH 1,
      success     TYPE abap_bool,
      pg_id       TYPE c LENGTH 40,
      message     TYPE string,
    END OF ty_run_result.

ENDINTERFACE.
