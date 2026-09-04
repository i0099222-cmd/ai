"! <p class="shorttext synchronized">스케줄 1건 실행 (런처 코어)</p>
"!
"! ZTJOB_RUN 한 건을 읽어서
"!   1) PARAM(JSON)을 풀어 실행 조건 판정 (close 시각 / 팩토리 캘린더)
"!   2) PGMID 실행
"!   3) 결과를 ZTJOB_RUN 에 기록
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
        iv_run_uuid      TYPE sysuuid_x16
      RETURNING
        VALUE(rs_result) TYPE zif_bc_job=>ty_run_result.

  PRIVATE SECTION.

    "! APJ 스케줄 옵션으로 표현할 수 없는 조건을 코드로 판정한다.
    METHODS check_run_condition
      IMPORTING
        is_param       TYPE zif_bc_job=>ty_param
      RETURNING
        VALUE(rv_skip) TYPE c.

    METHODS save_result
      IMPORTING
        is_result TYPE zif_bc_job=>ty_run_result.

ENDCLASS.


CLASS zcl_bc_job_runner IMPLEMENTATION.

  METHOD run.

    rs_result-run_uuid = iv_run_uuid.

*----------------------------------------------------------------------*
* 1) 스케줄 행 조회
*----------------------------------------------------------------------*
    SELECT SINGLE pgmid, param
      FROM ztjob_run
      WHERE run_uuid = @iv_run_uuid
      INTO @DATA(ls_run).

    IF sy-subrc <> 0.
      rs_result-skipped     = abap_true.
      rs_result-skip_reason = zif_bc_job=>gc_skip-run_missing.
      RETURN.   " 행이 없으니 기록할 곳도 없다
    ENDIF.

    rs_result-pgmid = ls_run-pgmid.

    IF ls_run-pgmid IS INITIAL.
      rs_result-skipped     = abap_true.
      rs_result-skip_reason = zif_bc_job=>gc_skip-no_program.
      save_result( rs_result ).
      RETURN.
    ENDIF.

*----------------------------------------------------------------------*
* 2) PARAM 을 풀어 실행 조건 판정
*    AS-IS 가 SM36 스케줄 옵션으로 처리하던 것을 런처가 대신한다.
*----------------------------------------------------------------------*
    DATA(ls_param) = zcl_bc_job_param=>deserialize( ls_run-param ).

    DATA(lv_skip) = check_run_condition( ls_param ).

    IF lv_skip <> zif_bc_job=>gc_skip-none.
      rs_result-skipped     = abap_true.
      rs_result-skip_reason = lv_skip.
      save_result( rs_result ).
      RETURN.
    ENDIF.

*----------------------------------------------------------------------*
* 3) 실행
*----------------------------------------------------------------------*
    CALL FUNCTION 'Z_BC_RUN_REPORT'
      EXPORTING
        iv_program = ls_run-pgmid
        iv_variant = ls_param-variant
      IMPORTING
        ev_subrc   = DATA(lv_subrc)
        ev_message = DATA(lv_message).

    rs_result-success = xsdbool( lv_subrc = 0 ).
    rs_result-message = lv_message.

    save_result( rs_result ).

  ENDMETHOD.


  METHOD check_run_condition.

    rv_skip = zif_bc_job=>gc_skip-none.

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_now)   = cl_abap_context_info=>get_system_time( ).

    " --- close 시각 (AS-IS 배치잡 close시간). APJ 에 대응 없음 (COMPARISON #19)
    IF is_param-last_start_date IS NOT INITIAL.
      IF lv_today > is_param-last_start_date
         OR ( lv_today = is_param-last_start_date
              AND is_param-last_start_time IS NOT INITIAL
              AND lv_now > is_param-last_start_time ).
        rv_skip = zif_bc_job=>gc_skip-after_close.
        RETURN.
      ENDIF.
    ENDIF.

    " --- 팩토리 캘린더 (AS-IS 공장시간/공장근무일수/공장근무시간). COMPARISON #12
    IF is_param-calendar_id IS NOT INITIAL.

      CALL FUNCTION 'Z_BC_CHECK_WORKDAY'
        EXPORTING
          iv_date        = lv_today
          iv_calendar_id = is_param-calendar_id
          iv_workday_nr  = is_param-workday_nr
        IMPORTING
          ev_is_workday  = DATA(lv_is_workday).

      IF lv_is_workday = abap_false.
        rv_skip = zif_bc_job=>gc_skip-not_workday.
        RETURN.
      ENDIF.

      IF is_param-workday_time IS NOT INITIAL
         AND lv_now < is_param-workday_time.
        rv_skip = zif_bc_job=>gc_skip-not_workday.
        RETURN.
      ENDIF.

    ENDIF.

  ENDMETHOD.


  METHOD save_result.

    DATA(lv_status) = COND #(
      WHEN is_result-skipped = abap_true THEN zif_bc_job=>gc_status-skipped
      WHEN is_result-success = abap_true THEN zif_bc_job=>gc_status-finished
      ELSE                                    zif_bc_job=>gc_status-error ).

    DATA(lv_message) = COND #(
      WHEN is_result-skipped = abap_true
        THEN |Skipped: { SWITCH string( is_result-skip_reason
               WHEN zif_bc_job=>gc_skip-after_close THEN 'past close time'
               WHEN zif_bc_job=>gc_skip-not_workday THEN 'not a factory working day'
               WHEN zif_bc_job=>gc_skip-no_program  THEN 'no program specified'
               ELSE 'unknown' ) }|
      ELSE is_result-message ).

    UPDATE ztjob_run
      SET status  = @lv_status,
          message = @( CONV ztjob_run-message( lv_message ) )
      WHERE run_uuid = @is_result-run_uuid.

    COMMIT WORK.

  ENDMETHOD.

ENDCLASS.
