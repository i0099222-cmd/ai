"! <p class="shorttext synchronized">ZI_JOB_RUN Behavior Implementation</p>
"!
"! AS-IS 인터페이스 대응:
"!   ZBC_BATCH_JOB_CREATE -> create 후 scheduleJob
"!   ZBC_BATCH_JOB_CHANGE -> update 후 cancelJob + scheduleJob
"!   ZBC_BATCH_JOB_DELETE -> cancelJob
"!   ZBC_BATCH_JOB_STATUS -> refreshStatus
"!
"! 액션은 전부 ZCL_JOB_APJ_ADAPTER 를 거쳐 CL_APJ_RT_API 를 호출한다. BDC 없음.
CLASS zbp_i_job_run DEFINITION
  PUBLIC
  ABSTRACT
  FINAL
  FOR BEHAVIOR OF zi_job_run.
ENDCLASS.

CLASS zbp_i_job_run IMPLEMENTATION.
ENDCLASS.


CLASS lhc_jobrun DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR jobrun RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR jobrun RESULT result.

    METHODS schedulejob FOR MODIFY
      IMPORTING keys FOR ACTION jobrun~schedulejob RESULT result.

    METHODS canceljob FOR MODIFY
      IMPORTING keys FOR ACTION jobrun~canceljob RESULT result.

    METHODS refreshstatus FOR MODIFY
      IMPORTING keys FOR ACTION jobrun~refreshstatus RESULT result.

    METHODS read_self
      IMPORTING keys          TYPE ANY TABLE
      RETURNING VALUE(result) TYPE TABLE FOR ACTION RESULT zi_job_run~schedulejob.

ENDCLASS.


CLASS lhc_jobrun IMPLEMENTATION.

  METHOD get_global_authorizations.
    " 테스트 단계 - 전부 허용. 운영에서는 업무 권한객체로 제한할 것.
  ENDMETHOD.


  METHOD get_instance_features.

    READ ENTITIES OF zi_job_run IN LOCAL MODE
      ENTITY jobrun
        FIELDS ( jobstatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_run)
      FAILED failed.

    result = VALUE #( FOR ls_run IN lt_run
      ( %tky = ls_run-%tky

        " 아직 안 걸었거나 끝난 잡만 스케줄 가능
        %action-schedulejob = COND #(
          WHEN ls_run-jobstatus = zif_bc_job=>gc_status-initial
            OR ls_run-jobstatus = zif_bc_job=>gc_status-finished
            OR ls_run-jobstatus = zif_bc_job=>gc_status-error
            OR ls_run-jobstatus = zif_bc_job=>gc_status-cancelled
          THEN if_abap_behv=>fc-o-enabled
          ELSE if_abap_behv=>fc-o-disabled )

        " 걸려 있거나 도는 중인 잡만 취소 가능
        %action-canceljob = COND #(
          WHEN ls_run-jobstatus = zif_bc_job=>gc_status-scheduled
            OR ls_run-jobstatus = zif_bc_job=>gc_status-running
          THEN if_abap_behv=>fc-o-enabled
          ELSE if_abap_behv=>fc-o-disabled ) ) ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 스케줄 - AS-IS ZBC_BATCH_JOB_CREATE 의 실행 부분
