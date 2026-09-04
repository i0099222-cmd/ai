"! <p class="shorttext synchronized">APJ 컨버전 공통 타입</p>
"!
"! AS-IS(ZBCS0011 헤더 + ZBCS0012 스텝)를 Application Job Framework 위에서
"! 재현하기 위한 계약.
"!
"! 핵심 설계:
"!   APJ 파라미터(tt_templ_val)는 selname/low/high 구조라 테이블을 못 넘긴다.
"!   그래서 스텝 목록은 ZTJOB_STEP 에 저장하고, APJ 에는 잡 정의 ID(P_DEFID)
"!   하나만 넘긴다. 런처가 그 ID 로 DEF/STEP 을 읽어 실행한다.
INTERFACE zif_bc_job
  PUBLIC.

  "! APJ 실행 클래스 파라미터 - 딱 하나뿐이다.
  CONSTANTS:
    BEGIN OF gc_param,
      def_id TYPE c LENGTH 8 VALUE 'P_DEFID',
    END OF gc_param.

  "! 스텝 종류
  CONSTANTS:
    BEGIN OF gc_pgtype,
      abap_program TYPE c LENGTH 4 VALUE 'PROG',
      ext_command  TYPE c LENGTH 4 VALUE 'CMD',
      ext_program  TYPE c LENGTH 4 VALUE 'EXT',
    END OF gc_pgtype.

  "! 실행 이력 상태
  CONSTANTS:
    BEGIN OF gc_status,
      scheduled TYPE c LENGTH 1 VALUE 'S',
      running   TYPE c LENGTH 1 VALUE 'R',
      finished  TYPE c LENGTH 1 VALUE 'F',
      error     TYPE c LENGTH 1 VALUE 'E',
      cancelled TYPE c LENGTH 1 VALUE 'C',
      skipped   TYPE c LENGTH 1 VALUE 'K',  "! 실행 조건 불충족으로 건너뜀
      unknown   TYPE c LENGTH 1 VALUE '?',
    END OF gc_status.

  "! 런처가 실행을 건너뛴 사유
  CONSTANTS:
    BEGIN OF gc_skip,
      none        TYPE c LENGTH 1 VALUE ' ',
      after_close TYPE c LENGTH 1 VALUE 'C',  "! laststrtdt/tm 초과
      not_workday TYPE c LENGTH 1 VALUE 'W',  "! 팩토리 캘린더 비작업일
      no_step     TYPE c LENGTH 1 VALUE 'N',  "! 스텝 없음
      def_missing TYPE c LENGTH 1 VALUE 'D',  "! 잡 정의 없음
    END OF gc_skip.

  "! 스텝 1건 실행 결과
  TYPES:
    BEGIN OF ty_step_result,
      step_no   TYPE i,
      pg_id     TYPE c LENGTH 40,
      pg_variant TYPE c LENGTH 14,
      success   TYPE abap_bool,
      message   TYPE string,
    END OF ty_step_result,
    tt_step_result TYPE STANDARD TABLE OF ty_step_result WITH EMPTY KEY.

  "! 런처 1회 실행 요약
  TYPES:
    BEGIN OF ty_run_summary,
      def_id     TYPE sysuuid_x16,
      skipped    TYPE abap_bool,
      skip_reason TYPE c LENGTH 1,
      requested  TYPE i,
      executed   TYPE i,
      failed     TYPE i,
      t_step     TYPE tt_step_result,
    END OF ty_run_summary.

ENDINTERFACE.
