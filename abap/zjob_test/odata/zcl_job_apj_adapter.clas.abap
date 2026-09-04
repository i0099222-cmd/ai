"! <p class="shorttext synchronized">Application Job API 어댑터 (CL_APJ_RT_API 래퍼)</p>
"!
"! RAP 핸들러가 CL_APJ_RT_API 를 직접 부르지 않고 이 클래스만 부르게 해서,
"! 릴리스마다 달라질 수 있는 APJ API 시그니처를 한 파일에 격리한다.
"! 시스템에 맞춰야 할 곳은 전부 "TODO: 시그니처 확인" 으로 표시했다.
"!
"! CL_APJ_RT_API 로 할 수 있는 것 = OData 로 테스트 가능한 APJ 기능의 범위:
"!   SCHEDULE_JOB   : 스케줄 생성 (즉시 / 예약 / 반복)
"!   GET_JOB_STATUS : 상태 조회
"!   CANCEL_JOB     : 취소
"! 반대로 SM36 의 "이벤트 시작 / 선행 잡 후 시작 / 대상 서버 / 잡 클래스 /
"! 다중 스텝" 에 대응하는 파라미터가 이 API 에 없다는 사실 자체가 비교 결과다.
CLASS zcl_job_apj_adapter DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_schedule_request,
        job_template_name  TYPE c LENGTH 60,
        params             TYPE zif_job_test=>ty_run_params,
        start_immediately  TYPE abap_bool,
        start_date         TYPE d,
        start_time         TYPE t,
        timezone           TYPE c LENGTH 6,
        recurrence_minutes TYPE i,
        end_date           TYPE d,
      END OF ty_schedule_request.

    TYPES:
      BEGIN OF ty_status_result,
        status  TYPE c LENGTH 1,
        message TYPE string,
      END OF ty_status_result.

    TYPES:
      BEGIN OF ty_schedule_result,
        job_name  TYPE c LENGTH 32,
        job_count TYPE c LENGTH 8,
        success   TYPE abap_bool,
        message   TYPE string,
      END OF ty_schedule_result.

    "! 잡 템플릿을 스케줄한다.
    METHODS schedule
      IMPORTING
        is_request       TYPE ty_schedule_request
      RETURNING
        VALUE(rs_result) TYPE ty_schedule_result.

    "! 잡 상태를 ZIF_JOB_TEST=>GC_STATUS 값으로 정규화해서 돌려준다.
    METHODS get_status
      IMPORTING
        iv_job_name      TYPE clike
        iv_job_count     TYPE clike
      RETURNING
        VALUE(rs_status) TYPE ty_status_result.

    "! 스케줄된/실행중인 잡을 취소한다.
    METHODS cancel
      IMPORTING
        iv_job_name       TYPE clike
        iv_job_count      TYPE clike
      RETURNING
        VALUE(rv_message) TYPE string.

  PRIVATE SECTION.

    METHODS build_parameter_values
      IMPORTING
        is_params      TYPE zif_job_test=>ty_run_params
      RETURNING
        VALUE(rt_vals) TYPE if_apj_rt_exec_object=>tt_templ_val.

ENDCLASS.


CLASS zcl_job_apj_adapter IMPLEMENTATION.

  METHOD schedule.

    TRY.

        DATA(lt_param_vals) = build_parameter_values( is_request-params ).

