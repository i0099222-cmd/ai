"! <p class="shorttext synchronized">Application Job API 어댑터 (CL_APJ_RT_API 래퍼)</p>
"!
"! RAP 핸들러가 CL_APJ_RT_API 를 직접 부르지 않고 이 클래스만 부른다.
"! 실행 대상은 잡 템플릿이 결정한다 (템플릿 -> 카탈로그 엔트리 -> 실행 클래스).
"! 릴리스마다 달라질 수 있는 APJ API 시그니처를 한 파일에 격리하기 위해서다.
"! 시스템에 맞춰야 할 곳은 "TODO: 시그니처 확인" 으로 표시했다.
CLASS zcl_batch_apj_adapter DEFINITION
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

    "! 잡 템플릿을 Application Job 으로 스케줄한다.
    "!
    "! @parameter iv_template | 실행 대상을 결정한다. 템플릿 -> 카탈로그 -> 실행 클래스.
    "! @parameter iv_jobtext  | 잡 텍스트. APJ 는 잡 이름을 자동 생성하므로
    "!                          사용자가 지은 이름은 여기로 넘긴다.
    "! @parameter iv_param    | 잡 파라미터 값 (JSON). 실행 클래스가 정의한 SELNAME 기준.
    "! @parameter is_start    | 시작 조건. DB 가 아니라 액션 파라미터에서 온다.
    METHODS schedule
      IMPORTING
        iv_template      TYPE clike
        iv_jobtext       TYPE clike
        iv_param         TYPE string OPTIONAL
        is_start         TYPE zif_batch_job=>ty_start_option
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


CLASS zcl_batch_apj_adapter IMPLEMENTATION.

  METHOD schedule.

    TRY.

        DATA ls_start_info TYPE cl_apj_rt_api=>ty_start_info.

        IF is_start-start_immediately = abap_true.
          ls_start_info-start_immediately = abap_true.
        ELSE.
          ls_start_info-earliest_start_date = is_start-start_date.
          ls_start_info-earliest_start_time = is_start-start_time.
          " 타임존은 APJ 가 처리한다. AS-IS 는 직접 변환했다. (COMPARISON A4)
          ls_start_info-timezone            = is_start-timezone.
        ENDIF.

        " 반복 주기는 릴리스마다 자리가 달라서 별도 메서드로 격리했다.
        fill_recurrence( EXPORTING is_start      = is_start
                         CHANGING  cs_start_info = ls_start_info ).

        " 실행 클래스가 GET_PARAMETERS 로 정의한 파라미터의 값들
        DATA(lt_param) = zcl_batch_param=>to_apj( iv_param ).

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

    rs_status-status = zif_batch_job=>gc_status-unknown.

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
          WHEN 'S' THEN zif_batch_job=>gc_status-scheduled
          WHEN 'R' THEN zif_batch_job=>gc_status-running
          WHEN 'F' THEN zif_batch_job=>gc_status-finished
          WHEN 'A' THEN zif_batch_job=>gc_status-error
          WHEN 'X' THEN zif_batch_job=>gc_status-cancelled
          ELSE          zif_batch_job=>gc_status-unknown ).

        rs_status-message = |APJ status '{ lv_apj_status }'|.

      CATCH cx_root INTO DATA(lx_error).
        rs_status-status  = zif_batch_job=>gc_status-unknown.
        rs_status-message = lx_error->get_text( ).
    ENDTRY.

  ENDMETHOD.


  METHOD fill_recurrence.

*----------------------------------------------------------------------*
* !! 미구현 !!
* 이 시스템의 TY_START_INFO 에 RECURRENCE_DESC 가 없다.
* 실제 필드를 확인한 뒤 아래 매핑을 살려야 반복(주기) 스케줄이 동작한다.
* 그때까지는 1회성 스케줄만 걸린다.
*
* AS-IS 대응:
*   반복주기   -> prd_mins / prd_hours / prd_weeks / prd_months
*   일반복주기 -> prd_days
*
*   IF is_start-prd_mins   > 0. cs_start_info-<필드> = is_start-prd_mins.   ENDIF.
*   IF is_start-prd_hours  > 0. cs_start_info-<필드> = is_start-prd_hours.  ENDIF.
*   IF is_start-prd_days   > 0. cs_start_info-<필드> = is_start-prd_days.   ENDIF.
*   IF is_start-prd_weeks  > 0. cs_start_info-<필드> = is_start-prd_weeks.  ENDIF.
*   IF is_start-prd_months > 0. cs_start_info-<필드> = is_start-prd_months. ENDIF.
*
* 팩토리 캘린더(공장근무일)는 어느 경우든 APJ 반복 패턴에 대응이 없다.
* 필요하면 실행 클래스가 EXECUTE 안에서 직접 판정해야 한다.
*----------------------------------------------------------------------*
    RETURN.

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
