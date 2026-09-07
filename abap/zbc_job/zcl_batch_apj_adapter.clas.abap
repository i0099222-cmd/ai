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

    "! 주기 값 하나와 그 APJ 단위. 어느 값이 채워졌는지 세기 위해 테이블로 다룬다.
    TYPES:
      BEGIN OF ty_unit,
        value       TYPE i,
        granularity TYPE string,
      END OF ty_unit,
      tt_unit TYPE STANDARD TABLE OF ty_unit WITH EMPTY KEY.

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
        VALUE(rs_sched) TYPE cl_apj_rt_api=>ty_scheduling_info
      RAISING
        zcx_batch_job.

    "! AS-IS 인터페이스의 CHAR(15) 일시를 UTC 타임스탬프로 바꾼다.
    "!
    "! 숫자만 뽑아 앞 8자리를 날짜, 다음 6자리를 시각으로 읽으므로
    "! '20261001020000' / '20261001 020000' / '2026-10-01 02:00:00' 이
    "! 모두 동작한다. 시각이 없으면 IV_DEFAULT_TIME 을 쓴다 - 시작 일시는
    "! 00:00:00(그 날의 시작), 종료 일시는 23:59:59(그 날의 끝)가 의도다.
    "! 비근무일(또는 없는 날짜)에 어느 방향으로 옮길지의 코드.
    "!
    "! START_RESTRICTION_CODE 와 SHIFT_DIRECTION 이 같은 값 도메인을 쓴다고
    "! 보고 한 곳에서 만든다. 도메인이 다르면 여기서 갈라주면 된다.
    "!
    "! TODO: 시그니처 확인 - 실제 값. 'B'/'A' 는 추정이다.
    METHODS shift_code
      IMPORTING
        iv_before      TYPE abap_bool
      RETURNING
        VALUE(rv_code) TYPE c LENGTH 1.

    METHODS to_timestamp
      IMPORTING
        iv_datetime         TYPE clike
        iv_timezone         TYPE timezone
        iv_default_time     TYPE t DEFAULT '000000'
      RETURNING
        VALUE(rv_timestamp) TYPE timestamp.

    "! 타임존 지정이 없으면 사용자 타임존을 쓴다.
    METHODS resolve_zone
      IMPORTING
        iv_timezone    TYPE clike
      RETURNING
        VALUE(rv_zone) TYPE timezone.

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

        ELSEIF is_start-start_datetime IS NOT INITIAL.

          ls_start_info-timestamp = to_timestamp(
            iv_datetime = is_start-start_datetime
            iv_timezone = resolve_zone( is_start-timezone ) ).

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
* 반복 주기 - AS-IS 반복주기(PRDMONTHS) / 일반복주기(PRDDAYS)
*
*   SM36 은 PRDMONTHS/PRDWEEKS/PRDDAYS/PRDHOURS/PRDMINS 를 동시에 채우면
*   그 합을 주기로 삼는다 (1개월 + 15일 = 45일 주기).
*   APJ 는 단위 하나 + 값 하나뿐이라 합산을 표현할 수 없다.
*
*   그래서 둘 이상 채워지면 조용히 하나를 고르지 않고 실패시킨다.
*   잘못된 주기로 잡이 걸리는 것보다 안 걸리는 편이 낫다.
*
* TODO: 시그니처 확인 - PERIODIC_GRANULARITY 의 값 도메인.
*       상수 클래스가 있으면 문자 리터럴 대신 그것을 쓸 것.
*----------------------------------------------------------------------*
    DATA(lt_unit) = VALUE tt_unit(
      ( value = is_start-prd_mins   granularity = 'MINUTE' )
      ( value = is_start-prd_hours  granularity = 'HOUR'   )
      ( value = is_start-prd_days   granularity = 'DAY'    )
      ( value = is_start-prd_weeks  granularity = 'WEEK'   )
      ( value = is_start-prd_months granularity = 'MONTH'  ) ).

    DELETE lt_unit WHERE value <= 0.

    IF lines( lt_unit ) > 1.
      RAISE EXCEPTION TYPE zcx_batch_job
        EXPORTING
          message = |반복 주기는 한 단위만 지정할 수 있다. |
                 && |APJ 는 합산 주기를 표현하지 못한다: |
                 && concat_lines_of( table = VALUE string_table(
                        FOR u IN lt_unit ( |{ u-granularity } { u-value }| ) )
                      sep = ` + ` ).
    ENDIF.

    IF lt_unit IS NOT INITIAL.
      rs_sched-periodic_granularity = lt_unit[ 1 ]-granularity.
      rs_sched-periodic_value       = lt_unit[ 1 ]-value.
    ENDIF.

*----------------------------------------------------------------------*
* 타임존 - AS-IS 시스템 zone시간
*   반복 계산의 기준 타임존이다. 지정이 없으면 사용자 타임존을 쓴다.
*----------------------------------------------------------------------*
    rs_sched-timezone = resolve_zone( is_start-timezone ).

