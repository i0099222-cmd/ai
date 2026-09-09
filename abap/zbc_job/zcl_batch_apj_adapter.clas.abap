"! <p class="shorttext synchronized">Application Job API 어댑터 (CL_APJ_RT_API 래퍼)</p>
"!
"! 액션과 작업 클래스가 CL_APJ_RT_API 를 직접 부르지 않고 이 클래스만 부른다.
"! 실행 대상은 잡 템플릿이 결정한다 (템플릿 -> 카탈로그 엔트리 -> 실행 클래스).
"! 릴리스마다 달라질 수 있는 APJ API 시그니처를 한 파일에 가두기 위해서다.
"! 시스템에 맞춰야 할 곳은 "TODO: 시그니처 확인" 으로 표시했다.
"!
"! 메서드 셋이 곧 APJ 호출 셋이다. 보조 메서드를 두지 않는다 - 한 호출이
"! 무엇을 어떤 순서로 조립하는지 그 메서드 안에서 다 읽히도록 한다.
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
    "! @parameter is_start    | 시작 조건 + 반복 + 제한 조건.
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

    "! 내부에서 COMMIT CONNECTION 을 하므로 RAP BO 가 활성인 동안 부르면
    "! 덤프난다. 반드시 자식 세션(ZCL_BATCH_APJ_TASK)에서 부를 것.
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

*----------------------------------------------------------------------*
* 타임존 - AS-IS 시스템 zone시간
*   시작 시각 해석과 반복 계산의 기준이다. 지정이 없으면 사용자 타임존.
*----------------------------------------------------------------------*
        DATA(lv_zone) = COND timezone(
          WHEN is_start-timezone IS NOT INITIAL
          THEN is_start-timezone
          ELSE cl_abap_context_info=>get_user_time_zone( ) ).

        DATA lv_date TYPE d.
        DATA lv_time TYPE t.

*----------------------------------------------------------------------*
* 시작 조건 - TY_START_INFO
*   START_IMMEDIATELY 와 TIMESTAMP 둘뿐이다. 날짜/시각을 따로 넘길 수
*   없으므로 하나의 타임스탬프로 합친다.
*
*   AS-IS 형식 CHAR(15) 를 그대로 받아 숫자만 뽑고, 앞 8자리를 날짜,
*   다음 6자리를 시각으로 읽는다. 구분자가 있든 없든 동작한다.
*   시각이 없으면 그 날의 시작(00:00:00)으로 본다.
*
*   ** 타임존은 APJ 가 처리해주지 않는다. ** 요청 타임존 기준 시각을
*   우리가 UTC 타임스탬프로 바꿔서 넣어야 한다.
*----------------------------------------------------------------------*
        DATA ls_start_info TYPE cl_apj_rt_api=>ty_start_info.

        DATA(lv_digits) = CONV string( is_start-start_datetime ).
        REPLACE ALL OCCURRENCES OF PCRE '\D' IN lv_digits WITH ``.

        IF is_start-start_immediately = abap_true OR strlen( lv_digits ) < 8.

          " 시작일도 즉시실행도 없으면 지금 건다.
          ls_start_info-start_immediately = abap_true.

        ELSE.

          lv_date = lv_digits+0(8).
          lv_time = COND #( WHEN strlen( lv_digits ) >= 14
                            THEN lv_digits+8(6) ELSE '000000' ).

          CONVERT DATE lv_date TIME lv_time
                  INTO TIME STAMP ls_start_info-timestamp TIME ZONE lv_zone.

        ENDIF.

        DATA ls_sched TYPE cl_apj_rt_api=>ty_scheduling_info.

        ls_sched-timezone = lv_zone.

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
        TYPES: BEGIN OF ty_unit,
                 value       TYPE i,
                 granularity TYPE string,
               END OF ty_unit.

        DATA(lt_unit) = VALUE STANDARD TABLE OF ty_unit WITH EMPTY KEY(
          ( value = is_start-prd_mins   granularity = 'MINUTE' )
          ( value = is_start-prd_hours  granularity = 'HOUR'   )
          ( value = is_start-prd_days   granularity = 'DAY'    )
          ( value = is_start-prd_weeks  granularity = 'WEEK'   )
          ( value = is_start-prd_months granularity = 'MONTH'  ) ).

        DELETE lt_unit WHERE value <= 0.

        IF lines( lt_unit ) > 1.
          rs_result-message =
            |반복 주기는 한 단위만 지정할 수 있다. APJ 는 합산 주기를 | &&
            |표현하지 못한다: | &&
            concat_lines_of( table = VALUE string_table(
                               FOR u IN lt_unit ( |{ u-granularity } { u-value }| ) )
                             sep = ` + ` ).
          RETURN.
        ENDIF.

        IF lt_unit IS NOT INITIAL.
          ls_sched-periodic_granularity = lt_unit[ 1 ]-granularity.
          ls_sched-periodic_value       = lt_unit[ 1 ]-value.
        ENDIF.

