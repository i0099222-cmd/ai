"! <p class="shorttext synchronized">ZI_BATCH_SCHEDULE Behavior Implementation</p>
"!
"! AS-IS 인터페이스와 표준 CRUD 가 1:1 이다.
"!   ZBC_BATCH_JOB_CREATE -> create -> SCHEDULE_JOB
"!   ZBC_BATCH_JOB_CHANGE -> update -> CANCEL_JOB + SCHEDULE_JOB
"!   ZBC_BATCH_JOB_DELETE -> delete -> CANCEL_JOB
"!   ZBC_BATCH_JOB_STATUS -> action refreshStatus
"!
"! CL_APJ_RT_API 는 RAP 인터랙션 단계에서 호출할 수 없다(LUW 충돌).
"! save_modified 에서만 호출하며, 필요한 값은 create/update 가 그대로 갖고 있다.
"!
"! 대가: save 단계에서는 reported 로 메시지를 돌려줄 수 없다.
"!       APJ 응답은 ZTBATCH_SCHED-MESSAGE 에 남고, 실패하면 JOBNAME 이 빈 채로
"!       남는다 (IsScheduled = '').
CLASS zbp_i_batch_schedule DEFINITION
  PUBLIC
  ABSTRACT
  FINAL
  FOR BEHAVIOR OF zi_batch_schedule.
ENDCLASS.

CLASS zbp_i_batch_schedule IMPLEMENTATION.
ENDCLASS.


*&---------------------------------------------------------------------*
*& 인터랙션 단계
*&---------------------------------------------------------------------*
CLASS lhc_schedule DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR batchschedule RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR batchschedule RESULT result.

    METHODS refreshstatus FOR MODIFY
      IMPORTING keys FOR ACTION batchschedule~refreshstatus RESULT result.

ENDCLASS.


CLASS lhc_schedule IMPLEMENTATION.

  METHOD get_global_authorizations.
    " 테스트 단계 - 전부 허용. 운영에서는 업무 권한객체로 제한할 것.
  ENDMETHOD.


  METHOD get_instance_features.

    READ ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        FIELDS ( jobname )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_run)
      FAILED failed.

    " 잡이 걸려 있을 때만 상태 조회가 의미 있다.
    result = VALUE #( FOR ls_run IN lt_run
      ( %tky = ls_run-%tky
        %action-refreshstatus = COND #( WHEN ls_run-jobname IS NOT INITIAL
                                        THEN if_abap_behv=>fc-o-enabled
                                        ELSE if_abap_behv=>fc-o-disabled ) ) ).

  ENDMETHOD.


  METHOD refreshstatus.

    READ ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        FIELDS ( jobname jobcount )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_run)
      FAILED failed.

    DATA(lo_adapter) = NEW zcl_batch_apj_adapter( ).

    LOOP AT lt_run INTO DATA(ls_run).

      CHECK ls_run-jobname IS NOT INITIAL.

      DATA(ls_status) = lo_adapter->get_status( iv_job_name  = ls_run-jobname
                                                iv_job_count = ls_run-jobcount ).

      APPEND VALUE #( %tky = ls_run-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-information
                               text     = |{ ls_run-jobname }/{ ls_run-jobcount }: | &&
                                          |{ ls_status-message }| ) )
             TO reported-batchschedule.

    ENDLOOP.

    READ ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_res IN lt_result
                      ( %tky = ls_res-%tky %param = ls_res ) ).

  ENDMETHOD.

ENDCLASS.


*&---------------------------------------------------------------------*
*& Saver - 여기서만 APJ 를 호출한다
*&---------------------------------------------------------------------*
CLASS lsc_zi_batch_schedule DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.

  PRIVATE SECTION.

    "! 걸려 있던 잡을 취소한다. 없으면 아무것도 하지 않는다.
    METHODS cancel_current
      IMPORTING iv_run_uuid       TYPE ztbatch_sched-run_uuid
      RETURNING VALUE(rv_message) TYPE string.

ENDCLASS.


CLASS lsc_zi_batch_schedule IMPLEMENTATION.

  METHOD save_modified.

    DATA(lo_adapter) = NEW zcl_batch_apj_adapter( ).

*----------------------------------------------------------------------*
* 삭제 - 걸려 있던 잡을 취소한다
*----------------------------------------------------------------------*
    LOOP AT delete INTO DATA(ls_del).
      cancel_current( ls_del-runuuid ).
    ENDLOOP.

*----------------------------------------------------------------------*
* 생성 / 변경 - 스케줄한다
*   변경이면 기존 잡을 먼저 취소한다. APJ 에 잡 수정 API 가 없어
*   취소 + 재생성이며, 그 결과 SM37 의 jobname/jobcount 가 바뀐다.
*----------------------------------------------------------------------*
    DATA lt_target TYPE TABLE FOR CREATE zi_batch_schedule.

    lt_target = create.

    LOOP AT update INTO DATA(ls_upd).
      cancel_current( ls_upd-runuuid ).
      APPEND CORRESPONDING #( ls_upd ) TO lt_target.
    ENDLOOP.

    LOOP AT lt_target INTO DATA(ls_row).

      DATA(ls_sched) = lo_adapter->schedule(
        iv_template = ls_row-jobtemplatename
        iv_jobtext  = ls_row-jobtext
        iv_param    = ls_row-parameters
        is_start    = VALUE #( start_immediately = ls_row-startimmediately
                               start_date        = ls_row-startdate
                               start_time        = ls_row-starttime
                               timezone          = ls_row-timezone
                               prd_mins          = ls_row-periodminutes
                               prd_hours         = ls_row-periodhours
                               prd_days          = ls_row-perioddays
                               prd_weeks         = ls_row-periodweeks
                               prd_months        = ls_row-periodmonths ) ).

      " 실패하면 jobname 이 빈 채로 남는다. 사유는 message 에 적힌다.
      " save 단계라 reported 로 메시지를 돌려줄 수 없기 때문이다.
      UPDATE ztbatch_sched
        SET jobname  = @ls_sched-job_name,
            jobcount = @ls_sched-job_count,
            message  = @( CONV ztbatch_sched-message( ls_sched-message ) )
        WHERE run_uuid = @ls_row-runuuid.

    ENDLOOP.

  ENDMETHOD.


  METHOD cancel_current.

    SELECT SINGLE jobname, jobcount
      FROM ztbatch_sched
      WHERE run_uuid = @iv_run_uuid
      INTO @DATA(ls_old).

    CHECK sy-subrc = 0 AND ls_old-jobname IS NOT INITIAL.

    rv_message = NEW zcl_batch_apj_adapter( )->cancel(
                   iv_job_name  = ls_old-jobname
                   iv_job_count = ls_old-jobcount ).

  ENDMETHOD.

ENDCLASS.
