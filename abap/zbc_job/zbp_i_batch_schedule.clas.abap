"! <p class="shorttext synchronized">ZI_BATCH_SCHEDULE Behavior Implementation</p>
"!
"! 이 BO 의 엔티티는 "스케줄 이력" 이다. 조회가 목적이고,
"! APJ 잡에 대한 조작은 CRUD 가 아니라 명령이므로 액션으로 노출한다.
"!
"!   ZBC_BATCH_JOB_CREATE -> scheduleJob
"!   ZBC_BATCH_JOB_CHANGE -> changeJob
"!   ZBC_BATCH_JOB_DELETE -> cancelJob      (잡만 끊고 이력은 남긴다)
"!   ZBC_BATCH_JOB_STATUS -> refreshStatus
"!
"! ** LUW 분리 **
"!   CL_APJ_RT_API 는 RAP 인터랙션 단계에서 호출할 수 없다.
"!   그래서 액션은 엔티티에 쓰기만 하고, 그 결과가 create/update 테이블에
"!   실려 saver 로 넘어간다. 별도 버퍼가 필요 없는 이유다.
"!
"!     scheduleJob ──▶ MODIFY CREATE ──▶ [create] ──▶ save_modified ──▶ SCHEDULE_JOB
"!     changeJob   ──▶ MODIFY UPDATE ──▶ [update] ──▶ save_modified ──▶ CANCEL + SCHEDULE
"!     cancelJob   ──▶ MODIFY UPDATE ──▶ [update] ──▶ save_modified ──▶ CANCEL_JOB
"!       (CancelRequested = 'X' 로 구분한다)
"!
"!   대가: save 단계에서는 reported 로 메시지를 돌려줄 수 없다.
"!         APJ 응답은 ZTBATCH_SCHED-MESSAGE 에 남고, 실패하면 JOBNAME 이
"!         빈 채로 남는다 (IsScheduled = '').
CLASS zbp_i_batch_schedule DEFINITION
  PUBLIC
  ABSTRACT
  FINAL
  FOR BEHAVIOR OF zi_batch_schedule.
ENDCLASS.

CLASS zbp_i_batch_schedule IMPLEMENTATION.
ENDCLASS.


*&---------------------------------------------------------------------*
*& 인터랙션 단계 - 엔티티에 쓰기만 한다
*&---------------------------------------------------------------------*
CLASS lhc_schedule DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR batchschedule RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR batchschedule RESULT result.

    METHODS schedulejob FOR MODIFY
      IMPORTING keys FOR ACTION batchschedule~schedulejob.

    METHODS changejob FOR MODIFY
      IMPORTING keys FOR ACTION batchschedule~changejob RESULT result.

    METHODS canceljob FOR MODIFY
      IMPORTING keys FOR ACTION batchschedule~canceljob RESULT result.

    METHODS refreshstatus FOR MODIFY
      IMPORTING keys FOR ACTION batchschedule~refreshstatus RESULT result.

    METHODS read_self
      IMPORTING keys          TYPE ANY TABLE
      RETURNING VALUE(result) TYPE TABLE FOR ACTION RESULT zi_batch_schedule~changejob.

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

    " 잡이 걸려 있을 때만 변경/취소/조회가 의미 있다.
    result = VALUE #( FOR ls_run IN lt_run
      ( %tky = ls_run-%tky
        %action-changejob     = COND #( WHEN ls_run-jobname IS NOT INITIAL
                                        THEN if_abap_behv=>fc-o-enabled
                                        ELSE if_abap_behv=>fc-o-disabled )
        %action-canceljob     = COND #( WHEN ls_run-jobname IS NOT INITIAL
                                        THEN if_abap_behv=>fc-o-enabled
                                        ELSE if_abap_behv=>fc-o-disabled )
        %action-refreshstatus = COND #( WHEN ls_run-jobname IS NOT INITIAL
                                        THEN if_abap_behv=>fc-o-enabled
                                        ELSE if_abap_behv=>fc-o-disabled ) ) ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 잡 생성 - AS-IS ZBC_BATCH_JOB_CREATE
