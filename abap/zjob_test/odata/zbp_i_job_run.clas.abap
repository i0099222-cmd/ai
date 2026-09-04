"! <p class="shorttext synchronized">ZI_JOB_RUN Behavior Implementation</p>
"!
"! Application Job 기능을 OData 액션으로 노출한다.
"!   scheduleJob   : CL_APJ_RT_API=>SCHEDULE_JOB   (POST .../JobRun/...scheduleJob)
"!   refreshStatus : CL_APJ_RT_API=>GET_JOB_STATUS (POST .../JobRun(...)/...refreshStatus)
"!   cancelJob     : CL_APJ_RT_API=>CANCEL_JOB     (POST .../JobRun(...)/...cancelJob)
"!
"! NOTE (RAP 원칙):
"!   외부 시스템/프레임워크 호출은 원칙적으로 save 시퀀스(additional save)에서
"!   수행하는 게 정석이다. 여기서는 "APJ 기능을 눌러보고 결과를 바로 확인"하는
"!   테스트 목적이 우선이라 액션 핸들러에서 바로 호출한다.
"!   운영성 코드로 승격할 때는 saver 로 옮길 것.
CLASS zbp_i_job_run DEFINITION
  PUBLIC
  ABSTRACT
  FINAL
  FOR BEHAVIOR OF zi_job_run.
ENDCLASS.

CLASS zbp_i_job_run IMPLEMENTATION.
ENDCLASS.


*----------------------------------------------------------------------*
* Local handler
*----------------------------------------------------------------------*
CLASS lhc_jobrun DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR jobrun RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR jobrun RESULT result.

    METHODS schedulejob FOR MODIFY
      IMPORTING keys FOR ACTION jobrun~schedulejob.

    METHODS refreshstatus FOR MODIFY
      IMPORTING keys FOR ACTION jobrun~refreshstatus RESULT result.

    METHODS canceljob FOR MODIFY
      IMPORTING keys FOR ACTION jobrun~canceljob RESULT result.

    METHODS current_timestamp
      RETURNING VALUE(rv_stamp) TYPE timestampl.

ENDCLASS.


CLASS lhc_jobrun IMPLEMENTATION.

  METHOD get_global_authorizations.
    " 테스트 서비스 - 전부 허용. 운영에서는 S_APJ / 커스텀 권한객체로 제한할 것.
  ENDMETHOD.


  METHOD get_instance_features.

    READ ENTITIES OF zi_job_run IN LOCAL MODE
      ENTITY jobrun
        FIELDS ( jobstatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_runs)
      FAILED failed.

    result = VALUE #( FOR ls_run IN lt_runs
      ( %tky = ls_run-%tky
        " 이미 끝난 잡은 취소 버튼을 비활성화한다.
        %action-canceljob = COND #(
          WHEN ls_run-jobstatus = zif_job_test=>gc_status-scheduled
            OR ls_run-jobstatus = zif_job_test=>gc_status-running
          THEN if_abap_behv=>fc-o-enabled
          ELSE if_abap_behv=>fc-o-disabled ) ) ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* Application Job 스케줄 (static factory action)
