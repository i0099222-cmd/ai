"! <p class="shorttext synchronized">스케줄 1건 실행 (런처 코어)</p>
"!
"! ZTBATCH_SCHED 한 건을 읽어서
"!   1) PARAM(JSON)의 cond 로 실행 조건 판정 (close 시각 / 팩토리 캘린더)
"!   2) EXEC_CLASS 를 동적 생성해서 ZIF_BATCH_STEP~EXECUTE 호출
"! 결과는 호출자(런처)에 돌려주기만 하고 DB 에 쓰지 않는다.
"! 실행 이력은 별도 로그 기능이 담당하고, 여기서는 잡 로그(MESSAGE)만 남는다.
"!
"! 언어버전: ABAP for Cloud Development. Standard ABAP 의존이 하나도 없다.
CLASS zcl_batch_runner DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS run
      IMPORTING
        iv_run_uuid      TYPE sysuuid_x16
      RETURNING
        VALUE(rs_result) TYPE zif_batch_job=>ty_run_result.

  PRIVATE SECTION.

    "! APJ 스케줄 옵션으로 표현할 수 없는 조건을 코드로 판정한다.
    METHODS check_condition
      IMPORTING
        is_cond        TYPE zif_batch_job=>ty_condition
      RETURNING
        VALUE(rv_skip) TYPE c.

ENDCLASS.


CLASS zcl_batch_runner IMPLEMENTATION.

  METHOD run.

    rs_result-run_uuid = iv_run_uuid.

*----------------------------------------------------------------------*
* 1) 스케줄 행 조회
*----------------------------------------------------------------------*
    SELECT SINGLE exec_class, param
      FROM ztbatch_sched
      WHERE run_uuid = @iv_run_uuid
      INTO @DATA(ls_run).

    IF sy-subrc <> 0.
      rs_result-skipped     = abap_true.
      rs_result-skip_reason = zif_batch_job=>gc_skip-run_missing.
      RETURN.
    ENDIF.

    rs_result-exec_class = ls_run-exec_class.

    IF ls_run-exec_class IS INITIAL.
      rs_result-skipped     = abap_true.
      rs_result-skip_reason = zif_batch_job=>gc_skip-no_class.
      RETURN.
    ENDIF.

*----------------------------------------------------------------------*
* 2) 실행 조건 판정
*----------------------------------------------------------------------*
    DATA(ls_param) = zcl_batch_param=>deserialize( ls_run-param ).

    DATA(lv_skip) = check_condition( ls_param-cond ).

    IF lv_skip <> zif_batch_job=>gc_skip-none.
      rs_result-skipped     = abap_true.
      rs_result-skip_reason = lv_skip.
      RETURN.
    ENDIF.

*----------------------------------------------------------------------*
* 3) 실행 클래스를 동적 생성해서 호출
*    이 한 줄이 SUBMIT 을 대신한다. Standard ABAP 이 필요 없는 이유다.
*----------------------------------------------------------------------*
    DATA lo_step TYPE REF TO zif_batch_step.

    TRY.
        " TODO: 확인 - CREATE OBJECT ... TYPE (name) 의 동적 생성이
        "       ABAP Cloud 언어버전에서 통과하는지. 막히면 런처에 CASE 분기를
        "       두는 레지스트리 방식으로 대체한다.
        CREATE OBJECT lo_step TYPE (ls_run-exec_class).

      CATCH cx_sy_create_object_error INTO DATA(lx_create).
        rs_result-skipped     = abap_true.
        rs_result-skip_reason = zif_batch_job=>gc_skip-bad_class.
        rs_result-message     = |{ ls_run-exec_class }: { lx_create->get_text( ) }|.
        RETURN.
    ENDTRY.

    TRY.
        rs_result-message = lo_step->execute( ls_param-app ).
        rs_result-success = abap_true.

      CATCH zcx_batch_job INTO DATA(lx_job).
        rs_result-success = abap_false.
        rs_result-message = lx_job->message.

      CATCH cx_root INTO DATA(lx_any).
        rs_result-success = abap_false.
        rs_result-message = |{ ls_run-exec_class }: { lx_any->get_text( ) }|.
    ENDTRY.

  ENDMETHOD.


  METHOD check_condition.

    rv_skip = zif_batch_job=>gc_skip-none.

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).
    DATA(lv_now)   = cl_abap_context_info=>get_system_time( ).

    " --- close 시각 (AS-IS 배치잡 close시간). APJ 스케줄 옵션에 대응 없음.
    IF is_cond-last_start_date IS NOT INITIAL.
      IF lv_today > is_cond-last_start_date
         OR ( lv_today = is_cond-last_start_date
              AND is_cond-last_start_time IS NOT INITIAL
              AND lv_now > is_cond-last_start_time ).
        rv_skip = zif_batch_job=>gc_skip-after_close.
        RETURN.
      ENDIF.
    ENDIF.

*----------------------------------------------------------------------*
* --- 팩토리 캘린더 (AS-IS 공장시간/공장근무일수/공장근무시간)
*
* TODO: 미구현. 판정에 쓸 수 있는 released API 를 시스템에서 확인해야 한다.
*   후보 1) 팩토리 캘린더 released CDS 뷰 (있으면 SELECT 로 판정)
*   후보 2) 없으면 Standard ABAP FM(DATE_CONVERT_TO_FACTORYDATE) 을
*           Local API 로 release 해서 호출 -> 순수 Cloud 구성이 깨진다
*   후보 3) 이 요구사항 자체를 드롭
*
* 현재는 캘린더 지정이 있어도 판정하지 않고 항상 실행한다.
*----------------------------------------------------------------------*
    IF is_cond-calendar_id IS NOT INITIAL.
      " 작업일 최소 시각만이라도 지킨다 (캘린더 조회 없이 가능한 부분)
      IF is_cond-workday_time IS NOT INITIAL
         AND lv_now < is_cond-workday_time.
        rv_skip = zif_batch_job=>gc_skip-not_workday.
        RETURN.
      ENDIF.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
