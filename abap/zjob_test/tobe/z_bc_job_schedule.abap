*&---------------------------------------------------------------------*
*& Function Module Z_BC_JOB_SCHEDULE
*&---------------------------------------------------------------------*
*& AS-IS ZBC_BATCH_JOB_CREATE 의 BDC(CALL TRANSACTION 'SM36') 를
*& 표준 FM 3종으로 대체한다.
*&
*&   JOB_OPEN   -> 잡 헤더 생성        (jobname, jobclass)
*&   JOB_SUBMIT -> 스텝 등록 (n회 반복) (pgid, pgvariant, jobuser, pglang)
*&   JOB_CLOSE  -> 시작 조건 + 릴리즈   (시작/close 시각, 주기, 팩토리캘린더)
*&
*& SE37 생성:
*&   Function Group : Z_BC_JOB   (신규, Standard ABAP 언어버전 패키지)
*&   Function Module: Z_BC_JOB_SCHEDULE
*&   Processing Type: Remote-Enabled Module
*&                    (멀티 시스템 대응 - 아래 NOTE 참고)
*&
*&   Import : IS_HEADER TYPE ZIF_BC_JOB=>TY_HEADER
*&            IT_STEPS  TYPE ZIF_BC_JOB=>TT_STEP
*&   Export : ES_RESULT TYPE ZIF_BC_JOB=>TY_RESULT
*&
*& 생성 후 SE37 > Goto > API State 에서 "Use in Cloud Development"(Local API)로
*& release 해야 RAP/Cloud 티어에서 호출할 수 있다.
*&
*& NOTE 1 - 멀티 시스템
*&   IS_HEADER-SYS_ID / CLIENT 는 SAP 잡의 표준 개념이 아니라 AS-IS 인터페이스가
*&   추가한 필드다. "타 시스템에 잡을 건다"는 의미라면 이 FM 자체를
*&   CALL FUNCTION 'Z_BC_JOB_SCHEDULE' DESTINATION <dest> 로 호출해야 하고,
*&   destination 선택은 호출 계층(ZCL_BC_JOB_SCHEDULER)의 책임이다.
*&   자기 시스템 전용이면 SYS_ID/CLIENT 는 검증용으로만 쓰면 된다.
*&
*& NOTE 2 - 타임존
*&   IS_HEADER-TIMEZONE 에 대응하는 JOB_CLOSE 파라미터가 없다.
*&   SDLSTRTDT/SDLSTRTTM 은 시스템 타임존 기준이므로, 호출 전에
*&   사용자 타임존 -> 시스템 타임존으로 변환해서 넣어야 한다. (아래 구현 참고)
*&
*& TODO: 시그니처 확인
*&   JOB_OPEN / JOB_SUBMIT / JOB_CLOSE 의 파라미터명은 SE37 에서 확인 후 맞출 것.
*&---------------------------------------------------------------------*
FUNCTION z_bc_job_schedule.

  DATA: lv_jobcount   TYPE tbtcjob-jobcount,
        lv_released   TYPE btch0000-char1,
        lv_step_no    TYPE tbtcstep-stepcount,
        lv_sdlstrtdt  TYPE tbtcjob-sdlstrtdt,
        lv_sdlstrttm  TYPE tbtcjob-sdlstrttm.

  CLEAR es_result.
  es_result-jobname = is_header-jobname.

*----------------------------------------------------------------------*
* 0) 사전 검증
*----------------------------------------------------------------------*
  IF is_header-jobname IS INITIAL.
    es_result = VALUE #( success = abap_false
                         status  = zif_bc_job=>gc_status-unknown
                         message = 'Job name is required' ).
    RETURN.
  ENDIF.

  IF it_steps IS INITIAL.
    " 스텝 없는 잡은 JOB_CLOSE 에서 JOB_NOSTEPS 로 떨어진다. 미리 막는다.
    es_result = VALUE #( success = abap_false
                         status  = zif_bc_job=>gc_status-unknown
                         message = 'At least one step is required' ).
    RETURN.
  ENDIF.

