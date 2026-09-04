"! <p class="shorttext synchronized">Application Job API 어댑터 (CL_APJ_RT_API 래퍼)</p>
"!
"! RAP 핸들러가 CL_APJ_RT_API 를 직접 부르지 않고 이 클래스만 부른다.
"! 릴리스마다 달라질 수 있는 APJ API 시그니처를 한 파일에 격리하기 위해서다.
"! 시스템에 맞춰야 할 곳은 "TODO: 시그니처 확인" 으로 표시했다.
CLASS zcl_job_apj_adapter DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_schedule_result,
        job_name  TYPE c LENGTH 32,
        job_count TYPE c LENGTH 8,
        success   TYPE abap_bool,
        message   TYPE string,
      END OF ty_schedule_result.

    TYPES:
      BEGIN OF ty_status_result,
        status  TYPE c LENGTH 1,
        message TYPE string,
      END OF ty_status_result.

    "! ZTJOB_RUN 한 건을 Application Job 으로 스케줄한다.
    "! 잡 파라미터는 P_RUNID 하나뿐이고, 나머지 설정은 런처가 DB 에서 읽는다.
    "! 시작 조건은 DB 가 아니라 액션 파라미터에서 온다.
    METHODS schedule
      IMPORTING
        iv_run_uuid      TYPE sysuuid_x16
        iv_template      TYPE clike
        iv_jobtext       TYPE clike
        is_start         TYPE zif_bc_job=>ty_start_option
      RETURNING
        VALUE(rs_result) TYPE ty_schedule_result.

    METHODS get_status
      IMPORTING
        iv_job_name      TYPE clike
        iv_job_count     TYPE clike
      RETURNING
        VALUE(rs_status) TYPE ty_status_result.

    METHODS cancel
      IMPORTING
        iv_job_name       TYPE clike
        iv_job_count      TYPE clike
      RETURNING
        VALUE(rv_message) TYPE string.

ENDCLASS.


CLASS zcl_job_apj_adapter IMPLEMENTATION.

  METHOD schedule.

    TRY.

*----------------------------------------------------------------------*
* TODO: 시그니처 확인
*   CL_APJ_RT_API=>TY_START_INFO 의 필드명은 릴리스마다 다르다.
*   ADT 에서 CL_APJ_RT_API 를 열어 확인한 뒤 이 블록만 맞추면 된다.
*----------------------------------------------------------------------*
        DATA ls_start_info TYPE cl_apj_rt_api=>ty_start_info.

        IF is_start-start_immediately = abap_true.
          ls_start_info-start_immediately = abap_true.
        ELSE.
          ls_start_info-earliest_start_date = is_start-start_date.
          ls_start_info-earliest_start_time = is_start-start_time.
          " 타임존은 APJ 가 처리한다. AS-IS 는 직접 변환했다. (COMPARISON A4)
          ls_start_info-timezone            = is_start-timezone.
        ENDIF.

        " 반복 주기. AS-IS 의 반복주기 / 일반복주기.
        " 팩토리 캘린더(공장근무일)는 APJ 에 대응이 없어 런처가 판정한다.
        IF is_start-prd_mins   > 0. ls_start_info-recurrence_desc-min   = is_start-prd_mins.   ENDIF.
        IF is_start-prd_hours  > 0. ls_start_info-recurrence_desc-hour  = is_start-prd_hours.  ENDIF.
        IF is_start-prd_days   > 0. ls_start_info-recurrence_desc-day   = is_start-prd_days.   ENDIF.
        IF is_start-prd_weeks  > 0. ls_start_info-recurrence_desc-week  = is_start-prd_weeks.  ENDIF.
        IF is_start-prd_months > 0. ls_start_info-recurrence_desc-month = is_start-prd_months. ENDIF.

        " 잡 파라미터는 스케줄 행 UUID 하나뿐
        DATA(lt_param) = VALUE if_apj_rt_exec_object=>tt_templ_val(
          ( selname = zif_bc_job=>gc_param-run_id
            kind    = if_apj_dt_exec_object=>parameter
            sign    = 'I'
            option  = 'EQ'
            low     = iv_run_uuid ) ).

        DATA lv_job_name  TYPE c LENGTH 32.
        DATA lv_job_count TYPE c LENGTH 8.

        cl_apj_rt_api=>schedule_job(
          EXPORTING
            iv_job_template_name = CONV #( iv_template )
            " 사용자가 지은 논리 잡 이름을 잡 텍스트로 넘긴다.
            " APJ 는 잡 이름을 자동 생성하므로 이게 최선이다. (COMPARISON #16)
            iv_job_text          = CONV #( iv_jobtext )
            is_start_info        = ls_start_info
            it_job_parameter_val = lt_param
          IMPORTING
            ev_jobname           = lv_job_name
            ev_jobcount          = lv_job_count ).

        rs_result = VALUE #( job_name  = lv_job_name
                             job_count = lv_job_count
                             success   = abap_true
                             message   = |Scheduled { lv_job_name }/{ lv_job_count }| ).

      CATCH cx_root INTO DATA(lx_error).
        rs_result = VALUE #( success = abap_false
                             message = lx_error->get_text( ) ).
    ENDTRY.

  ENDMETHOD.


  METHOD get_status.

    rs_status-status = zif_bc_job=>gc_status-unknown.

    TRY.

        " TODO: 시그니처 확인 - EV_JOB_STATUS 의 타입/값 도메인
        DATA lv_apj_status TYPE c LENGTH 1.

        cl_apj_rt_api=>get_job_status(
          EXPORTING
            iv_jobname    = CONV #( iv_job_name )
            iv_jobcount   = CONV #( iv_job_count )
          IMPORTING
            ev_job_status = lv_apj_status ).

        rs_status-status = SWITCH #( lv_apj_status
          WHEN 'S' THEN zif_bc_job=>gc_status-scheduled
          WHEN 'R' THEN zif_bc_job=>gc_status-running
          WHEN 'F' THEN zif_bc_job=>gc_status-finished
          WHEN 'A' THEN zif_bc_job=>gc_status-error
          WHEN 'X' THEN zif_bc_job=>gc_status-cancelled
          ELSE          zif_bc_job=>gc_status-unknown ).

        rs_status-message = |APJ status '{ lv_apj_status }'|.

      CATCH cx_root INTO DATA(lx_error).
        rs_status-status  = zif_bc_job=>gc_status-unknown.
        rs_status-message = lx_error->get_text( ).
    ENDTRY.

  ENDMETHOD.


  METHOD cancel.

    TRY.
        cl_apj_rt_api=>cancel_job( iv_jobname  = CONV #( iv_job_name )
                                   iv_jobcount = CONV #( iv_job_count ) ).
        rv_message = |Cancelled { iv_job_name }/{ iv_job_count }|.

      CATCH cx_root INTO DATA(lx_error).
        rv_message = lx_error->get_text( ).
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