*   이력 행만 만든다. 실제 SCHEDULE_JOB 은 saver 가 create 를 보고 호출한다.
*----------------------------------------------------------------------*
  METHOD schedulejob.

    DATA lt_create TYPE TABLE FOR CREATE zi_batch_schedule.

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_p) = ls_key-%param.

      APPEND VALUE #( %cid              = ls_key-%cid
                      jobtemplatename   = ls_p-jobtemplatename
                      jobtext           = ls_p-jobtext
                      parameters        = ls_p-parameters
                      startimmediately  = ls_p-startimmediately
                      startdatetime     = ls_p-startdatetime
                      timezone          = ls_p-timezone
                      periodminutes     = ls_p-periodminutes
                      periodhours       = ls_p-periodhours
                      perioddays        = ls_p-perioddays
                      periodweeks       = ls_p-periodweeks
                      periodmonths      = ls_p-periodmonths
                      enddatetime       = ls_p-enddatetime
                      calendarid        = ls_p-calendarid
                      monthday          = ls_p-monthday
                      endofmonth        = ls_p-endofmonth
                      useworkingdays    = ls_p-useworkingdays
                      startrestriction  = ls_p-startrestriction )
             TO lt_create.
    ENDLOOP.

    CHECK lt_create IS NOT INITIAL.

    MODIFY ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        CREATE FIELDS ( jobtemplatename jobtext parameters
                        startimmediately startdatetime timezone
                        periodminutes periodhours perioddays periodweeks periodmonths
                        enddatetime
                        calendarid monthday endofmonth useworkingdays startrestriction )
        WITH lt_create
      MAPPED   DATA(ls_mapped)
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    mapped-batchschedule   = CORRESPONDING #( ls_mapped-batchschedule ).
    failed-batchschedule   = VALUE #( BASE failed-batchschedule
                                      ( LINES OF CORRESPONDING #( ls_failed-batchschedule ) ) ).
    reported-batchschedule = VALUE #( BASE reported-batchschedule
                                      ( LINES OF CORRESPONDING #( ls_reported-batchschedule ) ) ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 스케줄 변경 - AS-IS ZBC_BATCH_JOB_CHANGE
*   새 시작 조건만 쓴다. saver 가 update 를 보고 취소 + 재스케줄한다.
*----------------------------------------------------------------------*
  METHOD changejob.

    DATA lt_update TYPE TABLE FOR UPDATE zi_batch_schedule.

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_p) = ls_key-%param.

      APPEND VALUE #( %tky             = ls_key-%tky
                      startimmediately = ls_p-startimmediately
                      startdatetime    = ls_p-startdatetime
                      timezone         = ls_p-timezone
                      periodminutes    = ls_p-periodminutes
                      periodhours      = ls_p-periodhours
                      perioddays       = ls_p-perioddays
                      periodweeks      = ls_p-periodweeks
                      periodmonths     = ls_p-periodmonths
                      enddatetime      = ls_p-enddatetime
                      calendarid       = ls_p-calendarid
                      monthday         = ls_p-monthday
                      endofmonth       = ls_p-endofmonth
                      useworkingdays   = ls_p-useworkingdays
                      startrestriction = ls_p-startrestriction )
             TO lt_update.
    ENDLOOP.

    MODIFY ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        UPDATE FIELDS ( startimmediately startdatetime timezone
                        periodminutes periodhours perioddays periodweeks periodmonths
                        enddatetime
                        calendarid monthday endofmonth useworkingdays startrestriction )
        WITH lt_update
      FAILED   failed
      REPORTED reported.

    result = read_self( keys ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 잡 취소 - AS-IS ZBC_BATCH_JOB_DELETE
*   이력 행은 남기고 잡만 끊는다.
*   CancelRequested 를 세워 saver 가 취소임을 알게 한다.
*----------------------------------------------------------------------*
  METHOD canceljob.

    MODIFY ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        UPDATE FIELDS ( cancelrequested )
        WITH VALUE #( FOR ls_key IN keys
                      ( %tky = ls_key-%tky cancelrequested = abap_true ) )
      FAILED   failed
      REPORTED reported.

    result = read_self( keys ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 상태 조회 - AS-IS ZBC_BATCH_JOB_STATUS
*   GET_JOB_STATUS 는 읽기만 하므로 인터랙션 단계에서 호출해도 된다.
*   덕분에 reported 로 상태를 바로 돌려줄 수 있다.
*----------------------------------------------------------------------*
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

    result = read_self( keys ).

  ENDMETHOD.


  METHOD read_self.

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

    "! 스케줄하고 결과를 이력 행에 기록한다.
    METHODS schedule_and_store
      IMPORTING is_row TYPE STRUCTURE FOR CREATE zi_batch_schedule.

ENDCLASS.


CLASS lsc_zi_batch_schedule IMPLEMENTATION.

  METHOD save_modified.

*----------------------------------------------------------------------*
* 삭제 - 걸려 있던 잡을 취소한다
*   (projection 에서 delete 를 노출하지 않으므로 보통은 비어 있다)
*----------------------------------------------------------------------*
    LOOP AT delete INTO DATA(ls_del).
      cancel_current( ls_del-runuuid ).
    ENDLOOP.

*----------------------------------------------------------------------*
* 생성 - scheduleJob
*----------------------------------------------------------------------*
    LOOP AT create INTO DATA(ls_new).
      schedule_and_store( ls_new ).
    ENDLOOP.

*----------------------------------------------------------------------*
* 변경 - cancelJob 이면 취소만, changeJob 이면 취소 + 재스케줄
*   APJ 에 잡 수정 API 가 없어 재스케줄은 취소 + 재생성이며,
*   그 결과 SM37 의 jobname/jobcount 가 바뀐다.
*----------------------------------------------------------------------*
    LOOP AT update INTO DATA(ls_upd).

      DATA(lv_cancel_msg) = cancel_current( ls_upd-runuuid ).

      IF ls_upd-cancelrequested = abap_true.

        " 취소만. 포인터를 비우고 요청 플래그도 내린다.
        DATA lv_empty_name  TYPE ztbatch_sched-jobname.
        DATA lv_empty_count TYPE ztbatch_sched-jobcount.

        UPDATE ztbatch_sched
          SET jobname          = @lv_empty_name,
              jobcount         = @lv_empty_count,
              cancel_requested = @abap_false,
              message          = @( CONV ztbatch_sched-message( lv_cancel_msg ) )
          WHERE run_uuid = @ls_upd-runuuid.

        CONTINUE.
      ENDIF.

      " 재스케줄. 변경된 시작 조건은 ls_upd 에 실려 있다.
      schedule_and_store( CORRESPONDING #( ls_upd ) ).

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


  METHOD schedule_and_store.

    DATA(ls_sched) = NEW zcl_batch_apj_adapter( )->schedule(
      iv_template = is_row-jobtemplatename
      iv_jobtext  = is_row-jobtext
      iv_param    = is_row-parameters
      is_start    = VALUE #( start_immediately = is_row-startimmediately
                             start_datetime    = is_row-startdatetime
                             timezone          = is_row-timezone
                             prd_mins          = is_row-periodminutes
                             prd_hours         = is_row-periodhours
                             prd_days          = is_row-perioddays
                             prd_weeks         = is_row-periodweeks
                             prd_months        = is_row-periodmonths
                             end_datetime      = is_row-enddatetime
                             calendar_id       = is_row-calendarid
                             month_day         = is_row-monthday
                             eof_month         = is_row-endofmonth
                             use_working_days  = is_row-useworkingdays
                             start_restriction = is_row-startrestriction ) ).

    " 실패하면 jobname 이 빈 채로 남는다. 사유는 message 에 적힌다.
    " save 단계라 reported 로 메시지를 돌려줄 수 없기 때문이다.
    UPDATE ztbatch_sched
      SET jobname  = @ls_sched-job_name,
          jobcount = @ls_sched-job_count,
          message  = @( CONV ztbatch_sched-message( ls_sched-message ) )
      WHERE run_uuid = @is_row-runuuid.

  ENDMETHOD.

ENDCLASS.
