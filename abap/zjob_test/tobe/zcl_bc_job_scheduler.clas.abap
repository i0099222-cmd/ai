"! <p class="shorttext synchronized">배치잡 스케줄러 진입점 (Cloud 티어)</p>
"!
"! RAP 액션(ZBP_I_JOB_RUN)이 부르는 유일한 클래스.
"! 실제 JOB_OPEN/JOB_SUBMIT/JOB_CLOSE 는 Standard ABAP FM 에 있고
"! 이 클래스는 그 FM 만 호출한다.
"!
"! 언어버전: ABAP for Cloud Development.
"! 호출하는 FM 3종은 Standard ABAP 패키지에 두고 Local API 로 release 해야 한다.
"! (기존 ZCL_PARKED_DOC_POSTER -> Z_FI_PARKED_DOC_POST_BDC 와 동일한 패턴)
CLASS zcl_bc_job_scheduler DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! 잡 생성 + 릴리즈. AS-IS ZBC_BATCH_JOB_CREATE 대체.
    METHODS schedule
      IMPORTING
        is_header        TYPE zif_bc_job=>ty_header
        it_steps         TYPE zif_bc_job=>tt_step
        is_requester     TYPE zif_bc_job=>ty_requester OPTIONAL
      RETURNING
        VALUE(rs_result) TYPE zif_bc_job=>ty_result.

    "! 잡 삭제. AS-IS ZBC_BATCH_JOB_DELETE 대체.
    METHODS delete
      IMPORTING
        iv_jobname       TYPE clike
        iv_jobcount      TYPE clike OPTIONAL
      RETURNING
        VALUE(rs_result) TYPE zif_bc_job=>ty_result.

    "! 잡 상태 조회. AS-IS ZBC_BATCH_JOB_STATUS 대체.
    METHODS get_status
      IMPORTING
        iv_jobname       TYPE clike
        iv_jobcount      TYPE clike OPTIONAL
      RETURNING
        VALUE(rs_result) TYPE zif_bc_job=>ty_result.

  PRIVATE SECTION.

    "! 스케줄 전 검증. AS-IS 는 BDC 화면이 걸러주던 것들을 여기서 막는다.
    "! Application Job 의 CHECK_PARAMETERS 에 해당하는 자리다.
    METHODS validate
      IMPORTING
        is_header        TYPE zif_bc_job=>ty_header
        it_steps         TYPE zif_bc_job=>tt_step
      RETURNING
        VALUE(rv_error)  TYPE string.

ENDCLASS.


CLASS zcl_bc_job_scheduler IMPLEMENTATION.

  METHOD schedule.

    DATA(lv_error) = validate( is_header = is_header it_steps = it_steps ).

    IF lv_error IS NOT INITIAL.
      rs_result = VALUE #( jobname = is_header-jobname
                           success = abap_false
                           status  = zif_bc_job=>gc_status-unknown
                           message = lv_error ).
      RETURN.
    ENDIF.

    " NOTE: 타 시스템에 잡을 걸어야 하면 여기서 IS_HEADER-SYS_ID / CLIENT 로
    "       RFC destination 을 골라 DESTINATION 추가 호출해야 한다.
    "       자기 시스템 전용이면 지금 형태로 충분하다.
    CALL FUNCTION 'Z_BC_JOB_SCHEDULE'
      EXPORTING
        is_header = is_header
        it_steps  = it_steps
      IMPORTING
        es_result = rs_result.

  ENDMETHOD.


  METHOD delete.

    CALL FUNCTION 'Z_BC_JOB_DELETE'
      EXPORTING
        iv_jobname  = CONV #( iv_jobname )
        iv_jobcount = CONV #( iv_jobcount )
      IMPORTING
        es_result   = rs_result.

  ENDMETHOD.


  METHOD get_status.

    " TODO: Z_BC_JOB_STATUS 는 TABLES 로 여러 건을 돌려준다.
    "       여기서는 최신 1건만 요약해 넘긴다. 목록이 필요하면
    "       별도 메서드로 테이블을 그대로 반환할 것.
    rs_result = VALUE #( jobname  = CONV #( iv_jobname )
                         jobcount = CONV #( iv_jobcount )
                         status   = zif_bc_job=>gc_status-unknown ).

  ENDMETHOD.


  METHOD validate.

    IF is_header-jobname IS INITIAL.
      rv_error = 'Job name is required'.
      RETURN.
    ENDIF.

    IF it_steps IS INITIAL.
      rv_error = 'At least one step is required'.
      RETURN.
    ENDIF.

    IF is_header-jobclass IS NOT INITIAL
       AND NOT is_header-jobclass CA 'ABC'.
      rv_error = |Invalid job class '{ is_header-jobclass }' (A/B/C only)|.
      RETURN.
    ENDIF.

    " 즉시 시작이 아니면 시작 일시가 있어야 한다
    IF is_header-start_immed = abap_false
       AND is_header-sdlstrtdt IS INITIAL.
      rv_error = 'Start date is required unless immediate start'.
      RETURN.
    ENDIF.

    " 반복 주기는 하나만 채워져 있어야 한다
    DATA(lv_prd_count) = 0.
    IF is_header-prd_mins   > 0. lv_prd_count = lv_prd_count + 1. ENDIF.
    IF is_header-prd_hours  > 0. lv_prd_count = lv_prd_count + 1. ENDIF.
    IF is_header-prd_days   > 0. lv_prd_count = lv_prd_count + 1. ENDIF.
    IF is_header-prd_weeks  > 0. lv_prd_count = lv_prd_count + 1. ENDIF.
    IF is_header-prd_months > 0. lv_prd_count = lv_prd_count + 1. ENDIF.

    IF lv_prd_count > 1.
      rv_error = 'Only one periodicity unit may be set'.
      RETURN.
    ENDIF.

    " 스텝 검증
    LOOP AT it_steps INTO DATA(ls_step).
      IF ls_step-pg_id IS INITIAL.
        rv_error = |Step { sy-tabix }: program name is required|.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