*----------------------------------------------------------------------*
* TODO: 시그니처 확인
*   CL_APJ_RT_API=>SCHEDULE_JOB 의 IS_START_INFO 구조
*   (CL_APJ_RT_API=>TY_START_INFO) 필드명은 릴리스마다 다르다.
*   ADT 에서 CL_APJ_RT_API 를 열어 확인한 뒤 이 블록만 맞추면
*   나머지 코드는 그대로 쓸 수 있다.
*----------------------------------------------------------------------*
        DATA ls_start_info TYPE cl_apj_rt_api=>ty_start_info.

        IF is_request-start_immediately = abap_true.
          ls_start_info-start_immediately = abap_true.
        ELSE.
          ls_start_info-earliest_start_date = is_request-start_date.
          ls_start_info-earliest_start_time = is_request-start_time.
          ls_start_info-timezone            = is_request-timezone.
        ENDIF.

        " 반복 스케줄. APJ 는 분/시/일 주기를 지원하지만 SM36 의
        " "팩토리캘린더 작업일에만 실행" 에는 대응이 없다. (비교 항목 #12)
        IF is_request-recurrence_minutes > 0.
          ls_start_info-recurrence_desc-min = is_request-recurrence_minutes.
          ls_start_info-end_date            = is_request-end_date.
        ENDIF.

        DATA lv_job_name  TYPE c LENGTH 32.
        DATA lv_job_count TYPE c LENGTH 8.

        cl_apj_rt_api=>schedule_job(
          EXPORTING
            iv_job_template_name = CONV #( is_request-job_template_name )
            iv_job_text          = CONV #( |JOBTEST { is_request-params-run_tag }| )
            is_start_info        = ls_start_info
            it_job_parameter_val = lt_param_vals
          IMPORTING
            ev_jobname           = lv_job_name
            ev_jobcount          = lv_job_count ).

        rs_result = VALUE #(
          job_name  = lv_job_name
          job_count = lv_job_count
          success   = abap_true
          message   = |Scheduled { lv_job_name } / { lv_job_count }| ).

      CATCH cx_root INTO DATA(lx_error).
        rs_result = VALUE #( success = abap_false
                             message = lx_error->get_text( ) ).
    ENDTRY.

  ENDMETHOD.


  METHOD get_status.

    rs_status-status = zif_job_test=>gc_status-unknown.

    TRY.

        " TODO: 시그니처 확인 - EV_JOB_STATUS 의 타입/값 도메인 확인 후 매핑 보정
        DATA lv_apj_status TYPE c LENGTH 1.

        cl_apj_rt_api=>get_job_status(
          EXPORTING
            iv_jobname    = CONV #( iv_job_name )
            iv_jobcount   = CONV #( iv_job_count )
          IMPORTING
            ev_job_status = lv_apj_status ).

        rs_status-status = SWITCH #( lv_apj_status
          WHEN 'S' THEN zif_job_test=>gc_status-scheduled
          WHEN 'R' THEN zif_job_test=>gc_status-running
          WHEN 'F' THEN zif_job_test=>gc_status-finished
          WHEN 'A' THEN zif_job_test=>gc_status-error
          WHEN 'X' THEN zif_job_test=>gc_status-cancelled
          ELSE          zif_job_test=>gc_status-unknown ).

        rs_status-message = |APJ status '{ lv_apj_status }'|.

      CATCH cx_root INTO DATA(lx_error).
        rs_status-status  = zif_job_test=>gc_status-unknown.
        rs_status-message = lx_error->get_text( ).
    ENDTRY.

  ENDMETHOD.


  METHOD cancel.

    TRY.

        cl_apj_rt_api=>cancel_job(
          iv_jobname  = CONV #( iv_job_name )
          iv_jobcount = CONV #( iv_job_count ) ).

        rv_message = |Cancelled { iv_job_name } / { iv_job_count }|.

      CATCH cx_root INTO DATA(lx_error).
        rv_message = lx_error->get_text( ).
    ENDTRY.

  ENDMETHOD.


  METHOD build_parameter_values.

    " 여기서 만드는 값들이 ZCL_APJ_JOB_TEST=>GET_PARAMETERS 의 정의와 1:1 이어야 한다.
    rt_vals = VALUE #(
      kind   = if_apj_dt_exec_object=>parameter
      sign   = 'I'
      option = 'EQ'
      ( selname = zif_job_test=>gc_param-run_tag    low = is_params-run_tag )
      ( selname = zif_job_test=>gc_param-rec_count  low = |{ is_params-rec_count }| )
      ( selname = zif_job_test=>gc_param-sleep_secs low = |{ is_params-sleep_secs }| )
      ( selname = zif_job_test=>gc_param-force_fail low = COND #( WHEN is_params-force_fail = abap_true
                                                                  THEN 'X' ELSE space ) ) ).

  ENDMETHOD.

ENDCLASS.
