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
"! ** 액션 4개가 전부 정적 액션이다 **
"!   외부 호출자는 RunUuid 를 모른다. AS-IS 인터페이스가 jobid/jobcount 로
"!   잡을 지목하고 호출하는 쪽이 그 둘을 자기 DB 에 들고 있기 때문이다.
"!   그래서 잡 이름을 파라미터로 받아 이력 행을 찾는다 - RESOLVE_JOB.
"!
"!   대가: save 단계에서는 reported 로 메시지를 돌려줄 수 없다.
"!         APJ 응답은 ZTBATCH_SCHED-MESSAGE 에 남고, 실패하면 JOBNAME 이
"!         빈 채로 남는다 (IsScheduled = '').
"!
"! ** unmanaged save **
"!   APJ 응답은 save 단계에 가서야 나오는데 그 단계에서는 BO 버퍼를 못
"!   건드린다. additional save 로 두면 managed 런타임이 자기 버퍼로 INSERT
"!   하므로 응답을 넣을 자리가 없다 - 아직 없는 행에 UPDATE 를 날려 조용히
"!   헛돌았다. 그래서 저장을 통째로 가져왔고, saver 가 유일한 writer 다.
"!   대신 관리 필드(CREATED_BY/AT, LOCAL_LAST_CHANGED_AT)도 직접 채운다.
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

    METHODS schedulejob FOR MODIFY
      IMPORTING keys FOR ACTION batchschedule~schedulejob RESULT result.

    METHODS changejob FOR MODIFY
      IMPORTING keys FOR ACTION batchschedule~changejob RESULT result.

    METHODS canceljob FOR MODIFY
      IMPORTING keys FOR ACTION batchschedule~canceljob RESULT result.

    METHODS refreshstatus FOR MODIFY
      IMPORTING keys FOR ACTION batchschedule~refreshstatus RESULT result.

    "! 정적 액션이 %cid 별로 찾아낸 이력 행. 응답을 대응시키는 데 쓴다.
    TYPES: BEGIN OF ty_hit,
             cid      TYPE abp_behv_cid,
             run_uuid TYPE ztbatch_sched-run_uuid,
           END OF ty_hit,
           tt_hit TYPE STANDARD TABLE OF ty_hit WITH EMPTY KEY.

    "! SM37 잡 이름으로 이력 행을 찾는다.
    "!
    "! 외부 호출자는 RunUuid 를 모르고 잡 이름을 들고 있다. 취소된 행은
    "! JOBNAME 이 비어 있으므로 JOBNAME + JOBCOUNT 는 유일하다.
    METHODS resolve_job
      IMPORTING iv_jobname         TYPE ztbatch_sched-jobname
                iv_jobcount        TYPE ztbatch_sched-jobcount
      RETURNING VALUE(rv_run_uuid) TYPE ztbatch_sched-run_uuid.

    "! 찾아낸 행들을 읽어 액션 결과로 만든다.
    METHODS hits_as_result
      IMPORTING it_hit        TYPE tt_hit
      RETURNING VALUE(result) TYPE TABLE FOR ACTION RESULT zi_batch_schedule~changejob.

ENDCLASS.


