"! <p class="shorttext synchronized">배치잡 비교 테스트 코어</p>
"!
"! Application Job(ZCL_APJ_JOB_TEST)과 클래식 리포트(ZR_JOB_TEST)가 둘 다
"! 이 클래스만 호출한다. "실행 로직은 동일 / 스케줄링 방식만 다름"이라는
"! 비교 조건을 성립시키기 위해서다.
"!
"! 하는 일: 실행 컨텍스트(사용자/시각/타임존/서버/잡ID)를 ZTJOB_PROBE 에 기록.
"! 업무 마스터데이터 의존이 전혀 없어서 어느 시스템에서도 바로 돌릴 수 있다.
"!
"! 언어버전: ABAP for Cloud Development.
"! 그래서 sy-batch / sy-host / sy-uname 같은 필드는 여기서 못 읽는다.
"! 그 값들은 Standard ABAP 인 클래식 리포트가 IS_CONTEXT 로 넘겨준다.
"! (Cloud 티어에서 못 읽는다는 사실 자체가 비교 결과 중 하나다.)
CLASS zcl_job_test_core DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_job_test.

  PRIVATE SECTION.

    METHODS fill_defaults
      IMPORTING
        is_params        TYPE zif_job_test=>ty_run_params
      RETURNING
        VALUE(rs_params) TYPE zif_job_test=>ty_run_params.

    METHODS build_probe
      IMPORTING
        is_params      TYPE zif_job_test=>ty_run_params
        is_context     TYPE zif_job_test=>ty_context
        iv_seq_no      TYPE i
      RETURNING
        VALUE(rs_probe) TYPE ztjob_probe
      RAISING
        zcx_job_test.

ENDCLASS.


CLASS zcl_job_test_core IMPLEMENTATION.

  METHOD zif_job_test~run.

    DATA(ls_params) = fill_defaults( is_params ).

    rs_summary-run_tag   = ls_params-run_tag.
    rs_summary-requested = ls_params-rec_count.
    rs_summary-started   = utclong_current( ).

    DO ls_params-rec_count TIMES.

      DATA(lv_seq) = sy-index.

      DATA(ls_probe) = build_probe( is_params  = ls_params
                                    is_context = is_context
                                    iv_seq_no  = lv_seq ).

      INSERT ztjob_probe FROM @ls_probe.

      " 잡이 중간에 취소됐을 때 "몇 번째까지 커밋됐는지" 보려면 건별 커밋이어야 한다.
      " (SM37 의 잡 중지 vs Application Jobs 앱의 Cancel 이 각각 어느 시점에
      "  실제로 끊는지 비교 - COMPARISON.md 항목 #14)
      COMMIT WORK.

      rs_summary-written = rs_summary-written + 1.

      APPEND VALUE #( seq_no  = lv_seq
                      stamp   = ls_probe-exec_stamp
                      message = |probe { lv_seq } written| )
             TO rs_summary-t_result.

      " 실행시간을 늘려서 "실행 중" 상태와 취소를 관찰할 시간을 번다.
      " NOTE: WAIT UP TO 가 Cloud 언어버전에서 막히면, 이 블록만
      "       Standard ABAP FM 으로 빼거나 rec_count 를 늘려 대체한다.
      IF ls_params-sleep_secs > 0.
        WAIT UP TO ls_params-sleep_secs SECONDS.
      ENDIF.

    ENDDO.

    rs_summary-finished = utclong_current( ).

    " 강제 오류: 잡을 "오류 종료" 상태로 만든다.
    IF ls_params-force_fail = abap_true.
      rs_summary-failed = abap_true.
      RAISE EXCEPTION NEW zcx_job_test(
        message = |Forced failure after { rs_summary-written } probe(s) | &&
                  |(run_tag={ ls_params-run_tag })| ).
    ENDIF.

  ENDMETHOD.


  METHOD fill_defaults.

    rs_params = is_params.

    IF rs_params-run_tag IS INITIAL.
      rs_params-run_tag = 'NOTAG'.
    ENDIF.

    IF rs_params-rec_count <= 0.
      rs_params-rec_count = 1.
    ENDIF.

    IF rs_params-sleep_secs < 0.
      rs_params-sleep_secs = 0.
    ENDIF.

  ENDMETHOD.


  METHOD build_probe.

    TRY.
        DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error INTO DATA(lx_uuid).
        RAISE EXCEPTION NEW zcx_job_test( message  = |UUID creation failed|
                                          previous = lx_uuid ).
    ENDTRY.

    rs_probe = VALUE #(
      probe_uuid    = lv_uuid
      run_tag       = is_params-run_tag
      seq_no        = iv_seq_no

      schedule_mode = is_context-schedule_mode
      job_name      = is_context-job_name
      job_count     = is_context-job_count

      " ABAP Cloud 에서 실행 컨텍스트를 읽는 정식 경로
      exec_user     = cl_abap_context_info=>get_user_technical_name( )
      exec_stamp    = utclong_current( )
      exec_date     = cl_abap_context_info=>get_system_date( )
      exec_time     = cl_abap_context_info=>get_system_time( )
      user_timezone = cl_abap_context_info=>get_user_time_zone( )

      " 아래 두 개는 Standard ABAP 호출자만 채워줄 수 있다
      host          = is_context-host
      is_batch      = is_context-is_batch

      message       = |mode={ is_context-schedule_mode } seq={ iv_seq_no }| ).

  ENDMETHOD.

ENDCLASS.
