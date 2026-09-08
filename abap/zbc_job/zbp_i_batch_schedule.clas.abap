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
"!   그래서 잡 이름을 파라미터로 받아 이력 행을 찾는다.
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
"!
"! ** 헬퍼 메서드를 두지 않는다 **
"!   액션 하나가 무슨 일을 하는지 그 메서드 안에서 다 읽히도록 한다.
"!   조회 SELECT 가 액션마다 반복되지만 그 편이 낫다.
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

    failed-batchschedule   = VALUE #( BASE failed-batchschedule
                                      ( LINES OF CORRESPONDING #( ls_failed-batchschedule ) ) ).
    reported-batchschedule = VALUE #( BASE reported-batchschedule
                                      ( LINES OF CORRESPONDING #( ls_reported-batchschedule ) ) ).
    mapped-batchschedule   = CORRESPONDING #( ls_mapped-batchschedule ).

    " 호출자에게 RunUuid 를 돌려준다. JobName 은 save 단계에 가서야 정해지므로
    " 아직 비어 있다 - 스케줄 결과는 행을 GET 해서 본다.
    READ ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        ALL FIELDS WITH CORRESPONDING #( ls_mapped-batchschedule )
      RESULT DATA(lt_row).

    result = VALUE #( FOR ls_map IN ls_mapped-batchschedule
                      ( %cid         = ls_map-%cid
                        %tky-runuuid = ls_map-runuuid
                        %param       = VALUE #( lt_row[ runuuid = ls_map-runuuid ] OPTIONAL ) ) ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 스케줄 변경 - AS-IS ZBC_BATCH_JOB_CHANGE
*   새 시작 조건만 쓴다. saver 가 update 를 보고 취소 + 재스케줄한다.
*----------------------------------------------------------------------*
  METHOD changejob.

    TYPES: BEGIN OF ty_hit,
             cid      TYPE abp_behv_cid,
             run_uuid TYPE ztbatch_sched-run_uuid,
           END OF ty_hit.

    DATA lt_hit    TYPE STANDARD TABLE OF ty_hit WITH EMPTY KEY.
    DATA lt_update TYPE TABLE FOR UPDATE zi_batch_schedule.

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_p) = ls_key-%param.

      " 외부 호출자는 RunUuid 를 모르고 SM37 잡 이름을 들고 있다.
      " 취소된 행은 jobname 이 비어 있어 jobname + jobcount 가 유일하다.
      SELECT SINGLE run_uuid
        FROM ztbatch_sched
        WHERE jobname  = @ls_p-jobname
          AND jobcount = @ls_p-jobcount
        INTO @DATA(lv_run_uuid).

      IF sy-subrc <> 0.
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

    READ ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        ALL FIELDS WITH VALUE #( FOR ls_hit IN lt_hit ( runuuid = ls_hit-run_uuid ) )
      RESULT DATA(lt_row).

    result = VALUE #( FOR ls_hit IN lt_hit
                      ( %cid         = ls_hit-cid
                        %tky-runuuid = ls_hit-run_uuid
                        %param       = VALUE #( lt_row[ runuuid = ls_hit-run_uuid ] OPTIONAL ) ) ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 잡 취소 - AS-IS ZBC_BATCH_JOB_DELETE
*   잡만 끊고 이력 행은 남긴다. 실제 CANCEL_JOB 은 saver 가 한다.
*----------------------------------------------------------------------*
  METHOD canceljob.

    TYPES: BEGIN OF ty_hit,
             cid      TYPE abp_behv_cid,
             run_uuid TYPE ztbatch_sched-run_uuid,
           END OF ty_hit.

    DATA lt_hit    TYPE STANDARD TABLE OF ty_hit WITH EMPTY KEY.
    DATA lt_update TYPE TABLE FOR UPDATE zi_batch_schedule.

    LOOP AT keys INTO DATA(ls_key).

      SELECT SINGLE run_uuid
        FROM ztbatch_sched
        WHERE jobname  = @ls_key-%param-jobname
          AND jobcount = @ls_key-%param-jobcount
        INTO @DATA(lv_run_uuid).

      IF sy-subrc <> 0.
        APPEND VALUE #( %cid = ls_key-%cid %fail-cause = if_abap_behv=>cause-not_found )
               TO failed-batchschedule.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( cid = ls_key-%cid run_uuid = lv_run_uuid ) TO lt_hit.
      APPEND VALUE #( runuuid         = lv_run_uuid
                      cancelrequested = abap_true ) TO lt_update.

    ENDLOOP.

    CHECK lt_update IS NOT INITIAL.

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

    READ ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        ALL FIELDS WITH VALUE #( FOR ls_hit IN lt_hit ( runuuid = ls_hit-run_uuid ) )
      RESULT DATA(lt_row).

    result = VALUE #( FOR ls_hit IN lt_hit
                      ( %cid         = ls_hit-cid
                        %tky-runuuid = ls_hit-run_uuid
                        %param       = VALUE #( lt_row[ runuuid = ls_hit-run_uuid ] OPTIONAL ) ) ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 상태 조회 - AS-IS ZBC_BATCH_JOB_STATUS
*   GET_JOB_STATUS 는 읽기만 하므로 인터랙션 단계에서 불러도 된다.
*   덕분에 상태만은 reported 로 바로 돌려줄 수 있다.
*----------------------------------------------------------------------*
  METHOD refreshstatus.

    TYPES: BEGIN OF ty_hit,
             cid      TYPE abp_behv_cid,
             run_uuid TYPE ztbatch_sched-run_uuid,
           END OF ty_hit.

    DATA lt_hit TYPE STANDARD TABLE OF ty_hit WITH EMPTY KEY.

    DATA(lo_adapter) = NEW zcl_batch_apj_adapter( ).

    LOOP AT keys INTO DATA(ls_key).

      SELECT SINGLE run_uuid
        FROM ztbatch_sched
        WHERE jobname  = @ls_key-%param-jobname
          AND jobcount = @ls_key-%param-jobcount
        INTO @DATA(lv_run_uuid).

      IF sy-subrc <> 0.
        APPEND VALUE #( %cid = ls_key-%cid %fail-cause = if_abap_behv=>cause-not_found )
               TO failed-batchschedule.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( cid = ls_key-%cid run_uuid = lv_run_uuid ) TO lt_hit.

      DATA(ls_status) = lo_adapter->get_status( iv_job_name  = ls_key-%param-jobname
                                                iv_job_count = ls_key-%param-jobcount ).

      APPEND VALUE #( %tky-runuuid = lv_run_uuid
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-information
                               text     = |{ ls_key-%param-jobname }/| &&
                                          |{ ls_key-%param-jobcount }: { ls_status-message }| ) )
             TO reported-batchschedule.

    ENDLOOP.

    CHECK lt_hit IS NOT INITIAL.

    READ ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        ALL FIELDS WITH VALUE #( FOR ls_hit IN lt_hit ( runuuid = ls_hit-run_uuid ) )
      RESULT DATA(lt_row).

    result = VALUE #( FOR ls_hit IN lt_hit
                      ( %cid         = ls_hit-cid
                        %tky-runuuid = ls_hit-run_uuid
                        %param       = VALUE #( lt_row[ runuuid = ls_hit-run_uuid ] OPTIONAL ) ) ).

  ENDMETHOD.

ENDCLASS.


*&---------------------------------------------------------------------*
*& save 단계 - APJ 를 호출하고 테이블을 직접 쓴다
*&
*& unmanaged save 라 이 클래스가 유일한 writer 다. 그래서 APJ 응답을
*& 처음부터 행에 담아 INSERT 할 수 있다.
*&---------------------------------------------------------------------*
CLASS lsc_zi_batch_schedule DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.

ENDCLASS.


CLASS lsc_zi_batch_schedule IMPLEMENTATION.

  METHOD save_modified.

    DATA(lo_adapter) = NEW zcl_batch_apj_adapter( ).

*----------------------------------------------------------------------*
* 삭제 - 걸려 있던 잡을 끊고 행을 지운다
*   (projection 에서 delete 를 노출하지 않으므로 보통은 비어 있다)
*----------------------------------------------------------------------*
    LOOP AT delete INTO DATA(ls_del).

      SELECT SINGLE jobname, jobcount
        FROM ztbatch_sched
        WHERE run_uuid = @ls_del-runuuid
        INTO @DATA(ls_old).

      IF ls_old-jobname IS NOT INITIAL.
        DATA(lo_del_cancel) = cl_bgmc_process_factory=>get_default( )->create( ).
        lo_del_cancel->set_operation_tx_uncontrolled(
          NEW zcl_batch_cancel_op( iv_run_uuid  = ls_del-runuuid
                                   iv_job_name  = ls_old-jobname
                                   iv_job_count = ls_old-jobcount ) ).
        lo_del_cancel->save_for_execution( ).
      ENDIF.

      DELETE FROM ztbatch_sched WHERE run_uuid = @ls_del-runuuid.

    ENDLOOP.

*----------------------------------------------------------------------*
* 생성 - scheduleJob
*   스케줄한 뒤 APJ 응답까지 담아 한 번에 INSERT 한다.
*----------------------------------------------------------------------*
    LOOP AT create INTO DATA(ls_new).

      DATA(ls_row) = VALUE ztbatch_sched(
        run_uuid              = ls_new-runuuid
        template              = ls_new-jobtemplatename
        jobtext               = ls_new-jobtext
        param                 = ls_new-parameters
        start_immediately     = ls_new-startimmediately
        start_datetime        = ls_new-startdatetime
        timezone              = ls_new-timezone
        prd_mins              = ls_new-periodminutes
        prd_hours             = ls_new-periodhours
        prd_days              = ls_new-perioddays
        prd_weeks             = ls_new-periodweeks
        prd_months            = ls_new-periodmonths
        end_datetime          = ls_new-enddatetime
        calendar_id           = ls_new-calendarid
        month_day             = ls_new-monthday
        use_working_days      = ls_new-useworkingdays
        count_from_end        = ls_new-countfrommonthend
        start_restriction     = ls_new-startrestriction
        created_by            = cl_abap_context_info=>get_user_technical_name( )
        created_at            = utclong_current( )
        local_last_changed_at = utclong_current( ) ).

      " 실패하면 jobname 이 빈 채로 남고 사유가 message 에 적힌다.
      " save 단계라 reported 로 메시지를 돌려줄 수 없기 때문이다.
      DATA(ls_sched) = lo_adapter->schedule( iv_template = ls_row-template
                                             iv_jobtext  = ls_row-jobtext
                                             iv_param    = ls_row-param
                                             is_start    = CORRESPONDING #( ls_row ) ).
      ls_row-jobname  = ls_sched-job_name.
      ls_row-jobcount = ls_sched-job_count.
      ls_row-message  = ls_sched-message.

      INSERT ztbatch_sched FROM @ls_row.

    ENDLOOP.

*----------------------------------------------------------------------*
* 변경 - cancelJob 이면 취소만, changeJob 이면 취소 + 재스케줄
*   APJ 에 잡 수정 API 가 없어 재스케줄은 취소 + 재생성이며,
*   그 결과 SM37 의 jobname/jobcount 가 바뀐다.
*----------------------------------------------------------------------*
    LOOP AT update INTO DATA(ls_upd).

      " update 요청에는 바뀐 필드만 실려 온다.
      " 무엇을 돌릴지(템플릿/텍스트/파라미터)와 걸려 있는 잡은 행이 갖고 있다.
      SELECT SINGLE template, jobtext, param, jobname, jobcount
        FROM ztbatch_sched
        WHERE run_uuid = @ls_upd-runuuid
        INTO @DATA(ls_old).
      CHECK sy-subrc = 0.

*     취소는 RAP 트랜잭션이 닫힌 뒤에 돌려야 한다.
*     CANCEL_JOB 이 COMMIT CONNECTION 을 하는데 BO 활성 중에는 금지다.
*     여기서는 큐에 넣기만 한다 - SAVE_FOR_EXECUTION 은 커밋하지 않는다.
      IF ls_old-jobname IS NOT INITIAL.
        DATA(lo_upd_cancel) = cl_bgmc_process_factory=>get_default( )->create( ).
        lo_upd_cancel->set_operation_tx_uncontrolled(
          NEW zcl_batch_cancel_op( iv_run_uuid  = ls_upd-runuuid
                                   iv_job_name  = ls_old-jobname
                                   iv_job_count = ls_old-jobcount ) ).
        lo_upd_cancel->save_for_execution( ).
      ENDIF.

*     cancelJob - 잡만 끊는다. 포인터를 비우고 요청 플래그를 내린다.
*     바꾸는 컬럼만 SET 한다. 전체 행을 쓰면 읽기가 한 번 어긋날 때
*     이력이 통째로 공백이 된다.
      IF ls_upd-cancelrequested = abap_true.

        UPDATE ztbatch_sched
          SET jobname               = @( VALUE ztbatch_sched-jobname( ) ),
              jobcount              = @( VALUE ztbatch_sched-jobcount( ) ),
              cancel_requested      = @abap_false,
              message               = @( CONV ztbatch_sched-message( |Cancel requested| ) ),
              local_last_changed_at = @( utclong_current( ) )
          WHERE run_uuid = @ls_upd-runuuid.

        CONTINUE.
      ENDIF.

*     changeJob - 새 조건으로 다시 건다.
*     APJ 에 잡 수정 API 가 없어 취소 + 재생성이며, 그 결과
*     SM37 의 jobname/jobcount 가 바뀐다.
      ls_sched = lo_adapter->schedule(
        iv_template = ls_old-template
        iv_jobtext  = ls_old-jobtext
        iv_param    = ls_old-param
        is_start    = VALUE #( start_immediately = ls_upd-startimmediately
                               start_datetime    = ls_upd-startdatetime
                               timezone          = ls_upd-timezone
                               prd_mins          = ls_upd-periodminutes
                               prd_hours         = ls_upd-periodhours
                               prd_days          = ls_upd-perioddays
                               prd_weeks         = ls_upd-periodweeks
                               prd_months        = ls_upd-periodmonths
                               end_datetime      = ls_upd-enddatetime
                               calendar_id       = ls_upd-calendarid
                               month_day         = ls_upd-monthday
                               use_working_days  = ls_upd-useworkingdays
                               count_from_end    = ls_upd-countfrommonthend
                               start_restriction = ls_upd-startrestriction ) ).

      UPDATE ztbatch_sched
        SET start_immediately     = @ls_upd-startimmediately,
            start_datetime        = @ls_upd-startdatetime,
            timezone              = @ls_upd-timezone,
            prd_mins              = @ls_upd-periodminutes,
            prd_hours             = @ls_upd-periodhours,
            prd_days              = @ls_upd-perioddays,
            prd_weeks             = @ls_upd-periodweeks,
            prd_months            = @ls_upd-periodmonths,
            end_datetime          = @ls_upd-enddatetime,
            calendar_id           = @ls_upd-calendarid,
            month_day             = @ls_upd-monthday,
            use_working_days      = @ls_upd-useworkingdays,
            count_from_end        = @ls_upd-countfrommonthend,
            start_restriction     = @ls_upd-startrestriction,
            jobname               = @ls_sched-job_name,
            jobcount              = @ls_sched-job_count,
            message               = @( CONV ztbatch_sched-message( ls_sched-message ) ),
            cancel_requested      = @abap_false,
            local_last_changed_at = @( utclong_current( ) )
        WHERE run_uuid = @ls_upd-runuuid.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
