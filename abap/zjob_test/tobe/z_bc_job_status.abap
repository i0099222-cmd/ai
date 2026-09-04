*&---------------------------------------------------------------------*
*& Function Module Z_BC_JOB_STATUS
*&---------------------------------------------------------------------*
*& AS-IS ZBC_BATCH_JOB_STATUS 대체.
*&
*& BP_JOB_SELECT 대신 TBTCO/TBTCP 를 직접 조회한다.
*& BP_JOB_SELECT 는 셀렉션 구조가 복잡하고 릴리스별 차이가 있어서,
*& 단순 조회는 테이블 직접 읽기가 안정적이다.
*&   TBTCO = 잡 헤더 (상태/시작시각/종료시각)
*&   TBTCP = 잡 스텝 (리포트/배리언트/사용자)
*&
*& SE37 생성:
*&   Function Group : Z_BC_JOB (Standard ABAP 언어버전)
*&   Processing Type: Remote-Enabled Module
*&   Import : IV_JOBNAME  TYPE C LENGTH 32
*&            IV_JOBCOUNT TYPE C LENGTH 8  (선택)
*&   Tables : ET_JOB      TYPE ZBC_JOB_STATUS_T  (아래 구조 참고)
*&
*& 생성 후 API State 에서 Local API 로 release.
*&---------------------------------------------------------------------*
FUNCTION z_bc_job_status.

  " 반환 구조 (딕셔너리 구조 ZBC_JOB_STATUS 로 만들어 쓸 것):
  "   jobname, jobcount, status, status_text,
  "   sdlstrtdt, sdlstrttm,        " 예정 시작
  "   strtdate,  strttime,         " 실제 시작
  "   enddate,   endtime,          " 종료
  "   authcknam,                   " 스텝 사용자
  "   reax_server                  " 실행 서버

  CLEAR et_job.

  IF iv_jobcount IS INITIAL.
    SELECT jobname, jobcount, status,
           sdlstrtdt, sdlstrttm,
           strtdate, strttime,
           enddate, endtime,
           authcknam, reaxserver
      FROM tbtco
      WHERE jobname = @iv_jobname
      ORDER BY sdlstrtdt DESCENDING, sdlstrttm DESCENDING
      INTO CORRESPONDING FIELDS OF TABLE @et_job.
  ELSE.
    SELECT jobname, jobcount, status,
           sdlstrtdt, sdlstrttm,
           strtdate, strttime,
           enddate, endtime,
           authcknam, reaxserver
      FROM tbtco
      WHERE jobname  = @iv_jobname
        AND jobcount = @iv_jobcount
      INTO CORRESPONDING FIELDS OF TABLE @et_job.
  ENDIF.

  " 상태 텍스트 채우기.
  " TBTCO-STATUS: P 예약 / S 릴리즈 / Y 준비 / R 실행중 / F 종료 / A 취소
  LOOP AT et_job ASSIGNING FIELD-SYMBOL(<ls_job>).
    <ls_job>-status_text = SWITCH string( <ls_job>-status
      WHEN zif_bc_job=>gc_status-scheduled THEN 'Scheduled'
      WHEN zif_bc_job=>gc_status-released  THEN 'Released'
      WHEN zif_bc_job=>gc_status-ready     THEN 'Ready'
      WHEN zif_bc_job=>gc_status-running   THEN 'Active'
      WHEN zif_bc_job=>gc_status-finished  THEN 'Finished'
      WHEN zif_bc_job=>gc_status-cancelled THEN 'Cancelled'
      ELSE 'Unknown' ).
  ENDLOOP.

  " TODO: 스텝 정보(리포트/배리언트)까지 필요하면 TBTCP 를 조인해서 채운다.
  "   SELECT jobname, jobcount, stepcount, progname, jobtype, authcknam, variant
  "     FROM tbtcp FOR ALL ENTRIES IN @et_job
  "    WHERE jobname = @et_job-jobname AND jobcount = @et_job-jobcount

ENDFUNCTION.
