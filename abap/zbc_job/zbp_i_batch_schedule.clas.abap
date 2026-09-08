"! <p class="shorttext synchronized">ZI_BATCH_SCHEDULE Behavior Implementation</p>
"!
"! 이 BO 의 엔티티는 "스케줄 이력" 이다. 조회가 목적이고,
"! APJ 잡에 대한 조작은 CRUD 가 아니라 명령이므로 액션으로 노출한다.
"!
"!   ZBC_BATCH_JOB_CREATE -> scheduleJob
"!   ZBC_BATCH_JOB_CHANGE -> changeJob
"!   ZBC_BATCH_JOB_DELETE -> cancelJob      (잡만 끊고 이력은 남긴다)
"!
"! ** APJ 잡 1개 = 이 테이블의 행 1개 **
"!   잡이 끝나면 행을 고치지 않고 ENDED_AT 만 찍는다. JOBNAME 을 지우면
"!   그 잡이 남긴 SM37 로그를 다시 찾을 수 없기 때문이다.
"!   changeJob 은 재스케줄이 취소 + 재생성이라 잡이 바뀌므로, 옛 행을 닫고
"!   새 행을 만든다. 응답은 새 행이다 - 새 JOBNAME 이 거기 있다.
"!   ZBC_BATCH_JOB_STATUS -> refreshStatus
"!
"! ** APJ 호출은 자식 세션에서 한다 **
"!   CL_APJ_RT_API=>CANCEL_JOB 이 내부에서 COMMIT CONNECTION 을 하는데,
"!   RAP 은 BO 가 활성인 동안 커밋을 금지한다. 액션 핸들러가 도는 중에도
"!   BO 는 활성이라 여기서도 못 부른다.
"!
"!   그래서 APJ 호출만 ZCL_BATCH_APJ_TASK 에 담아 CL_ABAP_PARALLEL 로
"!   자식 세션에 넘기고 결과를 기다린다. 자식은 자기 LUW 라 커밋이 합법이다.
"!
"!   결과가 인터랙션 단계에서 손에 들어오므로 그냥 엔티티에 써 두면 된다.
"!   저장은 평범한 managed 이고 saver 가 없다. 액션 응답에 JOBNAME 도
"!   실린다 - AS-IS RFC 와 같은 모양이다.
"!
"! ** 액션 4개가 전부 정적 액션이다 **
"!   외부 호출자는 RunUuid 를 모른다. AS-IS 인터페이스가 jobid/jobcount 로
"!   잡을 지목하고 호출하는 쪽이 그 둘을 자기 DB 에 들고 있기 때문이다.
"!   그래서 잡 이름을 파라미터로 받아 이력 행을 찾는다.
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
*   자식 세션에서 SCHEDULE_JOB 을 부르고, 받은 jobname 까지 담아 CREATE 한다.
*----------------------------------------------------------------------*
  METHOD schedulejob.

    DATA lt_task TYPE cl_abap_parallel=>t_in_inst.

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_p) = ls_key-%param.

      APPEND NEW zcl_batch_apj_task(
        iv_mode     = zcl_batch_apj_task=>gc_mode-schedule
        iv_cid      = ls_key-%cid
        iv_template = ls_p-jobtemplatename
        iv_jobtext  = ls_p-jobtext
        iv_param    = ls_p-parameters
        is_start    = VALUE #( start_immediately = ls_p-startimmediately
                               start_datetime    = ls_p-startdatetime
                               timezone          = ls_p-timezone
                               prd_mins          = ls_p-periodminutes
                               prd_hours         = ls_p-periodhours
                               prd_days          = ls_p-perioddays
                               prd_weeks         = ls_p-periodweeks
                               prd_months        = ls_p-periodmonths
                               end_datetime      = ls_p-enddatetime
                               calendar_id       = ls_p-calendarid
                               month_day         = ls_p-monthday
                               use_working_days  = ls_p-useworkingdays
                               count_from_end    = ls_p-countfrommonthend
                               start_restriction = ls_p-startrestriction ) )
             TO lt_task.
    ENDLOOP.

    CHECK lt_task IS NOT INITIAL.

    " TODO: 시그니처 확인 - RUN_INST 의 파라미터명과 T_OUT_INST 의 컴포넌트
    NEW cl_abap_parallel( )->run_inst( EXPORTING p_in_tab  = lt_task
                                       IMPORTING p_out_tab = DATA(lt_done) ).

    DATA lt_create TYPE TABLE FOR CREATE zi_batch_schedule.

    LOOP AT keys INTO ls_key.
      ls_p = ls_key-%param.

      " 결과는 인스턴스에 실려 돌아온다. CID 로 짝지어 순서에 기대지 않는다.
      LOOP AT lt_done INTO DATA(ls_done).
        DATA(lo_task) = CAST zcl_batch_apj_task( ls_done-inst ).
        IF lo_task->cid = ls_key-%cid.
          EXIT.
        ENDIF.
        CLEAR lo_task.
      ENDLOOP.
      CHECK lo_task IS BOUND.

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
                      startrestriction  = ls_p-startrestriction
                      jobname           = lo_task->job_name
                      jobcount          = lo_task->job_count
                      message           = CONV #( lo_task->message ) )
             TO lt_create.
    ENDLOOP.

    MODIFY ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        CREATE FIELDS ( jobtemplatename jobtext parameters
                        startimmediately startdatetime timezone
                        periodminutes periodhours perioddays periodweeks periodmonths
                        enddatetime
                        calendarid monthday useworkingdays countfrommonthend startrestriction
                        jobname jobcount message )
        WITH lt_create
      MAPPED   DATA(ls_mapped)
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    failed-batchschedule   = VALUE #( BASE failed-batchschedule
                                      ( LINES OF CORRESPONDING #( ls_failed-batchschedule ) ) ).
    reported-batchschedule = VALUE #( BASE reported-batchschedule
                                      ( LINES OF CORRESPONDING #( ls_reported-batchschedule ) ) ).

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
*   APJ 에 잡 수정 API 가 없어 취소 + 재생성이다. 한 작업에 담아 자식
*   세션에서 이어서 돌리므로 왕복이 한 번이다.
*   그 결과 SM37 의 jobname/jobcount 가 바뀐다.
*----------------------------------------------------------------------*
  METHOD changejob.

    DATA lt_task TYPE cl_abap_parallel=>t_in_inst.

    LOOP AT keys INTO DATA(ls_key).
      DATA(ls_p) = ls_key-%param.

      " 외부 호출자는 RunUuid 를 모르고 SM37 잡 이름을 들고 있다.
      " ENDED_AT 이 빈 행만 살아 있는 잡이다.
      " 무엇을 돌릴지(템플릿/텍스트/파라미터)는 요청에 없고 행이 갖고 있다.
      SELECT SINGLE run_uuid, template, jobtext, param, jobname, jobcount
        FROM ztbatch_sched
        WHERE jobname  = @ls_p-jobname
          AND jobcount = @ls_p-jobcount
          AND ended_at IS INITIAL
        INTO @DATA(ls_old).

      IF sy-subrc <> 0.
        APPEND VALUE #( %cid = ls_key-%cid %fail-cause = if_abap_behv=>cause-not_found )
               TO failed-batchschedule.
        CONTINUE.
      ENDIF.

      APPEND NEW zcl_batch_apj_task(
        iv_mode      = zcl_batch_apj_task=>gc_mode-change
        iv_run_uuid  = ls_old-run_uuid
        iv_cid       = ls_key-%cid
        iv_old_name  = ls_old-jobname
        iv_old_count = ls_old-jobcount
        iv_template  = ls_old-template
        iv_jobtext   = ls_old-jobtext
        iv_param     = ls_old-param
        is_start     = VALUE #( start_immediately = ls_p-startimmediately
                                start_datetime    = ls_p-startdatetime
                                timezone          = ls_p-timezone
                                prd_mins          = ls_p-periodminutes
                                prd_hours         = ls_p-periodhours
                                prd_days          = ls_p-perioddays
                                prd_weeks         = ls_p-periodweeks
                                prd_months        = ls_p-periodmonths
                                end_datetime      = ls_p-enddatetime
                                calendar_id       = ls_p-calendarid
                                month_day         = ls_p-monthday
                                use_working_days  = ls_p-useworkingdays
                                count_from_end    = ls_p-countfrommonthend
                                start_restriction = ls_p-startrestriction ) )
             TO lt_task.
    ENDLOOP.

    CHECK lt_task IS NOT INITIAL.

    NEW cl_abap_parallel( )->run_inst( EXPORTING p_in_tab  = lt_task
                                       IMPORTING p_out_tab = DATA(lt_done) ).

    DATA lt_close TYPE TABLE FOR UPDATE zi_batch_schedule.
    DATA lt_new   TYPE TABLE FOR CREATE zi_batch_schedule.

    LOOP AT keys INTO ls_key.
      ls_p = ls_key-%param.

      LOOP AT lt_done INTO DATA(ls_done).
        DATA(lo_task) = CAST zcl_batch_apj_task( ls_done-inst ).
        IF lo_task->cid = ls_key-%cid.
          EXIT.
        ENDIF.
        CLEAR lo_task.
      ENDLOOP.
      CHECK lo_task IS BOUND.

      " 옛 행은 고치지 않고 닫는다. JOBNAME 이 남아 있어야 그 잡의
      " SM37 로그를 나중에 찾을 수 있다.
      APPEND VALUE #( runuuid = lo_task->run_uuid
                      endedat = utclong_current( )
                      message = |Replaced by { lo_task->job_name }/{ lo_task->job_count }| )
             TO lt_close.

      " 새 잡은 새 행이다. 무엇을 돌릴지는 옛 행에서 그대로 가져온다.
      APPEND VALUE #( %cid              = ls_key-%cid
                      jobtemplatename   = lo_task->template
                      jobtext           = lo_task->jobtext
                      parameters        = lo_task->param
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
                      startrestriction  = ls_p-startrestriction
                      jobname           = lo_task->job_name
                      jobcount          = lo_task->job_count
                      message           = CONV #( lo_task->message ) )
             TO lt_new.
    ENDLOOP.

    MODIFY ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        UPDATE FIELDS ( endedat message ) WITH lt_close
      ENTITY batchschedule
        CREATE FIELDS ( jobtemplatename jobtext parameters
                        startimmediately startdatetime timezone
                        periodminutes periodhours perioddays periodweeks periodmonths
                        enddatetime
                        calendarid monthday useworkingdays countfrommonthend startrestriction
                        jobname jobcount message )
        WITH lt_new
      MAPPED   DATA(ls_mapped)
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    failed-batchschedule   = VALUE #( BASE failed-batchschedule
                                      ( LINES OF CORRESPONDING #( ls_failed-batchschedule ) ) ).
    reported-batchschedule = VALUE #( BASE reported-batchschedule
                                      ( LINES OF CORRESPONDING #( ls_reported-batchschedule ) ) ).

    " 응답은 새 행이다. 호출자는 여기서 새 JobName 을 받는다 -
    " 재스케줄로 SM37 이름이 바뀌기 때문이다.
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
* 잡 취소 - AS-IS ZBC_BATCH_JOB_DELETE
*   잡만 끊고 이력 행은 남긴다. 포인터를 비우면 IsScheduled 가 내려간다.
*----------------------------------------------------------------------*
  METHOD canceljob.

    DATA lt_task TYPE cl_abap_parallel=>t_in_inst.

    LOOP AT keys INTO DATA(ls_key).

      SELECT SINGLE run_uuid, jobname, jobcount
        FROM ztbatch_sched
        WHERE jobname  = @ls_key-%param-jobname
          AND jobcount = @ls_key-%param-jobcount
          AND ended_at IS INITIAL
        INTO @DATA(ls_old).

      IF sy-subrc <> 0.
        APPEND VALUE #( %cid = ls_key-%cid %fail-cause = if_abap_behv=>cause-not_found )
               TO failed-batchschedule.
        CONTINUE.
      ENDIF.

      APPEND NEW zcl_batch_apj_task(
        iv_mode      = zcl_batch_apj_task=>gc_mode-cancel
        iv_run_uuid  = ls_old-run_uuid
        iv_cid       = ls_key-%cid
        iv_old_name  = ls_old-jobname
        iv_old_count = ls_old-jobcount )
             TO lt_task.

    ENDLOOP.

    CHECK lt_task IS NOT INITIAL.

    NEW cl_abap_parallel( )->run_inst( EXPORTING p_in_tab  = lt_task
                                       IMPORTING p_out_tab = DATA(lt_done) ).

    DATA lt_close TYPE TABLE FOR UPDATE zi_batch_schedule.

    LOOP AT lt_done INTO DATA(ls_done).
      DATA(lo_task) = CAST zcl_batch_apj_task( ls_done-inst ).

      " 종료 시각만 찍는다. JOBNAME 은 지우지 않는다 - 그게 없으면
      " 이 잡이 남긴 SM37 로그를 다시 찾을 수 없다.
      APPEND VALUE #( runuuid = lo_task->run_uuid
                      endedat = utclong_current( )
                      message = CONV #( lo_task->message ) )
             TO lt_close.
    ENDLOOP.

    MODIFY ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        UPDATE FIELDS ( endedat message )
        WITH lt_close
      FAILED   DATA(ls_failed)
      REPORTED DATA(ls_reported).

    failed-batchschedule   = VALUE #( BASE failed-batchschedule
                                      ( LINES OF CORRESPONDING #( ls_failed-batchschedule ) ) ).
    reported-batchschedule = VALUE #( BASE reported-batchschedule
                                      ( LINES OF CORRESPONDING #( ls_reported-batchschedule ) ) ).

    READ ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        ALL FIELDS WITH CORRESPONDING #( lt_close )
      RESULT DATA(lt_row).

    result = VALUE #( FOR ls_close IN lt_close
                      ( %tky-runuuid = ls_close-runuuid
                        %param       = VALUE #( lt_row[ runuuid = ls_close-runuuid ] OPTIONAL ) ) ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 상태 조회 - AS-IS ZBC_BATCH_JOB_STATUS
*   여기만 ENDED_AT 을 안 본다. 이미 끝난 잡의 상태도 조회할 수 있어야 한다.
*   GET_JOB_STATUS 는 읽기만 하고 커밋하지 않으므로 여기서 직접 부른다.
*   자식 세션이 필요 없다.
*----------------------------------------------------------------------*
  METHOD refreshstatus.

    DATA lt_key TYPE TABLE FOR READ IMPORT zi_batch_schedule.

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

      APPEND VALUE #( runuuid = lv_run_uuid ) TO lt_key.

      DATA(ls_status) = lo_adapter->get_status( iv_job_name  = ls_key-%param-jobname
                                                iv_job_count = ls_key-%param-jobcount ).

      APPEND VALUE #( %tky-runuuid = lv_run_uuid
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-information
                               text     = |{ ls_key-%param-jobname }/| &&
                                          |{ ls_key-%param-jobcount }: { ls_status-message }| ) )
             TO reported-batchschedule.

    ENDLOOP.

    CHECK lt_key IS NOT INITIAL.

    READ ENTITIES OF zi_batch_schedule IN LOCAL MODE
      ENTITY batchschedule
        ALL FIELDS WITH CORRESPONDING #( lt_key )
      RESULT DATA(lt_row).

    result = VALUE #( FOR ls_k IN lt_key
                      ( %tky-runuuid = ls_k-runuuid
                        %param       = VALUE #( lt_row[ runuuid = ls_k-runuuid ] OPTIONAL ) ) ).

  ENDMETHOD.

ENDCLASS.
