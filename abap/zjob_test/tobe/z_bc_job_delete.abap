*&---------------------------------------------------------------------*
*& Function Module Z_BC_JOB_DELETE
*&---------------------------------------------------------------------*
*& AS-IS ZBC_BATCH_JOB_DELETE 의 BDC 를 표준 FM 으로 대체.
*&
*& SE37 생성:
*&   Function Group : Z_BC_JOB (Standard ABAP 언어버전)
*&   Processing Type: Remote-Enabled Module
*&   Import : IV_JOBNAME  TYPE C LENGTH 32
*&            IV_JOBCOUNT TYPE C LENGTH 8   (초기값이면 해당 잡명 전체 삭제)
*&   Export : ES_RESULT   TYPE ZIF_BC_JOB=>TY_RESULT
*&
*& 생성 후 API State 에서 Local API 로 release.
*&
*& TODO: 시그니처 확인 - BP_JOB_DELETE 의 파라미터/예외명
*&---------------------------------------------------------------------*
FUNCTION z_bc_job_delete.

  DATA lt_target TYPE STANDARD TABLE OF tbtco WITH DEFAULT KEY.

  CLEAR es_result.
  es_result-jobname  = iv_jobname.
  es_result-jobcount = iv_jobcount.

  IF iv_jobname IS INITIAL.
    es_result = VALUE #( success = abap_false
                         message = 'Job name is required' ).
    RETURN.
  ENDIF.

  " jobcount 가 없으면 같은 이름의 잡을 전부 대상으로 한다.
  " (AS-IS 가 어느 쪽인지 확인 필요 - 잡명만으로 삭제하는 화면이면 이 동작)
  IF iv_jobcount IS INITIAL.
    SELECT jobname, jobcount, status
      FROM tbtco
      WHERE jobname = @iv_jobname
      INTO CORRESPONDING FIELDS OF TABLE @lt_target.
  ELSE.
    APPEND VALUE #( jobname = iv_jobname jobcount = iv_jobcount ) TO lt_target.
  ENDIF.

  IF lt_target IS INITIAL.
    es_result = VALUE #( success = abap_false
                         status  = zif_bc_job=>gc_status-unknown
                         message = |Job { iv_jobname } not found| ).
    RETURN.
  ENDIF.

  DATA(lv_deleted) = 0.
  DATA(lv_failed)  = 0.

  LOOP AT lt_target INTO DATA(ls_target).

    CALL FUNCTION 'BP_JOB_DELETE'
      EXPORTING
        jobcount                = ls_target-jobcount
        jobname                 = ls_target-jobname
      EXCEPTIONS
        " TODO: 시그니처 확인 - SE37 에서 BP_JOB_DELETE 의 예외 목록을 보고
        "       그대로 옮길 것. 아래는 대표적인 것만 적어둔 것이다.
        cant_delete_job        = 1
        job_does_not_exist     = 2
        job_is_already_running = 3
        no_delete_authority    = 4
        OTHERS                 = 5.

    IF sy-subrc = 0.
      lv_deleted = lv_deleted + 1.
    ELSE.
      lv_failed = lv_failed + 1.
      es_result-message = |{ es_result-message } [{ ls_target-jobcount }: subrc={ sy-subrc }]|.
    ENDIF.

  ENDLOOP.

  es_result-success = xsdbool( lv_failed = 0 ).
  es_result-status  = COND #( WHEN lv_failed = 0
                              THEN zif_bc_job=>gc_status-cancelled
                              ELSE zif_bc_job=>gc_status-unknown ).
  es_result-message = |Deleted { lv_deleted }, failed { lv_failed }. { es_result-message }|.

ENDFUNCTION.
