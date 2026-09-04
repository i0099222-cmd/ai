"! <p class="shorttext synchronized">ZI_BATCH_SCHEDULE Behavior Implementation</p>
"!
"! AS-IS 인터페이스 대응:
"!   ZBC_BATCH_JOB_CREATE -> createJob   (등록부 행 + APJ 잡을 한 번에)
"!   ZBC_BATCH_JOB_CHANGE -> changeJob   (취소 + 재생성)
"!   ZBC_BATCH_JOB_DELETE -> cancelJob
"!   ZBC_BATCH_JOB_STATUS -> refreshStatus (APJ 에서 읽어 메시지로 반환)
"!
"! 액션은 전부 ZCL_BATCH_APJ_ADAPTER 를 거쳐 CL_APJ_RT_API 를 호출한다. BDC 없음.
"!
"! 이 BO 는 상태 컬럼을 갖지 않는다. 스케줄 여부는 JobName 유무로 판단하고,
"! 실제 실행 상태는 refreshStatus 가 APJ 에서 읽어 메시지로만 돌려준다.
"! 실행 이력은 별도 로그 기능이 담당한다.
CLASS zbp_i_batch_schedule DEFINITION
  PUBLIC
  ABSTRACT
  FINAL
  FOR BEHAVIOR OF zi_batch_schedule.
ENDCLASS.

CLASS zbp_i_batch_schedule IMPLEMENTATION.
ENDCLASS.


CLASS lhc_schedule DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR batchschedule RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR batchschedule RESULT result.

    METHODS createjob FOR MODIFY
      IMPORTING keys FOR ACTION batchschedule~createjob.

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

    " 상태 컬럼 없이 잡 이름 유무만으로 판단한다.
    "   차 있음   = 스케줄됨   -> changeJob / cancelJob / refreshStatus 가능
    "   비어 있음 = 취소된 행  -> 위 액션 전부 비활성 (createJob 으로 새로 만든다)
    result = VALUE #( FOR ls_run IN lt_run
      ( %tky = ls_run-%tky

        %action-canceljob = COND #(
          WHEN ls_run-jobname IS NOT INITIAL
          THEN if_abap_behv=>fc-o-enabled
          ELSE if_abap_behv=>fc-o-disabled )

        %action-refreshstatus = COND #(
          WHEN ls_run-jobname IS NOT INITIAL
          THEN if_abap_behv=>fc-o-enabled
          ELSE if_abap_behv=>fc-o-disabled )

        " 변경은 이미 걸려 있는 잡을 취소하고 다시 거는 것
        %action-changejob = COND #(
          WHEN ls_run-jobname IS NOT INITIAL
          THEN if_abap_behv=>fc-o-enabled
          ELSE if_abap_behv=>fc-o-disabled ) ) ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 등록 + 스케줄 - AS-IS ZBC_BATCH_JOB_CREATE 1:1 대응
*   SAP 에서 잡 생성 = 스케줄 등록이다. 한 번의 호출로
*   등록부 행 1건 + APJ 잡 1건이 만들어진다.
*
*   NOTE: UUID 키는 managed numbering 이 early numbering 이라
*         MODIFY 직후 mapped 에서 바로 읽을 수 있다. 그 값을 APJ 에 넘긴다.
*   NOTE: APJ 호출이 인터랙션 단계에서 일어나므로, 이후 트랜잭션이 롤백되면
*         잡만 남는다. 운영성 코드로 승격할 때는 saver 로 옮길 것.
*----------------------------------------------------------------------*
  METHOD createjob.

    DATA lt_create TYPE TABLE FOR CREATE zi_batch_schedule.

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_p) = ls_key-%param.

      APPEND VALUE #( %cid            = ls_key-%cid
                      jobtemplatename = ls_p-jobtemplatename
                      jobtext         = ls_p-jobtext
                      parameters      = ls_p-parameters )
             TO lt_create.
    ENDLOOP.

    CHECK lt_create IS NOT INITIAL.

    " 1) 행 생성 - UUID 를 여기서 얻는다
    MODIFY ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        CREATE FIELDS ( jobtemplatename jobtext parameters )
        WITH lt_create
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    mapped-batchschedule   = CORRESPONDING #( ls_mapped-batchschedule ).
    failed-batchschedule   = VALUE #( BASE failed-batchschedule
                                      ( LINES OF CORRESPONDING #( ls_failed-batchschedule ) ) ).
    reported-batchschedule = VALUE #( BASE reported-batchschedule
                                      ( LINES OF CORRESPONDING #( ls_reported-batchschedule ) ) ).

    " 2) 생성된 행을 APJ 에 스케줄
    DATA lt_update TYPE TABLE FOR UPDATE zi_batch_schedule.
    DATA(lo_adapter) = NEW zcl_batch_apj_adapter( ).

    LOOP AT ls_mapped-batchschedule INTO DATA(ls_new).

      DATA(ls_ck) = VALUE #( keys[ %cid = ls_new-%cid ] OPTIONAL ).
      CHECK ls_ck IS NOT INITIAL.

      DATA(ls_cp) = ls_ck-%param.

      DATA(ls_sched) = lo_adapter->schedule(
        iv_template = ls_cp-jobtemplatename
        iv_jobtext  = ls_cp-jobtext
        iv_param    = ls_cp-parameters
        is_start    = VALUE #( start_immediately = ls_cp-startimmediately
                               start_date        = ls_cp-startdate
                               start_time        = ls_cp-starttime
                               timezone          = ls_cp-timezone
                               prd_mins          = ls_cp-periodminutes
                               prd_hours         = ls_cp-periodhours
                               prd_days          = ls_cp-perioddays
                               prd_weeks         = ls_cp-periodweeks
                               prd_months        = ls_cp-periodmonths ) ).

      APPEND VALUE #( %tky = VALUE #( runuuid = ls_new-runuuid )
                      %msg = new_message_with_text(
                               severity = COND #( WHEN ls_sched-success = abap_true
                                                  THEN if_abap_behv_message=>severity-success
                                                  ELSE if_abap_behv_message=>severity-error )
                               text     = ls_sched-message ) )
             TO reported-batchschedule.

      CHECK ls_sched-success = abap_true.

      APPEND VALUE #( %tky     = VALUE #( runuuid = ls_new-runuuid )
                      jobname  = ls_sched-job_name
                      jobcount = ls_sched-job_count )
             TO lt_update.

    ENDLOOP.

    " 3) APJ 포인터 기록
    MODIFY ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        UPDATE FIELDS ( jobname jobcount )
        WITH lt_update.

  ENDMETHOD.