*----------------------------------------------------------------------*
* 종료 조건 - AS-IS 배치잡 close시간
*   BY : 이 시각 이후로는 더 스케줄하지 않는다. 이미 시작된 실행을
*        중단시키는 것이 아니다 - SM36 의 laststrtdt/tm 과 같은 의미다.
*
*        날짜만 들어오면 그 날 23:59:59 로 본다. 00:00:00 으로 읽으면
*        "9월 7일까지" 가 9월 6일까지가 되어 하루가 잘린다.
*
*   close시간이 없으면 END_INFO 를 통째로 비워 둔다. TYPE = 'NONE' 을
*   명시하지 않는 이유는 값 도메인을 아직 확인하지 못했기 때문이고,
*   구조 전체가 초기값이면 "지정 안 함" 으로 읽히는 것이 일반적이다.
*   API 가 TYPE 을 필수로 검증하면 여기서 바로 에러가 나므로 그때
*   확인된 상수를 넣으면 된다.
*
*   AFTER(N회 실행 후 종료)는 AS-IS 에 대응 값이 없어 쓰지 않는다.
*
* TODO: 시그니처 확인 - END_INFO 가 여기 컴포넌트인지 별도 파라미터인지,
*       그리고 TYPE 의 값(NONE / BY).
*----------------------------------------------------------------------*
    IF is_start-end_datetime IS NOT INITIAL.

      rs_sched-end_info-type      = 'BY'.
      rs_sched-end_info-timestamp = to_timestamp(
        iv_datetime     = is_start-end_datetime
        iv_timezone     = rs_sched-timezone
        iv_default_time = '235959' ).

    ENDIF.

*----------------------------------------------------------------------*
* 제한 조건 - AS-IS SM36 Restrictions 팝업
*
*   EXCEPTION{ calendar_id, start_restriction_code }
*     달력을 지정하지 않으면 근무일 판정 자체가 불가능하므로,
*     CALENDAR_ID 가 비면 나머지 제한 조건도 무의미하다.
*
*   MONTH_INFO{ day, use_working_days_ind, shift_direction, week_number }
*     WEEK_NUMBER 는 AS-IS 에 대응이 없어 쓰지 않는다.
*
* TODO: 시그니처 확인 - START_RESTRICTION_CODE / SHIFT_DIRECTION 의 값 도메인.
*       아래 상수 두 개만 고치면 된다.
*----------------------------------------------------------------------*
    IF is_start-calendar_id IS NOT INITIAL.
      rs_sched-exception-calendar_id = is_start-calendar_id.
      rs_sched-exception-start_restriction_code = shift_code( is_start-execute_before ).
    ENDIF.

*   월중 실행일. 말일은 일자로 표현할 수 없어 31 로 넣고 없는 달은
*   앞당기게 한다 - 2월이면 28/29일이 된다.
*
* TODO: 확인 - SHIFT_DIRECTION 이 "존재하지 않는 날짜" 에도 적용되는지,
*       아니면 "근무일이 아닌 날" 에만 적용되는지. 후자면 이 방식으로는
*       월말을 표현할 수 없다. 2월로 테스트해 SM37 에서 확인할 것.
    IF is_start-eof_month = abap_true OR is_start-month_day > 0.

      rs_sched-month_info-day = COND #( WHEN is_start-eof_month = abap_true
                                        THEN 31 ELSE is_start-month_day ).

      rs_sched-month_info-use_working_days_ind = is_start-use_working_days.

      "  말일은 없는 달에서 반드시 앞당겨야 하므로 요청과 무관하게 이전 방향.
      rs_sched-month_info-shift_direction =
        shift_code( COND #( WHEN is_start-eof_month = abap_true
                            THEN abap_true ELSE is_start-execute_before ) ).
    ENDIF.

*----------------------------------------------------------------------*
* 미사용
*   WEEKDAY_INFO : 요일 지정. AS-IS 에 대응 항목이 없다.
*   TEST_MODE    : 테스트 모드
*----------------------------------------------------------------------*

  ENDMETHOD.


  METHOD shift_code.
    rv_code = COND #( WHEN iv_before = abap_true THEN 'B' ELSE 'A' ).
  ENDMETHOD.


  METHOD to_timestamp.

    DATA(lv_digits) = CONV string( iv_datetime ).
    REPLACE ALL OCCURRENCES OF PCRE '\D' IN lv_digits WITH ``.

    CHECK strlen( lv_digits ) >= 8.

    DATA(lv_date) = CONV d( lv_digits+0(8) ).
    DATA(lv_time) = COND t( WHEN strlen( lv_digits ) >= 14
                            THEN CONV t( lv_digits+8(6) )
                            ELSE iv_default_time ).

    CONVERT DATE lv_date TIME lv_time
            INTO TIME STAMP rv_timestamp TIME ZONE iv_timezone.

  ENDMETHOD.


  METHOD resolve_zone.

    rv_zone = COND #( WHEN iv_timezone IS NOT INITIAL
                      THEN iv_timezone
                      ELSE cl_abap_context_info=>get_user_time_zone( ) ).

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
