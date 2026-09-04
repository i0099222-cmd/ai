*&---------------------------------------------------------------------*
*& Report ZR_JOB_TEST
*&---------------------------------------------------------------------*
*& SM36/SM37 비교용 클래식 배치 리포트.
*&
*& 언어버전: Standard ABAP (Standard ABAP 패키지에 생성)
*&   - WRITE(스풀 리스트), 배리언트, sy-batch/sy-host 는 ABAP Cloud 언어버전에서
*&     금지되므로 이 리포트는 반드시 Standard ABAP 티어에 둔다.
*&   - 업무 로직은 ZCL_JOB_TEST_CORE(Cloud 언어버전)를 그대로 호출한다.
*&     Standard ABAP -> ABAP Cloud 방향 호출은 허용된다.
*&
*& 이 리포트로만 확인 가능한 것 (Application Job 에는 대응이 없음):
*&   - SE38 배리언트 저장 -> SM36 스텝에 배리언트 지정
*&   - WRITE 스풀 리스트 -> SM37 > Spool
*&   - SM36 다중 스텝 / 이벤트 시작 / 선행 잡 후 시작 / 대상 서버 / 잡 클래스
*&   - sy-batch, sy-host 로 실행 환경 직접 확인
*&---------------------------------------------------------------------*
REPORT zr_job_test.

SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-b01.
  PARAMETERS: p_tag   TYPE c LENGTH 20 OBLIGATORY DEFAULT 'SM36-DEFAULT',
              p_count TYPE i DEFAULT 3,
              p_sleep TYPE i DEFAULT 0,
              p_fail  AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK b1.

*----------------------------------------------------------------------*
START-OF-SELECTION.

  DATA(ls_params) = VALUE zif_job_test=>ty_run_params(
    run_tag    = p_tag
    rec_count  = p_count
    sleep_secs = p_sleep
    force_fail = p_fail ).

  " Cloud 티어에서는 못 읽는 값들을 여기서 채워 넘긴다.
  " -> ZTJOB_PROBE 에서 schedule_mode='C' 행에만 host/is_batch 가 차 있고
  "    'A' 행은 비어 있는 것이 그대로 비교 결과가 된다.
  DATA(ls_context) = VALUE zif_job_test=>ty_context(
    schedule_mode = zif_job_test=>gc_mode-classic
    job_name      = sy-cprog
    host          = sy-host
    is_batch      = xsdbool( sy-batch = abap_true ) ).

  " SM36 으로 스케줄한 경우 실제 잡 이름/카운트를 잡 런타임에서 읽어온다.
  IF sy-batch = abap_true.
    DATA: lv_jobname  TYPE tbtcm-jobname,
          lv_jobcount TYPE tbtcm-jobcount.

    CALL FUNCTION 'GET_JOB_RUNTIME_INFO'
      IMPORTING
        jobcount        = lv_jobcount
        jobname         = lv_jobname
      EXCEPTIONS
        no_runtime_info = 1
        OTHERS          = 2.

    IF sy-subrc = 0.
      ls_context-job_name  = lv_jobname.
      ls_context-job_count = lv_jobcount.
    ENDIF.
  ENDIF.

  DATA(lo_core) = NEW zcl_job_test_core( ).
  DATA(lv_error) = VALUE string( ).
  DATA(ls_summary) = VALUE zif_job_test=>ty_run_summary( ).

  TRY.
      ls_summary = lo_core->zif_job_test~run( is_params  = ls_params
                                              is_context = ls_context ).
    CATCH zcx_job_test INTO DATA(lx_job).
      lv_error = lx_job->message.
  ENDTRY.

* --- 스풀 리스트 출력 (SM37 > Spool 에서 확인) -------------------------
* Application Job 에는 이에 해당하는 기능이 없다. (COMPARISON.md 항목 #9)
  WRITE: / 'ZR_JOB_TEST', sy-datum, sy-uzeit.
  WRITE: / 'User        :', sy-uname.
  WRITE: / 'Host        :', sy-host.
  WRITE: / 'Background  :', COND string( WHEN sy-batch = abap_true THEN 'YES' ELSE 'NO' ).
  WRITE: / 'Job         :', ls_context-job_name, '/', ls_context-job_count.
  WRITE: / 'Run tag     :', p_tag.
  ULINE.
  WRITE: / 'Requested   :', ls_summary-requested.
  WRITE: / 'Written     :', ls_summary-written.
  ULINE.

  LOOP AT ls_summary-t_result INTO DATA(ls_result).
    WRITE: / ls_result-seq_no, ls_result-message.
  ENDLOOP.

  IF lv_error IS NOT INITIAL.
    ULINE.
    WRITE: / 'ERROR:', lv_error.
  ENDIF.

* --- 잡 로그 메시지 (SM37 > Job log) ----------------------------------
  IF sy-batch = abap_true.
    MESSAGE |ZR_JOB_TEST tag={ p_tag } written={ ls_summary-written }| TYPE 'I'.
  ENDIF.

* --- 강제 오류: 잡을 "abort" 상태로 만든다 ----------------------------
* SM37 에서는 상태가 "Canceled" 로 보인다. Application Jobs 앱에서는
* 같은 상황이 어떤 상태로 보이는지 비교할 것. (COMPARISON.md 항목 #15)
  IF lv_error IS NOT INITIAL.
    MESSAGE lv_error TYPE 'E'.
  ENDIF.
