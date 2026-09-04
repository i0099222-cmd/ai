"! <p class="shorttext synchronized">스케줄 1건 실행 (런처 코어)</p>
"!
"! ZTJOB_RUN + ZTJOB_STEP 을 읽어서
"!   1) 실행 조건 판정 (close 시각 / 팩토리 캘린더 작업일)
"!   2) 스텝을 순번대로 실행
"!   3) 결과를 ZTJOB_STEP / ZTJOB_RUN 에 기록
"! 을 수행한다.
"!
"! 언어버전: ABAP for Cloud Development.
"! SUBMIT 과 팩토리 캘린더 조회는 Standard ABAP FM(Local API released)에 위임한다.
"!
"! APJ 실행 클래스와 분리한 이유: APJ 없이도 단위 테스트할 수 있어야 해서.
CLASS zcl_bc_job_runner DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS run
      IMPORTING
        iv_run_uuid       TYPE sysuuid_x16
      RETURNING
        VALUE(rs_summary) TYPE zif_bc_job=>ty_run_summary.

  PRIVATE SECTION.

    "! APJ 스케줄 옵션으로 표현할 수 없는 조건을 코드로 판정한다.
    METHODS check_run_condition
      IMPORTING
        is_run         TYPE ztjob_run
      RETURNING
        VALUE(rv_skip) TYPE c.

    METHODS save_result
      IMPORTING
        is_summary TYPE zif_bc_job=>ty_run_summary.

ENDCLASS.


CLASS zcl_bc_job_runner IMPLEMENTATION.

  METHOD run.

    rs_summary-run_uuid = iv_run_uuid.

*----------------------------------------------------------------------*
* 1) 스케줄 행 조회
*----------------------------------------------------------------------*
    SELECT SINGLE * FROM ztjob_run
      WHERE run_uuid = @iv_run_uuid
      INTO @DATA(ls_run).

    IF sy-subrc <> 0.
      rs_summary-skipped     = abap_true.
      rs_summary-skip_reason = zif_bc_job=>gc_skip-run_missing.
      RETURN.
    ENDIF.

*----------------------------------------------------------------------*
* 2) 실행 조건 판정
*    AS-IS 가 SM36 스케줄 옵션으로 처리하던 것을 런처가 대신한다.
*----------------------------------------------------------------------*
    DATA(lv_skip) = check_run_condition( ls_run ).

    IF lv_skip <> zif_bc_job=>gc_skip-none.
      rs_summary-skipped     = abap_true.
      rs_summary-skip_reason = lv_skip.
      save_result( rs_summary ).
      RETURN.
    ENDIF.

*----------------------------------------------------------------------*
* 3) 스텝 조회 - AS-IS lt_pg 에 해당
*----------------------------------------------------------------------*
    SELECT step_uuid, step_no, pg_type, pg_id, pg_variant, pg_lang, step_user
      FROM ztjob_step
      WHERE run_uuid = @iv_run_uuid
      ORDER BY step_no
      INTO TABLE @DATA(lt_step).

    IF lt_step IS INITIAL.
      rs_summary-skipped     = abap_true.
      rs_summary-skip_reason = zif_bc_job=>gc_skip-no_step.
      save_result( rs_summary ).
      RETURN.
    ENDIF.

    rs_summary-requested = lines( lt_step ).

