"! <p class="shorttext synchronized">Application Job 런처 (범용 실행 오브젝트)</p>
"!
"! AS-IS 의 "임의 프로그램을 스케줄하는 범용 잡 생성기"를 APJ 위에서
"! 재현하기 위한 실행 클래스.
"!
"! ** 설계의 핵심 **
"!   APJ 는 잡 카탈로그 엔트리에 등록된 클래스만 실행할 수 있다.
"!   그래서 "무엇이든 실행하는 클래스" 하나를 등록하고, 실제로 무엇을 돌릴지는
"!   파라미터로 넘긴 잡 정의 ID(P_DEFID)로 DB 에서 읽는다.
"!
"!   Job Catalog Entry  ZJC_JOB_LAUNCHER   ← 1개
"!   Job Template       ZJT_JOB_LAUNCHER   ← 1개
"!   Job (런타임)        P_DEFID 값만 다르게 해서 N개
"!
"!   APJ 파라미터(tt_templ_val)는 selname/low/high 구조라 스텝 테이블을
"!   넘길 수 없다. 그래서 스텝은 ZTJOB_STEP 에 두고 ID 만 넘기는 것이다.
"!
"! 언어버전: ABAP for Cloud Development.
"!
"! !! 주의 !!
"! IF_APJ_* 인터페이스 시그니처는 릴리스마다 다르다. ADT 에서 F2 로 확인 후
"! "TODO: 시그니처 확인" 표시된 곳만 맞출 것.
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

    "! 실행 결과를 잡 로그에 남긴다.
    METHODS log_summary
      IMPORTING
        is_summary TYPE zif_bc_job=>ty_run_summary.

    "! 실행 이력을 ZTJOB_RUN 에 기록한다.
    METHODS write_run_log
      IMPORTING
        is_summary TYPE zif_bc_job=>ty_run_summary.

ENDCLASS.


CLASS zcl_apj_job_launcher IMPLEMENTATION.

*----------------------------------------------------------------------*
* 디자인타임 - 파라미터 정의
*   딱 하나. 잡 정의 ID.
*   AS-IS 의 나머지 필드(잡명/클래스/스텝/주기/캘린더)는 전부 ZTJOB_DEF·
*   ZTJOB_STEP 에 있고, OData 서비스에서 관리한다.
*----------------------------------------------------------------------*
  METHOD if_apj_dt_exec_object~get_parameters.
    " TODO: 시그니처 확인
    "   EXPORTING et_parameter_def TYPE if_apj_dt_exec_object=>tt_templ_def
    "             et_parameter_val TYPE if_apj_dt_exec_object=>tt_templ_val

    et_parameter_def = VALUE #(
      ( selname       = zif_bc_job=>gc_param-def_id
        kind          = if_apj_dt_exec_object=>parameter
        datatype      = 'CHAR'
        length        = 32                 " sysuuid_x16 를 32자리 hex 문자열로 전달
        param_text    = '잡 정의 ID'
        changeable_ind = abap_true
        mandatory_ind  = abap_true ) ).

    " 기본값 없음 - 스케줄할 때마다 반드시 지정해야 한다.
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

    DATA(lv_def_id) = get_value( it_params  = lt_vals
                                 iv_selname = zif_bc_job=>gc_param-def_id ).

    IF lv_def_id IS INITIAL.
      RAISE EXCEPTION NEW cx_apj_dt_content( ).
    ENDIF.

    " 존재하지 않는/비활성 잡 정의는 스케줄 자체를 막는다.
    SELECT SINGLE @abap_true
      FROM ztjob_def
      WHERE def_id    = @lv_def_id
        AND is_active = @abap_true
      INTO @DATA(lv_exists).

    IF lv_exists <> abap_true.
      RAISE EXCEPTION NEW cx_apj_dt_content( ).
    ENDIF.

    " 스텝이 하나도 없으면 돌 이유가 없다.
    SELECT SINGLE @abap_true
      FROM ztjob_step
      WHERE def_id = @lv_def_id
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

    DATA(lv_def_id_str) = get_value( it_params  = it_parameters
                                     iv_selname = zif_bc_job=>gc_param-def_id ).

    IF lv_def_id_str IS INITIAL.
      MESSAGE 'Launcher: P_DEFID is empty' TYPE 'E'.
      RETURN.
    ENDIF.

    DATA lv_def_id TYPE sysuuid_x16.
    lv_def_id = lv_def_id_str.

    MESSAGE |Launcher start: def_id={ lv_def_id_str }| TYPE 'I'.

    DATA(lo_runner) = NEW zcl_bc_job_runner( ).
    DATA(ls_summary) = lo_runner->run( lv_def_id ).

    log_summary( ls_summary ).
    write_run_log( ls_summary ).

    " 스텝이 실패했으면 잡을 오류 종료시킨다.
    " Application Jobs 앱 / SM37 에서 각각 어떤 상태로 보이는지 비교 대상.
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
        WHEN zif_bc_job=>gc_skip-after_close THEN 'past close time (laststrt)'
        WHEN zif_bc_job=>gc_skip-not_workday THEN 'not a factory working day'
        WHEN zif_bc_job=>gc_skip-no_step     THEN 'no step defined'
        WHEN zif_bc_job=>gc_skip-def_missing THEN 'job definition not found or inactive'
        ELSE 'unknown' ) }| TYPE 'I'.
      RETURN.
    ENDIF.

    LOOP AT is_summary-t_step INTO DATA(ls_step).
      MESSAGE |Step { ls_step-step_no }: { ls_step-pg_id }| &&
              COND string( WHEN ls_step-pg_variant IS NOT INITIAL
                           THEN | ({ ls_step-pg_variant })| ) &&
              | -> { COND string( WHEN ls_step-success = abap_true THEN 'OK' ELSE 'NG' ) }| &&
              | { ls_step-message }|
        TYPE COND #( WHEN ls_step-success = abap_true THEN 'I' ELSE 'W' ).
    ENDLOOP.

    MESSAGE |Launcher end: executed={ is_summary-executed } | &&
            |failed={ is_summary-failed } / requested={ is_summary-requested }| TYPE 'I'.

  ENDMETHOD.


  METHOD write_run_log.

    " TODO: ZTJOB_RUN 에 실행 결과를 기록한다.
    "   스케줄 시점에 OData 액션이 만든 행을 찾아서 갱신하는 방식이 자연스럽다.
    "   현재 잡 이름/카운트를 APJ 런타임에서 얻는 표준 경로가 불명확하므로
    "   (COMPARISON #16), def_id + 실행시각으로 매칭하는 형태를 검토할 것.
    RETURN.

  ENDMETHOD.

ENDCLASS.
