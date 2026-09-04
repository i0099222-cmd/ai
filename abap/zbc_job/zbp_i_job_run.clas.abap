"! <p class="shorttext synchronized">ZI_JOB_RUN Behavior Implementation</p>
"!
"! AS-IS 인터페이스 대응:
"!   ZBC_BATCH_JOB_CREATE -> create(+ 스텝) 후 scheduleJob
"!   ZBC_BATCH_JOB_CHANGE -> update 후 재스케줄
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

    METHODS validateschedule FOR VALIDATE ON SAVE
      IMPORTING keys FOR jobrun~validateschedule.

    METHODS schedulejob FOR MODIFY
      IMPORTING keys FOR ACTION jobrun~schedulejob RESULT result.

    METHODS canceljob FOR MODIFY
      IMPORTING keys FOR ACTION jobrun~canceljob RESULT result.

    METHODS refreshstatus FOR MODIFY
      IMPORTING keys FOR ACTION jobrun~refreshstatus RESULT result.

    METHODS read_self
      IMPORTING keys          TYPE ANY TABLE
      RETURNING VALUE(result) TYPE TABLE FOR ACTION RESULT zi_job_run~schedulejob.

    METHODS now
      RETURNING VALUE(rv_stamp) TYPE timestampl.

ENDCLASS.


CLASS lhc_jobrun IMPLEMENTATION.

  METHOD get_global_authorizations.
    " 테스트 단계 - 전부 허용. 운영에서는 업무구분/시스템 단위로 제한할 것.
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

        " 아직 스케줄 안 했거나 끝난 잡만 스케줄 가능
        %action-schedulejob = COND #(
          WHEN ls_run-jobstatus = zif_bc_job=>gc_status-initial
            OR ls_run-jobstatus = zif_bc_job=>gc_status-finished
            OR ls_run-jobstatus = zif_bc_job=>gc_status-error
            OR ls_run-jobstatus = zif_bc_job=>gc_status-cancelled
          THEN if_abap_behv=>fc-o-enabled
          ELSE if_abap_behv=>fc-o-disabled )

        " 스케줄됐거나 도는 중인 잡만 취소 가능
        %action-canceljob = COND #(
          WHEN ls_run-jobstatus = zif_bc_job=>gc_status-scheduled
            OR ls_run-jobstatus = zif_bc_job=>gc_status-running
          THEN if_abap_behv=>fc-o-enabled
          ELSE if_abap_behv=>fc-o-disabled ) ) ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 저장 시 검증
*   AS-IS 는 BDC 화면이 걸러주던 것들. 이제 코드가 막아야 한다.
*----------------------------------------------------------------------*
  METHOD validateschedule.

    READ ENTITIES OF zi_job_run IN LOCAL MODE
      ENTITY jobrun
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_run).

    LOOP AT lt_run INTO DATA(ls_run).

      DATA(lv_error) = VALUE string( ).

      IF ls_run-joblabel IS INITIAL.
        lv_error = '배치잡 명이 필요합니다'.

      ELSEIF ls_run-startimmediately = abap_false
             AND ls_run-startdate IS INITIAL.
        lv_error = '즉시 시작이 아니면 시작일이 필요합니다'.

      ELSE.
        " 반복 주기는 한 단위만 채워야 한다
        DATA(lv_prd) = 0.
        IF ls_run-periodminutes > 0. lv_prd = lv_prd + 1. ENDIF.
        IF ls_run-periodhours   > 0. lv_prd = lv_prd + 1. ENDIF.
        IF ls_run-perioddays    > 0. lv_prd = lv_prd + 1. ENDIF.
        IF ls_run-periodweeks   > 0. lv_prd = lv_prd + 1. ENDIF.
        IF ls_run-periodmonths  > 0. lv_prd = lv_prd + 1. ENDIF.

        IF lv_prd > 1.
          lv_error = '반복 주기는 한 단위만 지정할 수 있습니다'.
        ENDIF.
      ENDIF.

      IF lv_error IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_run-%tky ) TO failed-jobrun.
        APPEND VALUE #( %tky = ls_run-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = lv_error ) )
               TO reported-jobrun.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


*----------------------------------------------------------------------*
* 스케줄 - AS-IS ZBC_BATCH_JOB_CREATE 의 실행 부분
*----------------------------------------------------------------------*
  METHOD schedulejob.

    READ ENTITIES OF zi_job_run IN LOCAL MODE
      ENTITY jobrun
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_run)
      FAILED failed.

    DATA lt_update TYPE TABLE FOR UPDATE zi_job_run.
    DATA(lo_adapter) = NEW zcl_job_apj_adapter( ).

    LOOP AT lt_run INTO DATA(ls_run).

      DATA(ls_key) = keys[ %tky = ls_run-%tky ].

      " CDS 요소명 -> 테이블 필드명으로 되돌려서 어댑터에 넘긴다
      DATA(ls_db) = VALUE ztjob_run(
        run_uuid          = ls_run-runuuid
        job_label         = ls_run-joblabel
        job_template      = ls_key-%param-jobtemplatename
        start_immediately = ls_run-startimmediately
        start_date        = ls_run-startdate
        start_time        = ls_run-starttime
        timezone          = ls_run-timezone
        prd_mins          = ls_run-periodminutes
        prd_hours         = ls_run-periodhours
        prd_days          = ls_run-perioddays
        prd_weeks         = ls_run-periodweeks
        prd_months        = ls_run-periodmonths ).

      DATA(ls_sched) = lo_adapter->schedule( ls_db ).

      IF ls_sched-success = abap_false.
        APPEND VALUE #( %tky = ls_run-%tky ) TO failed-jobrun.
        APPEND VALUE #( %tky = ls_run-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = ls_sched-message ) )
               TO reported-jobrun.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky            = ls_run-%tky
                      jobtemplatename = ls_key-%param-jobtemplatename
                      jobname         = ls_sched-job_name
                      jobcount        = ls_sched-job_count
                      jobstatus       = zif_bc_job=>gc_status-scheduled
                      scheduledat     = now( )
                      lastmessage     = CONV #( ls_sched-message ) )
             TO lt_update.

    ENDLOOP.

    MODIFY ENTITIES OF zi_job_run IN LOCAL MODE
      ENTITY jobrun
        UPDATE FIELDS ( jobtemplatename jobname jobcount
                        jobstatus scheduledat lastmessage )
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

      APPEND VALUE #( %tky          = ls_run-%tky
                      jobstatus     = zif_bc_job=>gc_status-cancelled
                      lastcheckedat = now( )
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

    result = read_self( keys ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 상태 조회 - AS-IS ZBC_BATCH_JOB_STATUS
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

      APPEND VALUE #( %tky          = ls_run-%tky
                      jobstatus     = ls_status-status
                      lastcheckedat = now( )
                      lastmessage   = CONV #( ls_status-message ) )
             TO lt_update.

    ENDLOOP.

    MODIFY ENTITIES OF zi_job_run IN LOCAL MODE
      ENTITY jobrun
        UPDATE FIELDS ( jobstatus lastcheckedat lastmessage )
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


  METHOD now.
    GET TIME STAMP FIELD rv_stamp.
  ENDMETHOD.

ENDCLASS.