*----------------------------------------------------------------------*
* 종료 조건 - AS-IS 배치잡 close시간
*   BY : 이 시각 이후로는 더 스케줄하지 않는다. 이미 시작된 실행을
*        중단시키는 것이 아니다 - SM36 의 laststrtdt/tm 과 같은 의미다.
*
*        날짜만 들어오면 그 날 23:59:59 로 본다. 00:00:00 으로 읽으면
*        "9월 7일까지" 가 9월 6일까지가 되어 하루가 잘린다.
*
*   close시간이 없으면 END_INFO 를 통째로 비워 둔다. TYPE = 'NONE' 을
*   명시하지 않는 이유는 값 도메인이 미확인이기 때문이고, 구조 전체가
*   초기값이면 "지정 안 함" 으로 읽히는 것이 일반적이다.
*
*   AFTER(N회 실행 후 종료)는 AS-IS 에 대응 값이 없어 쓰지 않는다.
*
* TODO: 시그니처 확인 - END_INFO 가 TY_SCHEDULING_INFO 의 컴포넌트인지
*       별도 파라미터인지, 그리고 TYPE 의 값(NONE / BY).
*----------------------------------------------------------------------*
        lv_digits = CONV string( is_start-end_datetime ).
        REPLACE ALL OCCURRENCES OF PCRE '\D' IN lv_digits WITH ``.

        IF strlen( lv_digits ) >= 8.

          lv_date = lv_digits+0(8).
          lv_time = COND #( WHEN strlen( lv_digits ) >= 14
                            THEN lv_digits+8(6) ELSE '235959' ).

          ls_sched-end_info-type = 'BY'.
          CONVERT DATE lv_date TIME lv_time
                  INTO TIME STAMP ls_sched-end_info-timestamp TIME ZONE lv_zone.

        ENDIF.

*----------------------------------------------------------------------*
* 제한 조건 - AS-IS SM36 Restrictions 팝업
*
*   두 구조의 역할이 겹치지 않는다.
*     EXCEPTION{ calendar_id, start_restriction_code }
*        고른 날이 비근무일일 때 어떻게 할지.
*        달력이 없으면 근무일 판정 자체가 불가능하므로 나머지도 무의미하다.
*     MONTH_INFO{ day, use_working_days_ind, shift_direction, week_number }
*        그 달의 어느 날에 돌릴지. WEEK_NUMBER 는 AS-IS 대응이 없어 안 쓴다.
*
*   AS-IS 는 WDAYNO(공장근무일수) + BOFMONTH/EOFMONTH 로
*   "월초부터 / 월말부터 N 번째 작업일" 을 지정한다.
*   BOFMONTH/EOFMONTH 는 실행일 자체가 아니라 세는 방향이다.
*
* TODO: 시그니처 확인 - SHIFT_DIRECTION 의 값 (NUMC 2, 도메인 고정값 없음).
*       의미는 확인됐다 - 작업일 기준 시작일을 어느 쪽에서 세는지.
*       01/02 는 추측이라 월초 기준으로 걸어 SM37 실행일로 판정할 것.
*----------------------------------------------------------------------*
        IF is_start-calendar_id IS NOT INITIAL.
          ls_sched-exception-calendar_id = is_start-calendar_id.
          " D(건너뜀) / B(앞당김) / A(미룸) / N(제한없음).
          " AS-IS 는 채우지 않아 보통 비고, 그러면 APJ 기본 동작을 따른다.
          ls_sched-exception-start_restriction_code = is_start-start_restriction.
        ENDIF.

*       작업일로 세려면 달력이 있어야 한다. AS-IS 는 공장시간(달력) 하나가
*       블록 전체의 게이트라 이 조합이 아예 안 나오지만, 우리 API 는 두 값을
*       따로 받으므로 여기서 막는다. 기준 없이 "작업일" 을 세면 APJ 가
*       기본 달력으로 조용히 돌아 요청과 다른 날에 걸린다.
        IF is_start-use_working_days = abap_true AND is_start-calendar_id IS INITIAL.
          rs_result-message = |작업일 기준으로 세려면 공장달력(CalendarId)이 필요하다.|.
          RETURN.
        ENDIF.

        IF is_start-month_day > 0.

          ls_sched-month_info-day                  = is_start-month_day.
          ls_sched-month_info-use_working_days_ind = is_start-use_working_days.

*         SHIFT_DIRECTION 은 "작업일 기준 시작일을 어느 쪽에서 세는지" 다.
*         작업일로 셀 때만 의미가 있으므로 그때만 채운다. 달력일로 셀 때
*         방향을 넣으면 뜻이 없고, 반대로 작업일인데 비워 두면 방향 없이
*         세라는 요청이 된다.
          IF is_start-use_working_days = abap_true.
            ls_sched-month_info-shift_direction =
              COND #( WHEN is_start-count_from_end = abap_true
                      THEN zif_batch_job=>gc_shift-from_month_end     " 월말에서 역순
                      ELSE zif_batch_job=>gc_shift-from_month_start ). " 월초에서 순서
          ENDIF.

        ENDIF.

*       미사용: WEEKDAY_INFO(요일 지정), TEST_MODE. AS-IS 대응이 없다.

*----------------------------------------------------------------------*
* 잡 파라미터
*   PARAM 의 JSON 은 IT_JOB_PARAMETER_VALUE 타입을 그대로 직렬화한 것이라
*   역직렬화 한 줄이면 끝이고 변환이 없다.
*
*   [{ "name":"P_MODU", "t_value":[{ "sign":"I","option":"EQ","low":"SD" }] }]
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
            is_scheduling_info     = ls_sched
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