CLASS lhc_schedule IMPLEMENTATION.

  METHOD get_global_authorizations.
    " 테스트 단계 - 전부 허용. 운영에서는 업무 권한객체로 제한할 것.
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
                      countfrommonthend = ls_p-countfrommonthend
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
                        calendarid monthday useworkingdays countfrommonthend startrestriction )
        WITH lt_create
      MAPPED   DATA(ls_mapped)
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    mapped-batchschedule   = CORRESPONDING #( ls_mapped-batchschedule ).

    failed-batchschedule   = VALUE #( BASE failed-batchschedule
                                      ( LINES OF CORRESPONDING #( ls_failed-batchschedule ) ) ).
    reported-batchschedule = VALUE #( BASE reported-batchschedule
                                      ( LINES OF CORRESPONDING #( ls_reported-batchschedule ) ) ).

    " 호출자에게 RunUuid 를 돌려준다. 이게 이후 액션의 키다.
    READ ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        ALL FIELDS WITH CORRESPONDING #( ls_mapped-batchschedule )
      RESULT DATA(lt_new).

    result = VALUE #( FOR ls_map IN ls_mapped-batchschedule
                      ( %cid   = ls_map-%cid
                        %tky   = ls_map-%tky
                        %param = VALUE #( lt_new[ runuuid = ls_map-runuuid ] OPTIONAL ) ) ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 스케줄 변경 - AS-IS ZBC_BATCH_JOB_CHANGE
*   새 시작 조건만 쓴다. saver 가 update 를 보고 취소 + 재스케줄한다.
*----------------------------------------------------------------------*
  METHOD changejob.

    DATA lt_update TYPE TABLE FOR UPDATE zi_batch_schedule.
    DATA lt_hit    TYPE tt_hit.

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_p) = ls_key-%param.

      DATA(lv_run_uuid) = resolve_job( iv_jobname  = ls_p-jobname
                                       iv_jobcount = ls_p-jobcount ).
      IF lv_run_uuid IS INITIAL.
        APPEND VALUE #( %cid = ls_key-%cid %fail-cause = if_abap_behv=>cause-not_found )
               TO failed-batchschedule.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( cid = ls_key-%cid run_uuid = lv_run_uuid ) TO lt_hit.

      APPEND VALUE #( runuuid           = lv_run_uuid
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
                      countfrommonthend = ls_p-countfrommonthend
                      useworkingdays    = ls_p-useworkingdays
                      startrestriction  = ls_p-startrestriction )
             TO lt_update.
    ENDLOOP.

    CHECK lt_update IS NOT INITIAL.

    " 실제 재스케줄(취소 + 재생성)은 saver 가 update 를 보고 한다.
    MODIFY ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        UPDATE FIELDS ( startimmediately startdatetime timezone
                        periodminutes periodhours perioddays periodweeks periodmonths
                        enddatetime
                        calendarid monthday useworkingdays countfrommonthend startrestriction )
        WITH lt_update
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    failed-batchschedule   = VALUE #( BASE failed-batchschedule
                                      ( LINES OF CORRESPONDING #( ls_failed-batchschedule ) ) ).
    reported-batchschedule = VALUE #( BASE reported-batchschedule
                                      ( LINES OF CORRESPONDING #( ls_reported-batchschedule ) ) ).

    result = hits_as_result( lt_hit ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 잡 취소 - AS-IS ZBC_BATCH_JOB_DELETE
*   이력 행은 남기고 잡만 끊는다.
*   CancelRequested 를 세워 saver 가 취소임을 알게 한다.
*----------------------------------------------------------------------*
  METHOD canceljob.

    DATA lt_update TYPE TABLE FOR UPDATE zi_batch_schedule.
    DATA lt_hit    TYPE tt_hit.

    LOOP AT keys INTO DATA(ls_key).

      DATA(lv_run_uuid) = resolve_job( iv_jobname  = ls_key-%param-jobname
                                       iv_jobcount = ls_key-%param-jobcount ).
      IF lv_run_uuid IS INITIAL.
        APPEND VALUE #( %cid = ls_key-%cid %fail-cause = if_abap_behv=>cause-not_found )
               TO failed-batchschedule.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( cid = ls_key-%cid run_uuid = lv_run_uuid ) TO lt_hit.
      APPEND VALUE #( runuuid         = lv_run_uuid
                      cancelrequested = abap_true ) TO lt_update.

    ENDLOOP.

    CHECK lt_update IS NOT INITIAL.

    " 실제 CANCEL_JOB 은 saver 가 cancelrequested 를 보고 호출한다.
    MODIFY ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        UPDATE FIELDS ( cancelrequested )
        WITH lt_update
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    failed-batchschedule   = VALUE #( BASE failed-batchschedule
                                      ( LINES OF CORRESPONDING #( ls_failed-batchschedule ) ) ).
    reported-batchschedule = VALUE #( BASE reported-batchschedule
                                      ( LINES OF CORRESPONDING #( ls_reported-batchschedule ) ) ).

    result = hits_as_result( lt_hit ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 상태 조회 - AS-IS ZBC_BATCH_JOB_STATUS
*   GET_JOB_STATUS 는 읽기만 하므로 인터랙션 단계에서 호출해도 된다.
*   덕분에 reported 로 상태를 바로 돌려줄 수 있다.
*----------------------------------------------------------------------*
  METHOD refreshstatus.

    DATA lt_hit TYPE tt_hit.

    DATA(lo_adapter) = NEW zcl_batch_apj_adapter( ).

    LOOP AT keys INTO DATA(ls_key).

      DATA(lv_run_uuid) = resolve_job( iv_jobname  = ls_key-%param-jobname
                                       iv_jobcount = ls_key-%param-jobcount ).
      IF lv_run_uuid IS INITIAL.
        APPEND VALUE #( %cid = ls_key-%cid %fail-cause = if_abap_behv=>cause-not_found )
               TO failed-batchschedule.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( cid = ls_key-%cid run_uuid = lv_run_uuid ) TO lt_hit.

      " GET_JOB_STATUS 는 읽기만 하므로 인터랙션 단계에서 불러도 된다.
      " 덕분에 상태만은 reported 로 바로 돌려줄 수 있다.
      DATA(ls_status) = lo_adapter->get_status( iv_job_name  = ls_key-%param-jobname
                                                iv_job_count = ls_key-%param-jobcount ).

      APPEND VALUE #( %tky-runuuid = lv_run_uuid
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-information
                               text     = |{ ls_key-%param-jobname }/| &&
                                          |{ ls_key-%param-jobcount }: { ls_status-message }| ) )
             TO reported-batchschedule.

    ENDLOOP.

    result = hits_as_result( lt_hit ).

  ENDMETHOD.


  METHOD resolve_job.

    SELECT SINGLE run_uuid
      FROM ztbatch_sched
      WHERE jobname  = @iv_jobname
        AND jobcount = @iv_jobcount
      INTO @rv_run_uuid.

  ENDMETHOD.


  METHOD hits_as_result.

    CHECK it_hit IS NOT INITIAL.

    READ ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        ALL FIELDS WITH VALUE #( FOR ls_hit IN it_hit ( runuuid = ls_hit-run_uuid ) )
      RESULT DATA(lt_row).

    result = VALUE #( FOR ls_hit IN it_hit
                      ( %cid         = ls_hit-cid
                        %tky-runuuid = ls_hit-run_uuid
                        %param       = VALUE #( lt_row[ runuuid = ls_hit-run_uuid ] OPTIONAL ) ) ).

  ENDMETHOD.

ENDCLASS.


*&---------------------------------------------------------------------*
*& Saver - 여기서만 APJ 를 호출한다
*&---------------------------------------------------------------------*
CLASS lsc_zi_batch_schedule DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.

  PRIVATE SECTION.

    "! 요청 행에서 시작 조건만 추려낸다.
    "! TY_START_OPTION 의 컴포넌트명은 ZTBATCH_SCHED 의 컬럼명과 같아서
    "! 이후 CORRESPONDING 한 번으로 행에 실린다.
    METHODS start_option
      IMPORTING is_row           TYPE STRUCTURE FOR CREATE zi_batch_schedule
      RETURNING VALUE(rs_option) TYPE zif_batch_job=>ty_start_option.

    "! 행의 조건대로 스케줄하고 APJ 응답을 같은 행에 적는다.
    "! 실패하면 JOBNAME 이 빈 채로 남고 사유가 MESSAGE 에 적힌다.
    METHODS schedule_row
      CHANGING cs_row TYPE ztbatch_sched.

    "! 걸려 있던 잡을 취소한다. 없으면 아무것도 하지 않는다.
    METHODS cancel_row
      IMPORTING is_row            TYPE ztbatch_sched
      RETURNING VALUE(rv_message) TYPE string.

ENDCLASS.


CLASS lsc_zi_batch_schedule IMPLEMENTATION.

  METHOD save_modified.

*----------------------------------------------------------------------*
* 삭제 - 잡을 끊고 행을 지운다
*   (projection 에서 delete 를 노출하지 않으므로 보통은 비어 있다)
*----------------------------------------------------------------------*
    LOOP AT delete INTO DATA(ls_del).

      SELECT SINGLE * FROM ztbatch_sched
        WHERE run_uuid = @ls_del-runuuid
        INTO @DATA(ls_dead).

      cancel_row( ls_dead ).
      DELETE FROM ztbatch_sched WHERE run_uuid = @ls_del-runuuid.

    ENDLOOP.

*----------------------------------------------------------------------*
* 생성 - scheduleJob
*   스케줄한 뒤 APJ 응답까지 담아 한 번에 INSERT 한다.
*   저장을 우리가 하므로 응답을 넣을 자리가 있다.
*----------------------------------------------------------------------*
    LOOP AT create INTO DATA(ls_new).

      DATA(ls_row) = VALUE ztbatch_sched(
        BASE CORRESPONDING #( start_option( ls_new ) )
        run_uuid              = ls_new-runuuid
        template              = ls_new-jobtemplatename
        jobtext               = ls_new-jobtext
        param                 = ls_new-parameters
        created_by            = cl_abap_context_info=>get_user_technical_name( )
        created_at            = utclong_current( )
        local_last_changed_at = utclong_current( ) ).

      schedule_row( CHANGING cs_row = ls_row ).

      INSERT ztbatch_sched FROM @ls_row.

    ENDLOOP.

*----------------------------------------------------------------------*
* 변경 - cancelJob 이면 취소만, changeJob 이면 취소 + 재스케줄
*   APJ 에 잡 수정 API 가 없어 재스케줄은 취소 + 재생성이며,
*   그 결과 SM37 의 jobname/jobcount 가 바뀐다.
*----------------------------------------------------------------------*
    LOOP AT update INTO DATA(ls_upd).

      " update 요청에는 바뀐 필드만 실려 온다. 나머지는 저장된 행이 갖고 있다.
      SELECT SINGLE * FROM ztbatch_sched
        WHERE run_uuid = @ls_upd-runuuid
        INTO @ls_row.
      CHECK sy-subrc = 0.

      ls_row-message          = cancel_row( ls_row ).
      ls_row-cancel_requested = abap_false.
      CLEAR: ls_row-jobname, ls_row-jobcount.

      " cancelJob 은 여기서 끝. changeJob 은 새 조건으로 다시 건다.
      IF ls_upd-cancelrequested = abap_false.
        ls_row = CORRESPONDING #( BASE ( ls_row )
                                  start_option( CORRESPONDING #( ls_upd ) ) ).
        schedule_row( CHANGING cs_row = ls_row ).
      ENDIF.

      ls_row-local_last_changed_at = utclong_current( ).

      UPDATE ztbatch_sched FROM @ls_row.

    ENDLOOP.

  ENDMETHOD.


  METHOD start_option.

    rs_option = VALUE #( start_immediately = is_row-startimmediately
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
                         count_from_end    = is_row-countfrommonthend
                         use_working_days  = is_row-useworkingdays
                         start_restriction = is_row-startrestriction ).

  ENDMETHOD.


  METHOD schedule_row.

    DATA(ls_sched) = NEW zcl_batch_apj_adapter( )->schedule(
      iv_template = cs_row-template
      iv_jobtext  = cs_row-jobtext
      iv_param    = cs_row-param
      is_start    = CORRESPONDING #( cs_row ) ).

    cs_row-jobname  = ls_sched-job_name.
    cs_row-jobcount = ls_sched-job_count.
    cs_row-message  = ls_sched-message.

  ENDMETHOD.


  METHOD cancel_row.

    CHECK is_row-jobname IS NOT INITIAL.

    rv_message = NEW zcl_batch_apj_adapter( )->cancel(
                   iv_job_name  = is_row-jobname
                   iv_job_count = is_row-jobcount ).

  ENDMETHOD.

ENDCLASS.
