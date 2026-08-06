*&---------------------------------------------------------------------*
*& Function Module Z_EXCEL_MIGR_SCHEDULE_JOB
*&---------------------------------------------------------------------*
*& SE37에서 아래대로 생성:
*&   Function Group : (신규, 예: Z_EXCEL_MIGR)
*&   Function Module: Z_EXCEL_MIGR_SCHEDULE_JOB
*&
*&   Import    탭 : IV_REQUEST_ID TYPE SYSUUID_X16
*&   Export    탭 : EV_JOB_NAME   TYPE BTCJOB
*&                  EV_JOB_COUNT  TYPE BTCJOBCNT
*&   Exceptions 탭 : SCHEDULE_FAILED
*&
*&   JOB_OPEN/JOB_SUBMIT/JOB_CLOSE는 Standard ABAP 전용 API이므로 이 FM은
*&   반드시 Standard ABAP 언어버전 패키지에 위치해야 하고, SE37 > API State에서
*&   Local API로 Release해야 ABAP Cloud(RAP) 쪽에서 호출 가능하다.
*&
*&   아래 내용은 Source Code(처리 로직) 탭에 그대로 붙여넣으면 됨.
*&---------------------------------------------------------------------*
FUNCTION z_excel_migr_schedule_job.

  DATA: lv_jobname  TYPE btcjob,
        lv_jobcount TYPE btcjobcnt.

  " 잡 1건 = 요청 1건(request_id 1개). 여러 건을 동시에 업로드하면
  " 서로 다른 잡으로 떨어지므로 자연스럽게 병렬로 돌아간다 - 단, 서로 다른
  " request가 같은 대상 테이블의 겹치는 키 범위를 갖는 경우 락 대기가
  " 늘어날 수 있으니, 동일 테이블에 대한 대량 재업로드는 순차 처리를 권장.
  " BTCJOB은 CHAR32라 "ZEXCEL_MIGR_"(12자) + UUID 앞 20자리 hex로 맞춘다.
  DATA(lv_uuid_c) = CONV sysuuid_c32( iv_request_id ).
  lv_jobname = |ZEXCEL_MIGR_{ lv_uuid_c(20) }|.

  CALL FUNCTION 'JOB_OPEN'
    EXPORTING
      jobname          = lv_jobname
    IMPORTING
      jobcount         = lv_jobcount
    EXCEPTIONS
      cant_create_job  = 1
      invalid_job_data = 2
      jobname_missing  = 3
      OTHERS           = 4.

  IF sy-subrc <> 0.
    RAISE schedule_failed.
  ENDIF.

  " Z_EXCEL_TABLE_MIGRATOR: 실제 파싱 + 동적 INSERT를 수행하는 Standard ABAP
  " 리포트. request_id 파라미터 하나로 ZEXCEL_MIGR_REQ에서 나머지 정보를 읽는다.
  SUBMIT z_excel_table_migrator
    WITH p_reqid = iv_request_id
    VIA JOB lv_jobname NUMBER lv_jobcount
    AND RETURN.

  IF sy-subrc <> 0.
    RAISE schedule_failed.
  ENDIF.

  CALL FUNCTION 'JOB_CLOSE'
    EXPORTING
      jobcount             = lv_jobcount
      jobname               = lv_jobname
      strtimmed             = abap_true   " 즉시 시작 - 접수 직후 처리 개시
    EXCEPTIONS
      cant_start_immediate = 1
      invalid_startdate     = 2
      jobname_missing       = 3
      job_close_failed      = 4
      job_nosteps           = 5
      job_notex              = 6
      lock_failed            = 7
      OTHERS                  = 8.

  IF sy-subrc <> 0.
    RAISE schedule_failed.
  ENDIF.

  ev_job_name  = lv_jobname.
  ev_job_count = lv_jobcount.

ENDFUNCTION.
