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
    "! @parameter iv_param    | 잡 파라미터 값 (JSON). IT_JOB_PARAMETER_VALUE 타입을
    "!                          그대로 직렬화한 것이라 역직렬화만 하면 된다.
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

  PRIVATE SECTION.

    "! 반복 주기를 APJ 의 주기 구조로 변환한다.
    "!
    "! 반복/종료 조건을 APJ 의 스케줄 구조로 변환한다.
    "!
    "! TY_START_INFO 에는 START_IMMEDIATELY / TIMESTAMP 만 있고,
    "! 반복은 TY_SCHEDULING_INFO 가 담당한다.
    "!
    "!   periodic_granularity + periodic_value  주기 단위 + 값
    "!   timezone                               반복 계산 기준 타임존
    "!   end_info                               종료 조건 (NONE / AFTER / BY)
    "!   weekday_info / month_info              요일 / 월 지정
    "!   exception                              비작업일 처리
    "!
    "! TODO: 시그니처 확인
    "!   - PERIODIC_GRANULARITY 의 값 도메인 (상수인지 문자값인지)
    "!   - END_INFO 가 TY_SCHEDULING_INFO 의 컴포넌트인지, 별도 파라미터인지
    "!   - END_INFO-TYPE 의 값 (NONE / BY)
    "!   - WEEKDAY_INFO / MONTH_INFO / EXCEPTION 의 구조
    METHODS build_scheduling_info
      IMPORTING
        is_start        TYPE zif_batch_job=>ty_start_option
      RETURNING
        VALUE(rs_sched) TYPE cl_apj_rt_api=>ty_scheduling_info.

ENDCLASS.


CLASS zcl_batch_apj_adapter IMPLEMENTATION.

  METHOD schedule.

    TRY.

*----------------------------------------------------------------------*
* 시작 조건
*   TY_START_INFO 에는 START_IMMEDIATELY 와 TIMESTAMP 만 있다.
*   날짜/시각을 따로 넘길 수 없으므로 하나의 타임스탬프로 합친다.
*
*   ** 타임존은 APJ 가 처리해주지 않는다. **
*   요청 타임존 기준 시각을 우리가 UTC 타임스탬프로 변환해서 넣어야 한다.
*   AS-IS 가 하던 변환을 그대로 해야 하는 것이다.
*----------------------------------------------------------------------*
        DATA ls_start_info TYPE cl_apj_rt_api=>ty_start_info.

        IF is_start-start_immediately = abap_true.

          ls_start_info-start_immediately = abap_true.

        ELSEIF is_start-start_date IS NOT INITIAL.

          " 타임존 지정이 없으면 사용자 타임존으로 해석한다.
          DATA(lv_zone) = COND timezone(
            WHEN is_start-timezone IS NOT INITIAL
            THEN CONV #( is_start-timezone )
            ELSE cl_abap_context_info=>get_user_time_zone( ) ).

          DATA lv_timestamp TYPE timestamp.

          CONVERT DATE is_start-start_date TIME is_start-start_time
                  INTO TIME STAMP lv_timestamp TIME ZONE lv_zone.

          ls_start_info-timestamp = lv_timestamp.

        ELSE.

          " 시작일도 즉시실행도 없으면 지금 건다.
          ls_start_info-start_immediately = abap_true.

        ENDIF.

        " 반복 / 종료 조건
        DATA(ls_scheduling_info) = build_scheduling_info( is_start ).

