*&---------------------------------------------------------------------*
*& Function Module Z_BC_CHECK_WORKDAY
*&---------------------------------------------------------------------*
*& 팩토리 캘린더 기준 작업일 판정.
*&
*& 왜 필요한가:
*&   AS-IS 는 SM36 의 "팩토리 캘린더 작업일 실행" 옵션을 쓴다
*&   (공장시간 / 공장근무일수 / 공장근무시간). APJ 반복 패턴에는
*&   이에 대응하는 옵션이 없다. (COMPARISON #12)
*&
*&   그래서 APJ 에는 "매일 실행"으로 걸고, 런처가 실행 시점에 이 FM 으로
*&   오늘이 작업일인지 판정해서 아니면 아무것도 하지 않고 종료한다.
*&   -> 잡은 매일 돌지만 실제 작업은 작업일에만 수행된다.
*&      로그에 skip 기록이 남는 것이 이 우회의 대가다.
*&
*& SE37 생성:
*&   Function Group : Z_BC_JOB_RUN (Standard ABAP 언어버전)
*&   Import : IV_DATE        TYPE SY-DATUM
*&            IV_CALENDAR_ID TYPE WFCID
*&            IV_WORKDAY_NR  TYPE I         (0 = 작업일이기만 하면 OK)
*&   Export : EV_IS_WORKDAY  TYPE ABAP_BOOL
*&            EV_MESSAGE     TYPE STRING
*&
*&   생성 후 API State 에서 Local API 로 release.
*&
*& TODO: 시그니처 확인
*&   DATE_CONVERT_TO_FACTORYDATE 의 파라미터/예외명과
*&   WORKINGDAY_INDICATOR 값 의미를 SE37 에서 확인할 것.
*&   (space = 작업일 로 알려져 있으나 시스템에서 확정 필요)
*&---------------------------------------------------------------------*
FUNCTION z_bc_check_workday.

  DATA: lv_factorydate TYPE scal-facdate,
        lv_indicator   TYPE scal-indicator,
        lv_date_out    TYPE sy-datum.

  CLEAR: ev_is_workday, ev_message.

  " 캘린더 지정이 없으면 판정하지 않는다 = 항상 실행
  IF iv_calendar_id IS INITIAL.
    ev_is_workday = abap_true.
    ev_message    = 'No factory calendar - always run'.
    RETURN.
  ENDIF.

  CALL FUNCTION 'DATE_CONVERT_TO_FACTORYDATE'
    EXPORTING
      correct_option               = '+'
      date                         = iv_date
      factory_calendar_id          = iv_calendar_id
    IMPORTING
      date                         = lv_date_out
      factorydate                  = lv_factorydate
      workingday_indicator         = lv_indicator
    EXCEPTIONS
      calendar_buffer_not_loadable = 1
      correct_option_invalid       = 2
      date_after_range             = 3
      date_before_range            = 4
      date_invalid                 = 5
      factory_calendar_not_found   = 6
      OTHERS                       = 7.

  IF sy-subrc <> 0.
    ev_is_workday = abap_false.
    ev_message    = |Factory calendar { iv_calendar_id } check failed (subrc={ sy-subrc })|.
    RETURN.
  ENDIF.

  " WORKINGDAY_INDICATOR: space = 해당 일자가 작업일
  IF lv_indicator IS NOT INITIAL.
    ev_is_workday = abap_false.
    ev_message    = |{ iv_date } is not a working day in calendar { iv_calendar_id }|.
    RETURN.
  ENDIF.

  " 작업일 번호 지정이 있으면 "그 달의 n번째 작업일"인지까지 본다.
  " 0 이면 작업일이기만 하면 통과.
  IF iv_workday_nr > 0.
    DATA(lv_month_first) = CONV sy-datum( |{ iv_date+0(6) }01| ).
    DATA lv_first_facdate TYPE scal-facdate.

    CALL FUNCTION 'DATE_CONVERT_TO_FACTORYDATE'
      EXPORTING
        correct_option               = '+'
        date                         = lv_month_first
        factory_calendar_id          = iv_calendar_id
      IMPORTING
        factorydate                  = lv_first_facdate
      EXCEPTIONS
        OTHERS                       = 7.

    IF sy-subrc <> 0.
      ev_is_workday = abap_false.
      ev_message    = 'Cannot determine workday number'.
      RETURN.
    ENDIF.

    DATA(lv_nr_in_month) = lv_factorydate - lv_first_facdate + 1.

    IF lv_nr_in_month <> iv_workday_nr.
      ev_is_workday = abap_false.
      ev_message    = |Workday no. { lv_nr_in_month } (expected { iv_workday_nr })|.
      RETURN.
    ENDIF.
  ENDIF.

  ev_is_workday = abap_true.
  ev_message    = |{ iv_date } is working day (factorydate { lv_factorydate })|.

ENDFUNCTION.
