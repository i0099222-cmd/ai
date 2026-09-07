"! <p class="shorttext synchronized">ZI_BATCH_SCHEDULE Behavior Implementation</p>
"!
"! AS-IS 인터페이스 대응:
"!   ZBC_BATCH_JOB_CREATE -> createJob   (등록부 행 + APJ 잡을 한 번에)
"!   ZBC_BATCH_JOB_CHANGE -> changeJob   (취소 + 재생성)
"!   ZBC_BATCH_JOB_DELETE -> cancelJob
"!   ZBC_BATCH_JOB_STATUS -> refreshStatus (APJ 에서 읽어 메시지로 반환)
"!
"! ** LUW 분리 **
"!   CL_APJ_RT_API 의 SCHEDULE_JOB / CANCEL_JOB 은 RAP 인터랙션 단계에서
"!   호출할 수 없다. RAP 이 LUW 를 소유하는데 이 API 들이 트랜잭션을 건드려서
"!   덤프가 난다.
"!
"!   그래서 액션은 "무엇을 할지" 만 LCL_APJ_BUFFER 에 담고,
"!   실제 APJ 호출은 saver(LSC_ZI_BATCH_SCHEDULE~SAVE_MODIFIED)에서 한다.
"!
"!   대가: save 단계에서는 reported 로 메시지를 돌려줄 수 없다.
"!         APJ 응답은 ZTBATCH_SCHED-MESSAGE 에 기록하고,
"!         실패하면 JOBNAME 이 빈 채로 남는다 (IsScheduled = '').
"!
"!   refreshStatus 는 GET_JOB_STATUS 로 읽기만 하므로 인터랙션 단계에 남겨둔다.
CLASS zbp_i_batch_schedule DEFINITION
  PUBLIC
  ABSTRACT
  FINAL
  FOR BEHAVIOR OF zi_batch_schedule.
ENDCLASS.

CLASS zbp_i_batch_schedule IMPLEMENTATION.
ENDCLASS.


*&---------------------------------------------------------------------*
*& 인터랙션 단계 -> save 단계로 넘기는 버퍼
*&---------------------------------------------------------------------*
CLASS lcl_apj_buffer DEFINITION CREATE PRIVATE.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF gc_mode,
        schedule   TYPE c LENGTH 1 VALUE 'S',   "! 신규 스케줄
        reschedule TYPE c LENGTH 1 VALUE 'R',   "! 취소 후 재스케줄
        cancel     TYPE c LENGTH 1 VALUE 'C',   "! 취소
      END OF gc_mode.

    TYPES:
      BEGIN OF ty_request,
        run_uuid TYPE ztbatch_sched-run_uuid,
        mode     TYPE c LENGTH 1,
        template TYPE ztbatch_sched-template,
        jobtext  TYPE ztbatch_sched-jobtext,
        param    TYPE string,
        jobname  TYPE ztbatch_sched-jobname,    "! 취소 대상
        jobcount TYPE ztbatch_sched-jobcount,   "! 취소 대상
        start    TYPE zif_batch_job=>ty_start_option,
      END OF ty_request,
      tt_request TYPE STANDARD TABLE OF ty_request WITH EMPTY KEY.

    CLASS-METHODS add
      IMPORTING is_request TYPE ty_request.

    CLASS-METHODS get
      RETURNING VALUE(rt_request) TYPE tt_request.

    CLASS-METHODS reset.

  PRIVATE SECTION.
    CLASS-DATA mt_request TYPE tt_request.

ENDCLASS.


CLASS lcl_apj_buffer IMPLEMENTATION.

  METHOD add.
    APPEND is_request TO mt_request.
  ENDMETHOD.

  METHOD get.
    rt_request = mt_request.
  ENDMETHOD.

  METHOD reset.
    CLEAR mt_request.
  ENDMETHOD.

ENDCLASS.


*&---------------------------------------------------------------------*
*& 인터랙션 단계 핸들러
*&---------------------------------------------------------------------*
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
* 잡 생성 - AS-IS ZBC_BATCH_JOB_CREATE
*   SAP 에서 잡 생성 = 스케줄 등록이다. 한 번의 호출로
*   등록부 행 1건 + APJ 잡 1건이 만들어진다.
*
*   여기서는 행만 만들고 스케줄 요청은 버퍼에 담는다.
*   실제 SCHEDULE_JOB 은 saver 에서 호출한다.
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

    " UUID 키는 managed numbering 이 early numbering 이라
    " MODIFY 직후 mapped 에서 바로 읽을 수 있다.
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

    LOOP AT ls_mapped-batchschedule INTO DATA(ls_new).

      DATA(ls_ck) = VALUE #( keys[ %cid = ls_new-%cid ] OPTIONAL ).
      CHECK ls_ck IS NOT INITIAL.

      DATA(ls_cp) = ls_ck-%param.

      lcl_apj_buffer=>add( VALUE #(
        run_uuid = ls_new-runuuid
        mode     = lcl_apj_buffer=>gc_mode-schedule
        template = ls_cp-jobtemplatename
        jobtext  = ls_cp-jobtext
        param    = ls_cp-parameters
        start    = VALUE #( start_immediately = ls_cp-startimmediately
                            start_date        = ls_cp-startdate
                            start_time        = ls_cp-starttime
                            timezone          = ls_cp-timezone
                            prd_mins          = ls_cp-periodminutes
                            prd_hours         = ls_cp-periodhours
                            prd_days          = ls_cp-perioddays
                            prd_weeks         = ls_cp-periodweeks
                            prd_months        = ls_cp-periodmonths ) ) ).

    ENDLOOP.

  ENDMETHOD.


