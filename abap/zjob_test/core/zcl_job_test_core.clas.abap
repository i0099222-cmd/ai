"! <p class="shorttext synchronized">배치잡 비교 테스트 코어</p>
"!
"! Application Job(ZCL_APJ_JOB_TEST)과 클래식 리포트(ZR_JOB_TEST)가 둘 다
"! 이 클래스만 호출한다. "실행 로직은 동일 / 스케줄링 방식만 다름"이라는
"! 비교 조건을 성립시키기 위해서다.
"!
"! 하는 일: 실행 컨텍스트(사용자/일자/시각/타임존/서버/잡ID)를 담은 메시지를
"! 잡 로그에 찍는다. DB 도, 업무 마스터데이터도 건드리지 않는다.
"!
"! 언어버전: ABAP for Cloud Development.
"! 그래서 sy-batch / sy-host / sy-uname 을 여기서 못 읽는다.
"! 그 값들은 Standard ABAP 인 클래식 리포트가 IS_CONTEXT 로 넘겨준다.
"! (Cloud 티어에서 못 읽는다는 사실 자체가 비교 결과 중 하나다.)
"!
"! NOTE: MESSAGE ... TYPE 'I' 는 백그라운드에서 잡 로그로 수집되지만,
"!       다이얼로그로 부르면 팝업이 뜬다. 이 클래스는 잡에서만 호출할 것.
CLASS zcl_job_test_core DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_job_test.

  PRIVATE SECTION.

    DATA mt_message TYPE zif_job_test=>tt_message.

    METHODS fill_defaults
      IMPORTING
        is_params        TYPE zif_job_test=>ty_run_params
      RETURNING
        VALUE(rs_params) TYPE zif_job_test=>ty_run_params.

    "! 잡 로그에 한 줄 찍고 요약에도 남긴다.
    METHODS emit
      IMPORTING
        iv_text TYPE string.

    "! 실행 컨텍스트 한 줄 요약 - 두 방식의 차이가 여기서 드러난다.
    METHODS context_line
      IMPORTING
        is_context     TYPE zif_job_test=>ty_context
      RETURNING
        VALUE(rv_line) TYPE string.

ENDCLASS.


CLASS zcl_job_test_core IMPLEMENTATION.

  METHOD zif_job_test~run.

    CLEAR mt_message.

    DATA(ls_params) = fill_defaults( is_params ).

    rs_summary-run_tag   = ls_params-run_tag.
    rs_summary-requested = ls_params-msg_count.

    emit( |[{ ls_params-run_tag }] START { context_line( is_context ) }| ).

    DO ls_params-msg_count TIMES.

      emit( |[{ ls_params-run_tag }] #{ sy-index } at { utclong_current( ) }| ).

      rs_summary-written = rs_summary-written + 1.

      " 실행시간을 늘려서 "실행 중" 상태와 취소를 관찰할 시간을 번다.
      " (SM37 의 잡 중지 vs Application Jobs 앱의 Cancel 이 각각 어느 시점에
      "  실제로 끊는지 - 잡 로그에 몇 번째 메시지까지 남았는지로 비교)
      " NOTE: WAIT UP TO 가 Cloud 언어버전에서 막히면 이 블록만 걷어내고
      "       msg_count 를 크게 잡아 대체한다.
      IF ls_params-sleep_secs > 0.
        WAIT UP TO ls_params-sleep_secs SECONDS.
      ENDIF.

    ENDDO.

    emit( |[{ ls_params-run_tag }] END written={ rs_summary-written }/{ rs_summary-requested }| ).

    rs_summary-t_message = mt_message.

    " 강제 오류: 잡을 "오류 종료" 상태로 만든다.
    IF ls_params-force_fail = abap_true.
      RAISE EXCEPTION NEW zcx_job_test(
        message = |[{ ls_params-run_tag }] forced failure after { rs_summary-written } message(s)| ).
    ENDIF.

  ENDMETHOD.


  METHOD fill_defaults.

    rs_params = is_params.

    IF rs_params-run_tag IS INITIAL.
      rs_params-run_tag = 'NOTAG'.
    ENDIF.

    IF rs_params-msg_count <= 0.
      rs_params-msg_count = 1.
    ENDIF.

    IF rs_params-sleep_secs < 0.
      rs_params-sleep_secs = 0.
    ENDIF.

  ENDMETHOD.


  METHOD emit.

    APPEND iv_text TO mt_message.

    " 백그라운드 실행이면 잡 로그로 수집된다.
    MESSAGE iv_text TYPE 'I'.

  ENDMETHOD.


  METHOD context_line.

    " ABAP Cloud 에서 실행 컨텍스트를 읽는 정식 경로
    rv_line = |mode={ is_context-schedule_mode } | &&
              |user={ cl_abap_context_info=>get_user_technical_name( ) } | &&
              |date={ cl_abap_context_info=>get_system_date( ) } | &&
              |time={ cl_abap_context_info=>get_system_time( ) } | &&
              |tz={ cl_abap_context_info=>get_user_time_zone( ) }|.

    " 아래는 Standard ABAP 호출자만 채워줄 수 있다.
    " -> mode=A 메시지에는 job/host/batch 가 비어 있고 mode=C 에만 찍힌다.
    IF is_context-job_name IS NOT INITIAL.
      rv_line = |{ rv_line } job={ is_context-job_name }/{ is_context-job_count }|.
    ENDIF.

    IF is_context-host IS NOT INITIAL.
      rv_line = |{ rv_line } host={ is_context-host } batch={ is_context-is_batch }|.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