*   시작 조건은 DB 가 아니라 액션 파라미터(%param)에서 온다.
*----------------------------------------------------------------------*
  METHOD schedulejob.

    READ ENTITIES OF zi_job_run IN LOCAL MODE
      ENTITY jobrun
        FIELDS ( jobtemplatename jobtext )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_run)
      FAILED failed.

    DATA lt_update TYPE TABLE FOR UPDATE zi_job_run.
    DATA(lo_adapter) = NEW zcl_job_apj_adapter( ).

    LOOP AT lt_run INTO DATA(ls_run).

      DATA(ls_p) = keys[ %tky = ls_run-%tky ]-%param.

      DATA(ls_start) = VALUE zif_bc_job=>ty_start_option(
        start_immediately = ls_p-startimmediately
        start_date        = ls_p-startdate
        start_time        = ls_p-starttime
        timezone          = ls_p-timezone
        prd_mins          = ls_p-periodminutes
        prd_hours         = ls_p-periodhours
        prd_days          = ls_p-perioddays
        prd_weeks         = ls_p-periodweeks
        prd_months        = ls_p-periodmonths ).

      DATA(ls_sched) = lo_adapter->schedule(
        iv_run_uuid = ls_run-runuuid
        iv_template = ls_run-jobtemplatename
        iv_jobtext  = ls_run-jobtext
        is_start    = ls_start ).

      IF ls_sched-success = abap_false.
        APPEND VALUE #( %tky = ls_run-%tky ) TO failed-jobrun.
        APPEND VALUE #( %tky = ls_run-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = ls_sched-message ) )
               TO reported-jobrun.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky      = ls_run-%tky
                      jobname   = ls_sched-job_name
                      jobcount  = ls_sched-job_count
                      jobstatus = zif_bc_job=>gc_status-scheduled
                      message   = CONV #( ls_sched-message ) )
             TO lt_update.

    ENDLOOP.

    MODIFY ENTITIES OF zi_job_run IN LOCAL MODE
      ENTITY jobrun
        UPDATE FIELDS ( jobname jobcount jobstatus message )
        WITH lt_update.

    result = read_self( keys ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 취소 - AS-IS ZBC_BATCH_JOB_DELETE
*----------------------------------------------------------------------*
  METHOD canceljob.

    READ ENTITIES OF zi_job_run IN LOCAL MODE
      ENTITY jobrun
        FIELDS ( jobname jobcount )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_run)
      FAILED failed.

    DATA lt_update TYPE TABLE FOR UPDATE zi_job_run.
    DATA(lo_adapter) = NEW zcl_job_apj_adapter( ).

    LOOP AT lt_run INTO DATA(ls_run).

      DATA(lv_message) = lo_adapter->cancel( iv_job_name  = ls_run-jobname
                                             iv_job_count = ls_run-jobcount ).

      APPEND VALUE #( %tky      = ls_run-%tky
                      jobstatus = zif_bc_job=>gc_status-cancelled
                      message   = CONV #( lv_message ) )
             TO lt_update.

      APPEND VALUE #( %tky = ls_run-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-success
                               text     = lv_message ) )
             TO reported-jobrun.

    ENDLOOP.

    MODIFY ENTITIES OF zi_job_run IN LOCAL MODE
      ENTITY jobrun
        UPDATE FIELDS ( jobstatus message )
        WITH lt_update.

    result = read_self( keys ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 상태 조회 - AS-IS ZBC_BATCH_JOB_STATUS
*   진실의 원천은 APJ 다. 여기서 읽어 DB 캐시를 갱신한다.
*----------------------------------------------------------------------*
  METHOD refreshstatus.

    READ ENTITIES OF zi_job_run IN LOCAL MODE
      ENTITY jobrun
        FIELDS ( jobname jobcount )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_run)
      FAILED failed.

    DATA lt_update TYPE TABLE FOR UPDATE zi_job_run.
    DATA(lo_adapter) = NEW zcl_job_apj_adapter( ).

    LOOP AT lt_run INTO DATA(ls_run).

      " 아직 스케줄 안 한 행은 건너뛴다
      CHECK ls_run-jobname IS NOT INITIAL.

      DATA(ls_status) = lo_adapter->get_status( iv_job_name  = ls_run-jobname
                                                iv_job_count = ls_run-jobcount ).

      APPEND VALUE #( %tky      = ls_run-%tky
                      jobstatus = ls_status-status
                      message   = CONV #( ls_status-message ) )
             TO lt_update.

    ENDLOOP.

    MODIFY ENTITIES OF zi_job_run IN LOCAL MODE
      ENTITY jobrun
        UPDATE FIELDS ( jobstatus message )
        WITH lt_update.

    result = read_self( keys ).

  ENDMETHOD.


  METHOD read_self.

    READ ENTITIES OF zi_job_run IN LOCAL MODE
      ENTITY jobrun
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_res IN lt_result
                      ( %tky = ls_res-%tky %param = ls_res ) ).

  ENDMETHOD.

ENDCLASS.