*----------------------------------------------------------------------*
* 1) JOB_OPEN - 잡 헤더 생성
*    AS-IS BDC 의 SM36 첫 화면(jobname, jobclass)에 해당
*----------------------------------------------------------------------*
  CALL FUNCTION 'JOB_OPEN'
    EXPORTING
      jobname          = is_header-jobname
      jobclass         = is_header-jobclass
      jobgroup         = is_header-jobgroup
    IMPORTING
      jobcount         = lv_jobcount
    EXCEPTIONS
      cant_create_job  = 1
      invalid_job_data = 2
      jobname_missing  = 3
      OTHERS           = 4.

  IF sy-subrc <> 0.
    es_result = VALUE #(
      jobname = is_header-jobname
      success = abap_false
      status  = zif_bc_job=>gc_status-unknown
      message = |JOB_OPEN failed (subrc={ sy-subrc }): { sy-msgid }{ sy-msgno }| ).
    RETURN.
  ENDIF.

  es_result-jobcount = lv_jobcount.

*----------------------------------------------------------------------*
* 2) JOB_SUBMIT - 스텝 등록. 스텝 수만큼 반복.
*    AS-IS 의 lt_pg(ZBCS0012) 각 행 = 스텝 1개
*    ** 여기가 Application Job 으로 못 넘어가는 핵심 지점 **
*       - 임의 리포트(pg_id) 지정
*       - 배리언트(pg_variant)
*       - 스텝별 실행 사용자(jobuser)
*       - 스텝 여러 개
*----------------------------------------------------------------------*
  LOOP AT it_steps INTO DATA(ls_step).

    " 스텝 사용자: 스텝에 지정이 없으면 헤더의 배치유저명을 쓴다
    DATA(lv_authcknam) = COND tbtcstep-authcknam(
      WHEN ls_step-jobuser IS NOT INITIAL THEN ls_step-jobuser
      ELSE is_header-jobuser ).

    CASE ls_step-pg_type.

      WHEN zif_bc_job=>gc_pgtype-abap_program OR space.

        CALL FUNCTION 'JOB_SUBMIT'
          EXPORTING
            authcknam               = lv_authcknam
            jobcount                = lv_jobcount
            jobname                 = is_header-jobname
            language                = ls_step-pg_lang
            report                  = ls_step-pg_id
            variant                 = ls_step-pg_variant
          IMPORTING
            step_number             = lv_step_no
          EXCEPTIONS
            bad_priparams           = 1
            bad_xpgflags            = 2
            invalid_jobdata         = 3
            jobname_missing         = 4
            job_notex               = 5
            job_submit_failed       = 6
            lock_failed             = 7
            program_missing         = 8
            prog_abap_and_extpg_set = 9
            OTHERS                  = 10.

      WHEN OTHERS.
        " TODO: 외부 커맨드(COMMANDNAME) / 외부 프로그램(EXTPGM_NAME) 분기.
        "       AS-IS 가 pg_type='PROG' 만 쓰면 이 분기는 필요 없다.
        sy-subrc = 99.

    ENDCASE.

    IF sy-subrc <> 0.
      " 스텝 등록 실패 - 이미 열린 잡을 정리하고 빠진다
      CALL FUNCTION 'BP_JOB_DELETE'
        EXPORTING
          jobcount               = lv_jobcount
          jobname                = is_header-jobname
        EXCEPTIONS
          cant_delete_event_entry = 1
          cant_delete_job         = 2
          no_delete_authority     = 3
          OTHERS                  = 4.

      es_result = VALUE #(
        jobname  = is_header-jobname
        jobcount = lv_jobcount
        success  = abap_false
        status   = zif_bc_job=>gc_status-unknown
        message  = |JOB_SUBMIT failed at step { sy-tabix } | &&
                   |(report={ ls_step-pg_id } subrc={ sy-subrc })| ).
      RETURN.
    ENDIF.

  ENDLOOP.