*----------------------------------------------------------------------*
* 잡 파라미터
*   PARAM 에 저장된 JSON 은 IT_JOB_PARAMETER_VALUE 의 타입을 그대로
*   직렬화한 것이다. 그래서 역직렬화 한 줄이면 끝이고 변환이 없다.
*
*   구조: [{ "name":"P_MODU",
*            "t_value":[{ "sign":"I","option":"EQ","low":"SD" }] }]
*----------------------------------------------------------------------*
        DATA lt_param TYPE cl_apj_rt_api=>tt_job_parameter_value.

        IF iv_param IS NOT INITIAL.
          /ui2/cl_json=>deserialize( EXPORTING json = iv_param
                                     CHANGING  data = lt_param ).
        ENDIF.

        DATA lv_job_name  TYPE c LENGTH 32.
        DATA lv_job_count TYPE c LENGTH 8.

        cl_apj_rt_api=>schedule_job(
          EXPORTING
            iv_job_template_name   = CONV #( iv_template )
            " 사용자가 지은 논리 잡 이름을 잡 텍스트로 넘긴다.
            " APJ 는 잡 이름을 자동 생성하므로 이게 최선이다. (COMPARISON #16)
            iv_job_text            = CONV #( iv_jobtext )
            is_start_info          = ls_start_info
            is_scheduling_info     = ls_scheduling_info
            it_job_parameter_value = lt_param
          IMPORTING
            ev_jobname             = lv_job_name
            ev_jobcount            = lv_job_count ).

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


  METHOD build_scheduling_info.

*----------------------------------------------------------------------*
* 반복 주기 - AS-IS 반복주기 / 일반복주기
*   APJ 는 "단위 + 값" 으로 표현한다. 하나만 채운다.
*
* TODO: 시그니처 확인 - PERIODIC_GRANULARITY 의 값 도메인.
*       상수 클래스가 있으면 문자 리터럴 대신 그것을 쓸 것.
*----------------------------------------------------------------------*
    IF is_start-prd_mins > 0.
      rs_sched-periodic_granularity = 'MINUTE'.
      rs_sched-periodic_value       = is_start-prd_mins.

    ELSEIF is_start-prd_hours > 0.
      rs_sched-periodic_granularity = 'HOUR'.
      rs_sched-periodic_value       = is_start-prd_hours.

    ELSEIF is_start-prd_days > 0.
      rs_sched-periodic_granularity = 'DAY'.
      rs_sched-periodic_value       = is_start-prd_days.

    ELSEIF is_start-prd_weeks > 0.
      rs_sched-periodic_granularity = 'WEEK'.
      rs_sched-periodic_value       = is_start-prd_weeks.

    ELSEIF is_start-prd_months > 0.
      rs_sched-periodic_granularity = 'MONTH'.
      rs_sched-periodic_value       = is_start-prd_months.

    ENDIF.

*----------------------------------------------------------------------*
* 타임존 - AS-IS 시스템 zone시간
*   반복 계산의 기준 타임존이다. 지정이 없으면 사용자 타임존을 쓴다.
*----------------------------------------------------------------------*
    rs_sched-timezone = COND #(
      WHEN is_start-timezone IS NOT INITIAL
      THEN is_start-timezone
      ELSE cl_abap_context_info=>get_user_time_zone( ) ).

*----------------------------------------------------------------------*
* 종료 조건 - AS-IS 배치잡 close시간
*   BY   : 이 시각까지만 반복
*   NONE : 무한 반복
*
*   APJ 는 AFTER(N회 실행 후 종료)도 지원하지만 AS-IS 에 대응 값이 없어
*   쓰지 않는다.
*
* TODO: 시그니처 확인 - END_INFO 가 여기 컴포넌트인지 별도 파라미터인지,
*       그리고 TYPE 의 값(NONE / BY).
*----------------------------------------------------------------------*
    IF is_start-end_date IS NOT INITIAL.

      DATA lv_end_ts TYPE timestamp.

      CONVERT DATE is_start-end_date TIME is_start-end_time
              INTO TIME STAMP lv_end_ts TIME ZONE rs_sched-timezone.

      rs_sched-end_info-type      = 'BY'.
      rs_sched-end_info-timestamp = lv_end_ts.

    ELSE.

      rs_sched-end_info-type = 'NONE'.

    ENDIF.

*----------------------------------------------------------------------*
* 미사용
*   WEEKDAY_INFO / MONTH_INFO : 요일·월 지정. AS-IS 에 대응 항목이 없다.
*   EXCEPTION                 : 비작업일 처리. AS-IS 의 공장근무일
*                               (공장시간/공장근무일수/공장근무시간)을
*                               여기로 옮길 수 있는지 확인이 필요하다.
*   TEST_MODE                 : 테스트 모드
*----------------------------------------------------------------------*

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