*----------------------------------------------------------------------*
  METHOD schedulejob.

    DATA lt_create TYPE TABLE FOR CREATE zi_job_run.

    DATA(lo_adapter) = NEW zcl_job_apj_adapter( ).

    LOOP AT keys INTO DATA(ls_key).

      DATA(ls_p) = ls_key-%param.

      DATA(ls_request) = VALUE zcl_job_apj_adapter=>ty_schedule_request(
        job_template_name  = ls_p-jobtemplatename
        params             = VALUE #( run_tag    = ls_p-runtag
                                      rec_count  = ls_p-recordcount
                                      sleep_secs = ls_p-sleepseconds
                                      force_fail = ls_p-forcefail )
        start_immediately  = ls_p-startimmediately
        start_date         = ls_p-startdate
        start_time         = ls_p-starttime
        timezone           = ls_p-timezone
        recurrence_minutes = ls_p-recurrenceminutes
        end_date           = ls_p-enddate ).

      DATA(ls_sched) = lo_adapter->schedule( ls_request ).

      IF ls_sched-success = abap_false.
        APPEND VALUE #( %cid = ls_key-%cid ) TO failed-jobrun.
        APPEND VALUE #( %cid = ls_key-%cid
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = ls_sched-message ) )
               TO reported-jobrun.
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        %cid              = ls_key-%cid
        jobtemplatename   = ls_p-jobtemplatename
        jobname           = ls_sched-job_name
        jobcount          = ls_sched-job_count
        runtag            = ls_p-runtag
        recordcount       = ls_p-recordcount
        sleepseconds      = ls_p-sleepseconds
        forcefail         = ls_p-forcefail
        startimmediately  = ls_p-startimmediately
        startdate         = ls_p-startdate
        starttime         = ls_p-starttime
        timezone          = ls_p-timezone
        recurrenceminutes = ls_p-recurrenceminutes
        enddate           = ls_p-enddate
        jobstatus         = zif_job_test=>gc_status-scheduled
        scheduledat       = current_timestamp( )
        lastmessage       = CONV #( ls_sched-message ) )
        TO lt_create.

    ENDLOOP.

    CHECK lt_create IS NOT INITIAL.

    MODIFY ENTITIES OF zi_job_run IN LOCAL MODE
      ENTITY jobrun
        CREATE FIELDS ( jobtemplatename jobname jobcount
                        runtag recordcount sleepseconds forcefail
                        startimmediately startdate starttime timezone
                        recurrenceminutes enddate
                        jobstatus scheduledat lastmessage )
        WITH lt_create
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    mapped-jobrun   = CORRESPONDING #( ls_mapped-jobrun ).
    failed-jobrun   = VALUE #( BASE failed-jobrun   ( LINES OF CORRESPONDING #( ls_failed-jobrun ) ) ).
    reported-jobrun = VALUE #( BASE reported-jobrun ( LINES OF CORRESPONDING #( ls_reported-jobrun ) ) ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 상태 폴링
*----------------------------------------------------------------------*
  METHOD refreshstatus.

    READ ENTITIES OF zi_job_run IN LOCAL MODE
      ENTITY jobrun
        FIELDS ( jobname jobcount )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_runs)
      FAILED failed.

    DATA lt_update TYPE TABLE FOR UPDATE zi_job_run.
    DATA(lo_adapter) = NEW zcl_job_apj_adapter( ).

    LOOP AT lt_runs INTO DATA(ls_run).

      DATA(ls_status) = lo_adapter->get_status( iv_job_name  = ls_run-jobname
                                                iv_job_count = ls_run-jobcount ).

      APPEND VALUE #( %tky          = ls_run-%tky
                      jobstatus     = ls_status-status
                      lastcheckedat = current_timestamp( )
                      lastmessage   = CONV #( ls_status-message ) )
             TO lt_update.

    ENDLOOP.

    MODIFY ENTITIES OF zi_job_run IN LOCAL MODE
      ENTITY jobrun
        UPDATE FIELDS ( jobstatus lastcheckedat lastmessage )
        WITH lt_update
      REPORTED DATA(ls_reported).

    reported = CORRESPONDING #( DEEP ls_reported ).

    READ ENTITIES OF zi_job_run IN LOCAL MODE
      ENTITY jobrun
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_res IN lt_result
                      ( %tky = ls_res-%tky %param = ls_res ) ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 취소
*----------------------------------------------------------------------*
  METHOD canceljob.

    READ ENTITIES OF zi_job_run IN LOCAL MODE
      ENTITY jobrun
        FIELDS ( jobname jobcount )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_runs)
      FAILED failed.

    DATA lt_update TYPE TABLE FOR UPDATE zi_job_run.
    DATA(lo_adapter) = NEW zcl_job_apj_adapter( ).

    LOOP AT lt_runs INTO DATA(ls_run).

      DATA(lv_message) = lo_adapter->cancel( iv_job_name  = ls_run-jobname
                                             iv_job_count = ls_run-jobcount ).

      APPEND VALUE #( %tky          = ls_run-%tky
                      jobstatus     = zif_job_test=>gc_status-cancelled
                      lastcheckedat = current_timestamp( )
                      lastmessage   = CONV #( lv_message ) )
             TO lt_update.

      APPEND VALUE #( %tky = ls_run-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-success
                               text     = lv_message ) )
             TO reported-jobrun.

    ENDLOOP.

    MODIFY ENTITIES OF zi_job_run IN LOCAL MODE
      ENTITY jobrun
        UPDATE FIELDS ( jobstatus lastcheckedat lastmessage )
        WITH lt_update.

    READ ENTITIES OF zi_job_run IN LOCAL MODE
      ENTITY jobrun
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_res IN lt_result
                      ( %tky = ls_res-%tky %param = ls_res ) ).

  ENDMETHOD.


  METHOD current_timestamp.
    GET TIME STAMP FIELD rv_stamp.
  ENDMETHOD.

ENDCLASS.
