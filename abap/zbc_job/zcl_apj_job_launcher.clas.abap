"! <p class="shorttext synchronized">Application Job 실행 오브젝트 (런처)</p>
"!
"! AS-IS 의 "화면에서 고른 임의 프로그램을 스케줄" 을 APJ 위에서 재현하기 위한
"! 유일한 실행 클래스.
"!
"! ** 왜 런처인가 **
"!   APJ 는 잡 카탈로그 엔트리에 등록된 클래스만 실행한다. 실행할 프로그램이
"!   화면에서 정해지므로 카탈로그를 미리 만들 수 없다. 그래서 "무엇이든
"!   실행하는" 클래스 하나만 등록하고, 무엇을 돌릴지는 파라미터로 받는다.
"!
"!   Job Catalog Entry  ZJC_BC_JOB   ← 1개
"!   Job Template       ZJT_BC_JOB   ← 1개
"!   Job (런타임)        P_RUNID 값만 다르게 해서 N 개
"!
"!   대가: APJ 의 카탈로그 화이트리스트(보안 통제)를 우회하게 된다.
"!         실행 가능 프로그램 통제는 check_parameters 와 업무 권한으로 해야 한다.
"!
"! 언어버전: ABAP for Cloud Development.
"!
"! !! IF_APJ_* 시그니처는 릴리스마다 다르다. ADT 에서 F2 로 확인 후
"!    "TODO: 시그니처 확인" 표시된 곳만 맞출 것. !!
CLASS zcl_apj_job_launcher DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.

  PRIVATE SECTION.

    METHODS get_value
      IMPORTING
        it_params       TYPE if_apj_rt_exec_object=>tt_templ_val
        iv_selname      TYPE clike
      RETURNING
        VALUE(rv_value) TYPE string.

    METHODS log_summary
      IMPORTING
        is_summary TYPE zif_bc_job=>ty_run_summary.

ENDCLASS.


CLASS zcl_apj_job_launcher IMPLEMENTATION.

*----------------------------------------------------------------------*
* 디자인타임 - 파라미터 정의
*   딱 하나. 스케줄 행 UUID.
*   AS-IS 의 나머지 필드(잡명/클래스/스텝/주기/캘린더)는 전부 ZTJOB_RUN·
*   ZTJOB_STEP 에 있고 OData 서비스가 관리한다.
*----------------------------------------------------------------------*
  METHOD if_apj_dt_exec_object~get_parameters.
    " TODO: 시그니처 확인

    et_parameter_def = VALUE #(
      ( selname        = zif_bc_job=>gc_param-run_id
        kind           = if_apj_dt_exec_object=>parameter
        datatype       = 'CHAR'
        length         = 32                 " sysuuid_x16 을 32자리 hex 로 전달
        param_text     = '스케줄 ID'
        changeable_ind = abap_true
        mandatory_ind  = abap_true ) ).

    " 기본값 없음 - 스케줄할 때마다 반드시 지정된다.
    CLEAR et_parameter_val.

  ENDMETHOD.


*----------------------------------------------------------------------*
* 디자인타임 - 검증
*   AS-IS 는 BDC 화면이 걸러주던 것을 여기서 코드로 막는다.
*   SM36 배리언트에는 없는 계층이다. (COMPARISON A2)
*----------------------------------------------------------------------*
  METHOD if_apj_dt_exec_object~check_parameters.
    " TODO: 시그니처 확인 - 파라미터명이 it_parameters / it_parameter_val 중 무엇인지

    DATA(lt_vals) = CORRESPONDING if_apj_rt_exec_object=>tt_templ_val( it_parameters ).

    DATA(lv_run_id) = get_value( it_params  = lt_vals
                                 iv_selname = zif_bc_job=>gc_param-run_id ).

    IF lv_run_id IS INITIAL.
      RAISE EXCEPTION NEW cx_apj_dt_content( ).
    ENDIF.

    SELECT SINGLE @abap_true FROM ztjob_run
      WHERE run_uuid = @lv_run_id
      INTO @DATA(lv_exists).

    IF lv_exists <> abap_true.
      RAISE EXCEPTION NEW cx_apj_dt_content( ).
    ENDIF.

    " 스텝이 하나도 없으면 돌 이유가 없다.
    SELECT SINGLE @abap_true FROM ztjob_step
      WHERE run_uuid = @lv_run_id
      INTO @DATA(lv_has_step).

    IF lv_has_step <> abap_true.
      RAISE EXCEPTION NEW cx_apj_dt_content( ).
    ENDIF.

  ENDMETHOD.


*----------------------------------------------------------------------*
* 런타임 - 실행
*----------------------------------------------------------------------*
  METHOD if_apj_rt_exec_object~execute.
    " TODO: 시그니처 확인 - IMPORTING it_parameters TYPE if_apj_rt_exec_object=>tt_templ_val

    DATA(lv_run_id_str) = get_value( it_params  = it_parameters
                                     iv_selname = zif_bc_job=>gc_param-run_id ).

    IF lv_run_id_str IS INITIAL.
      MESSAGE 'Launcher: P_RUNID is empty' TYPE 'E'.
      RETURN.
    ENDIF.

    DATA lv_run_uuid TYPE sysuuid_x16.
    lv_run_uuid = lv_run_id_str.

    MESSAGE |Launcher start: run_id={ lv_run_id_str }| TYPE 'I'.

    DATA(ls_summary) = NEW zcl_bc_job_runner( )->run( lv_run_uuid ).

    log_summary( ls_summary ).

    " 스텝이 실패했으면 잡을 오류 종료시킨다.
    " Application Jobs 앱 / SM37 에서 각각 어떤 상태로 보이는지가 비교 항목 #15.
    IF ls_summary-failed > 0.
      MESSAGE |Launcher: { ls_summary-failed } step(s) failed| TYPE 'E'.
    ENDIF.

  ENDMETHOD.


*----------------------------------------------------------------------*
* 헬퍼
*----------------------------------------------------------------------*
  METHOD get_value.

    rv_value = VALUE #( it_params[ selname = iv_selname ]-low OPTIONAL ).

  ENDMETHOD.


  METHOD log_summary.

    IF is_summary-skipped = abap_true.
      MESSAGE |Launcher SKIPPED: { SWITCH string( is_summary-skip_reason
        WHEN zif_bc_job=>gc_skip-after_close THEN 'past close time (last_start)'
        WHEN zif_bc_job=>gc_skip-not_workday THEN 'not a factory working day'
        WHEN zif_bc_job=>gc_skip-no_step     THEN 'no step defined'
        WHEN zif_bc_job=>gc_skip-run_missing THEN 'schedule row not found'
        ELSE 'unknown' ) }| TYPE 'I'.
      RETURN.
    ENDIF.

    LOOP AT is_summary-t_step INTO DATA(ls_step).
      MESSAGE |Step { ls_step-step_no }: { ls_step-pg_id } -> | &&
              |{ COND string( WHEN ls_step-success = abap_true THEN 'OK' ELSE 'NG' ) } | &&
              |{ ls_step-message }|
        TYPE COND #( WHEN ls_step-success = abap_true THEN 'I' ELSE 'W' ).
    ENDLOOP.

    MESSAGE |Launcher end: executed={ is_summary-executed } | &&
            |failed={ is_summary-failed } / requested={ is_summary-requested }| TYPE 'I'.

  ENDMETHOD.

ENDCLASS.