*----------------------------------------------------------------------*
* 재스케줄 - AS-IS ZBC_BATCH_JOB_CHANGE 의 스케줄 변경 부분
*   기존 잡을 취소하고 새 조건으로 다시 건다.
*   NOTE: APJ 에 잡 수정 API 가 없어서 취소 + 재생성이다.
*         그래서 SM37 의 jobname/jobcount 가 바뀐다.
*----------------------------------------------------------------------*
  METHOD changejob.

    READ ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        FIELDS ( jobtemplatename jobtext parameters jobname jobcount )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_run)
      FAILED failed.

    DATA lt_update TYPE TABLE FOR UPDATE zi_batch_schedule.
    DATA(lo_adapter) = NEW zcl_batch_apj_adapter( ).

    LOOP AT lt_run INTO DATA(ls_run).

      " 1) 기존 잡 취소
      IF ls_run-jobname IS NOT INITIAL.
        DATA(lv_cancel_msg) = lo_adapter->cancel( iv_job_name  = ls_run-jobname
                                                  iv_job_count = ls_run-jobcount ).

        APPEND VALUE #( %tky = ls_run-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-information
                                 text     = lv_cancel_msg ) )
               TO reported-batchschedule.
      ENDIF.

      " 2) 새 조건으로 다시 스케줄
      DATA(ls_p) = keys[ %tky = ls_run-%tky ]-%param.

      DATA(ls_sched) = lo_adapter->schedule(
        iv_template = ls_run-jobtemplatename
        iv_jobtext  = ls_run-jobtext
        iv_param    = ls_run-parameters
        is_start    = VALUE #( start_immediately = ls_p-startimmediately
                               start_date        = ls_p-startdate
                               start_time        = ls_p-starttime
                               timezone          = ls_p-timezone
                               prd_mins          = ls_p-periodminutes
                               prd_hours         = ls_p-periodhours
                               prd_days          = ls_p-perioddays
                               prd_weeks         = ls_p-periodweeks
                               prd_months        = ls_p-periodmonths ) ).

      APPEND VALUE #( %tky = ls_run-%tky
                      %msg = new_message_with_text(
                               severity = COND #( WHEN ls_sched-success = abap_true
                                                  THEN if_abap_behv_message=>severity-success
                                                  ELSE if_abap_behv_message=>severity-error )
                               text     = ls_sched-message ) )
             TO reported-batchschedule.

      IF ls_sched-success = abap_false.
        APPEND VALUE #( %tky = ls_run-%tky ) TO failed-batchschedule.
        " 취소는 됐고 재스케줄만 실패 -> 포인터를 비워 다시 걸 수 있게 한다
        APPEND VALUE #( %tky = ls_run-%tky jobname = space jobcount = space ) TO lt_update.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky     = ls_run-%tky
                      jobname  = ls_sched-job_name
                      jobcount = ls_sched-job_count )
             TO lt_update.

    ENDLOOP.

    MODIFY ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        UPDATE FIELDS ( jobname jobcount )
        WITH lt_update.

    result = read_self( keys ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 취소 - AS-IS ZBC_BATCH_JOB_DELETE
*----------------------------------------------------------------------*
  METHOD canceljob.

    READ ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        FIELDS ( jobname jobcount )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_run)
      FAILED failed.

    DATA lt_update TYPE TABLE FOR UPDATE zi_batch_schedule.
    DATA(lo_adapter) = NEW zcl_batch_apj_adapter( ).

    LOOP AT lt_run INTO DATA(ls_run).

      DATA(lv_message) = lo_adapter->cancel( iv_job_name  = ls_run-jobname
                                             iv_job_count = ls_run-jobcount ).

      " 취소했으면 APJ 포인터를 비운다. 같은 행을 다시 스케줄할 수 있게 된다.
      APPEND VALUE #( %tky     = ls_run-%tky
                      jobname  = space
                      jobcount = space )
             TO lt_update.

      APPEND VALUE #( %tky = ls_run-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-success
                               text     = lv_message ) )
             TO reported-batchschedule.

    ENDLOOP.

    MODIFY ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        UPDATE FIELDS ( jobname jobcount )
        WITH lt_update.

    result = read_self( keys ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 상태 조회 - AS-IS ZBC_BATCH_JOB_STATUS
*   진실의 원천은 APJ 다. 여기서 읽어 DB 캐시를 갱신한다.
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

      " DB 에 쓰지 않는다. 진실의 원천은 APJ 이고, 이력은 로그 기능이 갖는다.
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