*----------------------------------------------------------------------*
* 4) 스텝 순차 실행
*    SM36 의 다중 스텝을 LOOP 로 대신한다.
*    차이: SM37 에서 스텝별 상태를 따로 볼 수 없다. (COMPARISON #1)
*          그래서 결과를 ZTJOB_STEP 에 직접 기록해 조회 가능하게 한다.
*----------------------------------------------------------------------*
    LOOP AT lt_step INTO DATA(ls_step).

      IF ls_step-pg_type IS NOT INITIAL
         AND ls_step-pg_type <> zif_bc_job=>gc_pgtype-abap_program.
        " 외부 커맨드/외부 프로그램은 APJ 로 실행할 수 없다. (COMPARISON #3)
        APPEND VALUE #( step_uuid = ls_step-step_uuid
                        step_no   = ls_step-step_no
                        pg_id     = ls_step-pg_id
                        success   = abap_false
                        message   = |pg_type '{ ls_step-pg_type }' not supported on APJ| )
               TO rs_summary-t_step.
        rs_summary-failed = rs_summary-failed + 1.
        EXIT.
      ENDIF.

      CALL FUNCTION 'Z_BC_RUN_REPORT'
        EXPORTING
          iv_program = ls_step-pg_id
          iv_variant = ls_step-pg_variant
        IMPORTING
          ev_subrc   = DATA(lv_subrc)
          ev_message = DATA(lv_message).

      DATA(lv_ok) = xsdbool( lv_subrc = 0 ).

      APPEND VALUE #( step_uuid = ls_step-step_uuid
                      step_no   = ls_step-step_no
                      pg_id     = ls_step-pg_id
                      success   = lv_ok
                      message   = lv_message )
             TO rs_summary-t_step.

      IF lv_ok = abap_true.
        rs_summary-executed = rs_summary-executed + 1.
      ELSE.
        rs_summary-failed = rs_summary-failed + 1.
        " SM36 은 스텝 실패 시 후속 스텝을 중단한다. 동일하게 맞춘다.
        EXIT.
      ENDIF.

    ENDLOOP.

    save_result( rs_summary ).

  ENDMETHOD.


  METHOD check_run_condition.

    rv_skip = zif_bc_job=>gc_skip-none.

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_now)   = cl_abap_context_info=>get_system_time( ).

    " --- close 시각 (AS-IS 배치잡 close시간). APJ 에 대응 없음 (COMPARISON #19)
    IF is_run-last_start_date IS NOT INITIAL.
      IF lv_today > is_run-last_start_date
         OR ( lv_today = is_run-last_start_date
              AND is_run-last_start_time IS NOT INITIAL
              AND lv_now > is_run-last_start_time ).
        rv_skip = zif_bc_job=>gc_skip-after_close.
        RETURN.
      ENDIF.
    ENDIF.

    " --- 팩토리 캘린더 (AS-IS 공장시간/공장근무일수/공장근무시간). COMPARISON #12
    IF is_run-calendar_id IS NOT INITIAL.

      CALL FUNCTION 'Z_BC_CHECK_WORKDAY'
        EXPORTING
          iv_date        = lv_today
          iv_calendar_id = is_run-calendar_id
          iv_workday_nr  = is_run-workday_nr
        IMPORTING
          ev_is_workday  = DATA(lv_is_workday).

      IF lv_is_workday = abap_false.
        rv_skip = zif_bc_job=>gc_skip-not_workday.
        RETURN.
      ENDIF.

      IF is_run-workday_time IS NOT INITIAL
         AND lv_now < is_run-workday_time.
        rv_skip = zif_bc_job=>gc_skip-not_workday.
        RETURN.
      ENDIF.

    ENDIF.

  ENDMETHOD.


  METHOD save_result.

    DATA(lv_status) = COND #(
      WHEN is_summary-skipped = abap_true THEN zif_bc_job=>gc_status-skipped
      WHEN is_summary-failed  > 0         THEN zif_bc_job=>gc_status-error
      ELSE                                     zif_bc_job=>gc_status-finished ).

    DATA(lv_message) = COND #(
      WHEN is_summary-skipped = abap_true
        THEN |Skipped: { SWITCH string( is_summary-skip_reason
               WHEN zif_bc_job=>gc_skip-after_close THEN 'past close time'
               WHEN zif_bc_job=>gc_skip-not_workday THEN 'not a factory working day'
               WHEN zif_bc_job=>gc_skip-no_step     THEN 'no step defined'
               WHEN zif_bc_job=>gc_skip-run_missing THEN 'schedule row not found'
               ELSE 'unknown' ) }|
      ELSE |executed={ is_summary-executed } failed={ is_summary-failed } | &&
           |/ requested={ is_summary-requested }| ).

    " 스텝별 결과
    LOOP AT is_summary-t_step INTO DATA(ls_step).
      UPDATE ztjob_step
        SET exec_success = @ls_step-success,
            exec_message = @( CONV ztjob_step-exec_message( ls_step-message ) )
        WHERE run_uuid  = @is_summary-run_uuid
          AND step_uuid = @ls_step-step_uuid.
    ENDLOOP.

    " 헤더 상태
    DATA lv_now_ts TYPE timestampl.
    GET TIME STAMP FIELD lv_now_ts.

    UPDATE ztjob_run
      SET job_status      = @lv_status,
          last_checked_at = @lv_now_ts,
          last_message    = @( CONV ztjob_run-last_message( lv_message ) )
      WHERE run_uuid = @is_summary-run_uuid.

    COMMIT WORK.

  ENDMETHOD.

ENDCLASS.