*----------------------------------------------------------------------*
* 3) 시작 시각 - 타임존 변환
*    IS_HEADER-TIMEZONE 기준 시각을 시스템 타임존으로 바꿔서 넣는다.
*    (JOB_CLOSE 에 타임존 파라미터가 없기 때문)
*    ** Application Job 은 이 변환을 프레임워크가 해준다 - COMPARISON A4 **
*----------------------------------------------------------------------*
  lv_sdlstrtdt = is_header-sdlstrtdt.
  lv_sdlstrttm = is_header-sdlstrttm.

  IF is_header-timezone IS NOT INITIAL
     AND is_header-sdlstrtdt IS NOT INITIAL.

    DATA: lv_tstamp  TYPE timestamp,
          lv_sys_zone TYPE timezone.

    " SDLSTRTDT/SDLSTRTTM 은 **시스템 타임존** 기준으로 해석된다.
    " sy-zonlo 는 사용자 타임존이라 여기 쓰면 안 된다.
    " TODO: 시그니처 확인 - GET_SYSTEM_TIMEZONE 의 파라미터명
    CALL FUNCTION 'GET_SYSTEM_TIMEZONE'
      IMPORTING
        timezone            = lv_sys_zone
      EXCEPTIONS
        customizing_missing = 1
        OTHERS              = 2.

    IF sy-subrc <> 0.
      lv_sys_zone = sy-zonlo.   " 폴백
    ENDIF.

    " 요청 타임존의 로컬 시각 -> UTC
    CONVERT DATE is_header-sdlstrtdt TIME is_header-sdlstrttm
            INTO TIME STAMP lv_tstamp TIME ZONE is_header-timezone.

    " UTC -> 시스템 타임존
    CONVERT TIME STAMP lv_tstamp TIME ZONE lv_sys_zone
            INTO DATE lv_sdlstrtdt TIME lv_sdlstrttm.

  ENDIF.

*----------------------------------------------------------------------*
* 4) JOB_CLOSE - 시작 조건 지정 + 릴리즈
*    AS-IS BDC 의 "배치잡 주기" 화면에 해당
*----------------------------------------------------------------------*
  CALL FUNCTION 'JOB_CLOSE'
    EXPORTING
      jobcount                    = lv_jobcount
      jobname                     = is_header-jobname

      "--- 즉시 / 예약
      strtimmed                   = is_header-start_immed
      sdlstrtdt                   = lv_sdlstrtdt
      sdlstrttm                   = lv_sdlstrttm

      "--- close 시각 (이 시각 넘으면 실행 안 함) - COMPARISON #19
      laststrtdt                  = is_header-laststrtdt
      laststrttm                  = is_header-laststrttm

      "--- 반복 주기. 하나만 채워져 있어야 한다.
      prdmins                     = is_header-prd_mins
      prdhours                    = is_header-prd_hours
      prddays                     = is_header-prd_days
      prdweeks                    = is_header-prd_weeks
      prdmonths                   = is_header-prd_months

      "--- 팩토리 캘린더 기준 작업일 실행 - COMPARISON #12
      calendar_id                 = is_header-calendar_id
      start_on_workday_nr         = is_header-workday_nr
      start_on_workday_not_before = is_header-workday_time
      workday_count_direction     = is_header-workday_dir

    IMPORTING
      job_was_released            = lv_released

    EXCEPTIONS
      cant_start_immediate        = 1
      invalid_startdate           = 2
      jobname_missing             = 3
      job_close_failed            = 4
      job_nosteps                 = 5
      job_notex                   = 6
      lock_failed                 = 7
      invalid_target              = 8
      OTHERS                      = 9.

  IF sy-subrc <> 0.
    CALL FUNCTION 'BP_JOB_DELETE'
      EXPORTING
        jobcount                = lv_jobcount
        jobname                 = is_header-jobname
      EXCEPTIONS
        OTHERS                  = 4.

    es_result = VALUE #(
      jobname  = is_header-jobname
      jobcount = lv_jobcount
      success  = abap_false
      status   = zif_bc_job=>gc_status-unknown
      message  = |JOB_CLOSE failed (subrc={ sy-subrc })| ).
    RETURN.
  ENDIF.

  es_result = VALUE #(
    jobname  = is_header-jobname
    jobcount = lv_jobcount
    success  = abap_true
    status   = COND #( WHEN lv_released = 'X' THEN zif_bc_job=>gc_status-released
                       ELSE zif_bc_job=>gc_status-scheduled )
    message  = |Job { is_header-jobname }/{ lv_jobcount } | &&
               |{ COND string( WHEN lv_released = 'X' THEN 'released' ELSE 'scheduled' ) } | &&
               |with { lines( it_steps ) } step(s)| ).

ENDFUNCTION.
