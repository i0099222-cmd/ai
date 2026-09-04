"! <p class="shorttext synchronized">잡 정의 실행기 (런처 코어)</p>
"!
"! ZTJOB_DEF / ZTJOB_STEP 을 읽어서
"!   1) 실행 조건 판정 (close 시각 / 팩토리 캘린더 작업일)
"!   2) 스텝 순서대로 리포트 실행
"! 을 수행한다.
"!
"! 언어버전: ABAP for Cloud Development.
"! SUBMIT 과 팩토리 캘린더 조회는 Standard ABAP FM(Local API released)에 위임한다.
"!   Z_BC_RUN_REPORT     - SUBMIT
"!   Z_BC_CHECK_WORKDAY  - 팩토리 캘린더 판정
"!
"! APJ 실행 클래스(ZCL_APJ_JOB_LAUNCHER)와 분리한 이유:
"! 이 클래스는 APJ 없이도 단위 테스트가 가능해야 하기 때문이다.
CLASS zcl_bc_job_runner DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! 잡 정의 1건을 실행한다.
    METHODS run
      IMPORTING
        iv_def_id         TYPE sysuuid_x16
      RETURNING
        VALUE(rs_summary) TYPE zif_bc_job=>ty_run_summary.

  PRIVATE SECTION.

    "! 실행해도 되는 시점인지 판정.
    "! APJ 스케줄 옵션으로 표현할 수 없는 조건을 여기서 코드로 대신한다.
    METHODS check_run_condition
      IMPORTING
        is_def          TYPE ztjob_def
      RETURNING
        VALUE(rv_skip)  TYPE c.

ENDCLASS.


CLASS zcl_bc_job_runner IMPLEMENTATION.

  METHOD run.

    rs_summary-def_id = iv_def_id.

*----------------------------------------------------------------------*
* 1) 잡 정의 조회
*----------------------------------------------------------------------*
    SELECT SINGLE *
      FROM ztjob_def
      WHERE def_id    = @iv_def_id
        AND is_active = @abap_true
      INTO @DATA(ls_def).

    IF sy-subrc <> 0.
      rs_summary-skipped     = abap_true.
      rs_summary-skip_reason = zif_bc_job=>gc_skip-def_missing.
      RETURN.
    ENDIF.

*----------------------------------------------------------------------*
* 2) 실행 조건 판정
*    SM36 이 스케줄 옵션으로 처리하던 것을 런처가 코드로 대신한다.
*----------------------------------------------------------------------*
    DATA(lv_skip) = check_run_condition( ls_def ).

    IF lv_skip <> zif_bc_job=>gc_skip-none.
      rs_summary-skipped     = abap_true.
      rs_summary-skip_reason = lv_skip.
      RETURN.
    ENDIF.

*----------------------------------------------------------------------*
* 3) 스텝 조회
*----------------------------------------------------------------------*
    SELECT step_no, pg_type, pg_id, pg_variant, pg_lang, step_user
      FROM ztjob_step
      WHERE def_id = @iv_def_id
      ORDER BY step_no
      INTO TABLE @DATA(lt_step).

    IF lt_step IS INITIAL.
      rs_summary-skipped     = abap_true.
      rs_summary-skip_reason = zif_bc_job=>gc_skip-no_step.
      RETURN.
    ENDIF.

    rs_summary-requested = lines( lt_step ).

*----------------------------------------------------------------------*
* 4) 스텝 순차 실행
*    SM36 의 다중 스텝을 런처의 LOOP 로 대신한다.
*    차이: 스텝별 상태 구분이 안 되고 로그가 하나로 합쳐진다. (COMPARISON #1)
*----------------------------------------------------------------------*
    LOOP AT lt_step INTO DATA(ls_step).

      IF ls_step-pg_type <> zif_bc_job=>gc_pgtype-abap_program
         AND ls_step-pg_type IS NOT INITIAL.
        " 외부 커맨드/외부 프로그램은 APJ 로 실행할 수 없다. (COMPARISON #3)
        APPEND VALUE #( step_no    = ls_step-step_no
                        pg_id      = ls_step-pg_id
                        pg_variant = ls_step-pg_variant
                        success    = abap_false
                        message    = |pg_type '{ ls_step-pg_type }' not supported on APJ| )
               TO rs_summary-t_step.
        rs_summary-failed = rs_summary-failed + 1.
        CONTINUE.
      ENDIF.

      CALL FUNCTION 'Z_BC_RUN_REPORT'
        EXPORTING
          iv_program  = ls_step-pg_id
          iv_variant  = ls_step-pg_variant
          iv_language = ls_step-pg_lang
        IMPORTING
          ev_subrc    = DATA(lv_subrc)
          ev_message  = DATA(lv_message).

      DATA(lv_ok) = xsdbool( lv_subrc = 0 ).

      APPEND VALUE #( step_no    = ls_step-step_no
                      pg_id      = ls_step-pg_id
                      pg_variant = ls_step-pg_variant
                      success    = lv_ok
                      message    = lv_message )
             TO rs_summary-t_step.

      IF lv_ok = abap_true.
        rs_summary-executed = rs_summary-executed + 1.
      ELSE.
        rs_summary-failed = rs_summary-failed + 1.
        " SM36 은 스텝 실패 시 후속 스텝을 중단한다. 동일하게 맞춘다.
        " (계속 진행이 필요하면 ZTJOB_DEF 에 옵션 컬럼을 추가할 것)
        EXIT.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD check_run_condition.

    rv_skip = zif_bc_job=>gc_skip-none.

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_now)   = cl_abap_context_info=>get_system_time( ).

*----------------------------------------------------------------------*
* close 시각 (AS-IS laststrtdt / laststrttm)
* SM36 은 "No start after" 로 처리한다. APJ 에 대응 없음. (COMPARISON #19)
*----------------------------------------------------------------------*
    IF is_def-last_start_date IS NOT INITIAL.
      IF lv_today > is_def-last_start_date
         OR ( lv_today = is_def-last_start_date
              AND is_def-last_start_time IS NOT INITIAL
              AND lv_now > is_def-last_start_time ).
        rv_skip = zif_bc_job=>gc_skip-after_close.
        RETURN.
      ENDIF.
    ENDIF.

*----------------------------------------------------------------------*
* 팩토리 캘린더 작업일 (AS-IS 공장시간 / 공장근무일수 / 공장근무시간)
* SM36 은 주기 옵션으로 처리한다. APJ 에 대응 없음. (COMPARISON #12)
*----------------------------------------------------------------------*
    IF is_def-calendar_id IS NOT INITIAL.

      CALL FUNCTION 'Z_BC_CHECK_WORKDAY'
        EXPORTING
          iv_date         = lv_today
          iv_calendar_id  = is_def-calendar_id
          iv_workday_nr   = is_def-workday_nr
        IMPORTING
          ev_is_workday   = DATA(lv_is_workday).

      IF lv_is_workday = abap_false.
        rv_skip = zif_bc_job=>gc_skip-not_workday.
        RETURN.
      ENDIF.

      " 작업일 최소 시각 이전이면 아직 실행하지 않는다.
      IF is_def-workday_time IS NOT INITIAL
         AND lv_now < is_def-workday_time.
        rv_skip = zif_bc_job=>gc_skip-not_workday.
        RETURN.
      ENDIF.

    ENDIF.

  ENDMETHOD.

ENDCLASS.