*----------------------------------------------------------------------*
* 스케줄 변경 - AS-IS ZBC_BATCH_JOB_CHANGE
*   APJ 에 잡 수정 API 가 없어 취소 + 재생성이다.
*   그 결과 SM37 의 jobname/jobcount 가 바뀐다.
*----------------------------------------------------------------------*
  METHOD changejob.

    READ ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        FIELDS ( jobtemplatename jobtext parameters jobname jobcount )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_run)
      FAILED failed.

    LOOP AT lt_run INTO DATA(ls_run).

      DATA(ls_p) = keys[ %tky = ls_run-%tky ]-%param.

      lcl_apj_buffer=>add( VALUE #(
        run_uuid = ls_run-runuuid
        mode     = lcl_apj_buffer=>gc_mode-reschedule
        template = ls_run-jobtemplatename
        jobtext  = ls_run-jobtext
        param    = ls_run-parameters
        jobname  = ls_run-jobname
        jobcount = ls_run-jobcount
        start    = VALUE #( start_immediately = ls_p-startimmediately
                            start_date        = ls_p-startdate
                            start_time        = ls_p-starttime
                            timezone          = ls_p-timezone
                            prd_mins          = ls_p-periodminutes
                            prd_hours         = ls_p-periodhours
                            prd_days          = ls_p-perioddays
                            prd_weeks         = ls_p-periodweeks
                            prd_months        = ls_p-periodmonths ) ) ).

    ENDLOOP.

    result = read_self( keys ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 잡 취소 - AS-IS ZBC_BATCH_JOB_DELETE
*   등록부 행은 남고 APJ 포인터만 비워진다 (다시 걸 수 있음).
*----------------------------------------------------------------------*
  METHOD canceljob.

    READ ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        FIELDS ( jobname jobcount )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_run)
      FAILED failed.

    LOOP AT lt_run INTO DATA(ls_run).

      CHECK ls_run-jobname IS NOT INITIAL.

      lcl_apj_buffer=>add( VALUE #(
        run_uuid = ls_run-runuuid
        mode     = lcl_apj_buffer=>gc_mode-cancel
        jobname  = ls_run-jobname
        jobcount = ls_run-jobcount ) ).

    ENDLOOP.

    result = read_self( keys ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 상태 조회 - AS-IS ZBC_BATCH_JOB_STATUS
*   GET_JOB_STATUS 는 읽기만 하므로 인터랙션 단계에 남겨둔다.
*   진실의 원천은 APJ 이고 DB 에 쓰지 않는다.
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
    METHODS save_modified    REDEFINITION.
    METHODS cleanup          REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.

ENDCLASS.


CLASS lsc_zi_batch_schedule IMPLEMENTATION.

  METHOD save_modified.

    DATA(lt_request) = lcl_apj_buffer=>get( ).
    CHECK lt_request IS NOT INITIAL.

    DATA(lo_adapter) = NEW zcl_batch_apj_adapter( ).

    DATA lv_empty_name  TYPE ztbatch_sched-jobname.
    DATA lv_empty_count TYPE ztbatch_sched-jobcount.

    LOOP AT lt_request INTO DATA(ls_req).

      " --- 취소가 필요한 경우 먼저 끊는다 (cancel / reschedule) ---
      DATA(lv_cancel_msg) = VALUE string( ).

      IF ls_req-mode = lcl_apj_buffer=>gc_mode-cancel
         OR ls_req-mode = lcl_apj_buffer=>gc_mode-reschedule.

        IF ls_req-jobname IS NOT INITIAL.
          lv_cancel_msg = lo_adapter->cancel( iv_job_name  = ls_req-jobname
                                              iv_job_count = ls_req-jobcount ).
        ENDIF.

      ENDIF.

      " --- 취소만 하고 끝 ---
      IF ls_req-mode = lcl_apj_buffer=>gc_mode-cancel.

        UPDATE ztbatch_sched
          SET jobname  = @lv_empty_name,
              jobcount = @lv_empty_count,
              message  = @( CONV ztbatch_sched-message( lv_cancel_msg ) )
          WHERE run_uuid = @ls_req-run_uuid.

        CONTINUE.
      ENDIF.

      " --- 스케줄 ---
      DATA(ls_sched) = lo_adapter->schedule(
        iv_template = ls_req-template
        iv_jobtext  = ls_req-jobtext
        iv_param    = ls_req-param
        is_start    = ls_req-start ).

      DATA(lv_message) = COND string(
        WHEN lv_cancel_msg IS NOT INITIAL
        THEN |{ lv_cancel_msg } / { ls_sched-message }|
        ELSE ls_sched-message ).

      " 실패하면 jobname 이 빈 채로 남는다. 사유는 message 에 적힌다.
      " save 단계라 reported 로 메시지를 돌려줄 수 없기 때문이다.
      UPDATE ztbatch_sched
        SET jobname  = @ls_sched-job_name,
            jobcount = @ls_sched-job_count,
            message  = @( CONV ztbatch_sched-message( lv_message ) )
        WHERE run_uuid = @ls_req-run_uuid.

    ENDLOOP.

    lcl_apj_buffer=>reset( ).

  ENDMETHOD.


  METHOD cleanup.
    lcl_apj_buffer=>reset( ).
  ENDMETHOD.


  METHOD cleanup_finalize.
    lcl_apj_buffer=>reset( ).
  ENDMETHOD.

ENDCLASS.
