"! <p class="shorttext synchronized">Application Job 실행 클래스 (비교 테스트)</p>
"!
"! Application Job Framework(APJ)의 실행 오브젝트.
"!   IF_APJ_DT_EXEC_OBJECT : 디자인타임 - 잡 템플릿에 노출할 파라미터 정의/검증
"!   IF_APJ_RT_EXEC_OBJECT : 런타임    - 실제 실행(EXECUTE)
"!
"! 생성 순서는 apj/CATALOG_TEMPLATE.md 참고.
"!
"! !! 주의 !!
"! IF_APJ_* 인터페이스의 파라미터 이름/타입은 릴리스·SP 레벨에 따라 다르다.
"! ADT 에서 인터페이스에 커서 두고 F2 로 실제 시그니처를 확인한 뒤,
"! "TODO: 시그니처 확인" 표시된 곳만 맞추면 된다.
CLASS zcl_apj_job_test DEFINITION
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

    METHODS map_parameters
      IMPORTING
        it_params        TYPE if_apj_rt_exec_object=>tt_templ_val
      RETURNING
        VALUE(rs_params) TYPE zif_job_test=>ty_run_params.

ENDCLASS.


CLASS zcl_apj_job_test IMPLEMENTATION.

*----------------------------------------------------------------------*
* 디자인타임 - 잡 템플릿에 보여줄 파라미터 정의 + 기본값
*   비교 포인트: SM36 은 "리포트 배리언트"를 쓰지만 APJ 는 이 메서드가
*   파라미터 화면을 코드로 만든다. 배리언트 개념 자체가 없다.
*----------------------------------------------------------------------*
  METHOD if_apj_dt_exec_object~get_parameters.
    " TODO: 시그니처 확인
    "   IMPORTING iv_job_catalog_entry_name
    "   EXPORTING et_parameter_def TYPE if_apj_dt_exec_object=>tt_templ_def
    "             et_parameter_val TYPE if_apj_dt_exec_object=>tt_templ_val

    et_parameter_def = VALUE #(
      kind           = if_apj_dt_exec_object=>parameter
      changeable_ind = abap_true
      ( selname       = zif_job_test=>gc_param-run_tag
        datatype      = 'CHAR'  length = 20
        param_text    = '테스트 태그'
        mandatory_ind = abap_true )
      ( selname       = zif_job_test=>gc_param-rec_count
        datatype      = 'INT4'  length = 10
        param_text    = '프로브 건수' )
      ( selname       = zif_job_test=>gc_param-sleep_secs
        datatype      = 'INT4'  length = 10
        param_text    = '건별 지연(초)' )
      ( selname       = zif_job_test=>gc_param-force_fail
        datatype      = 'CHAR'  length = 1
        param_text    = '강제 오류' ) ).

    " 잡 템플릿을 열었을 때 미리 채워질 기본값
    et_parameter_val = VALUE #(
      kind   = if_apj_dt_exec_object=>parameter
      sign   = 'I'
      option = 'EQ'
      ( selname = zif_job_test=>gc_param-run_tag    low = 'APJ-DEFAULT' )
      ( selname = zif_job_test=>gc_param-rec_count  low = '3' )
      ( selname = zif_job_test=>gc_param-sleep_secs low = '0' )
      ( selname = zif_job_test=>gc_param-force_fail low = space ) ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 디자인타임 - 스케줄 저장 시점의 파라미터 검증
*   비교 포인트: SM36 은 배리언트를 저장할 때 업무 검증을 걸 수 없다.
*   APJ 는 여기서 막을 수 있다. (Application Job 쪽 우위 항목)
*----------------------------------------------------------------------*
  METHOD if_apj_dt_exec_object~check_parameters.
    " TODO: 시그니처 확인 - 파라미터명이 it_parameters / it_parameter_val 중
    "       무엇인지 확인 후 아래 변수명만 맞출 것.

    DATA(lt_vals) = CORRESPONDING if_apj_rt_exec_object=>tt_templ_val( it_parameters ).

    DATA(lv_count) = get_value( it_params = lt_vals iv_selname = zif_job_test=>gc_param-rec_count ).
    IF lv_count IS NOT INITIAL AND ( CONV i( lv_count ) < 1 OR CONV i( lv_count ) > 1000 ).
      " TODO: CX_APJ_DT_CONTENT 의 textid 를 시스템에서 확인해 지정하면
      "       Fiori 화면에 사유가 표시된다.
      RAISE EXCEPTION NEW cx_apj_dt_content( ).
    ENDIF.

    DATA(lv_tag) = get_value( it_params = lt_vals iv_selname = zif_job_test=>gc_param-run_tag ).
    IF lv_tag IS INITIAL.
      RAISE EXCEPTION NEW cx_apj_dt_content( ).
    ENDIF.

  ENDMETHOD.


*----------------------------------------------------------------------*
* 런타임 - 실제 실행
*----------------------------------------------------------------------*
  METHOD if_apj_rt_exec_object~execute.
    " TODO: 시그니처 확인 - IMPORTING it_parameters TYPE if_apj_rt_exec_object=>tt_templ_val

    DATA(ls_params) = map_parameters( it_parameters ).

    " 비교 포인트: APJ 실행 컨텍스트에서 현재 잡 이름/카운트를 얻는 표준 경로가
    " SM36 쪽만큼 명확하지 않다. 잡 이름은 프레임워크가 자동 생성하며
    " 사용자가 지정할 수 없다. -> ZTJOB_PROBE 의 job_name 이 비는지,
    " SM37 에서 어떤 이름으로 보이는지 확인하는 것이 테스트 항목 #16.
    DATA(ls_context) = VALUE zif_job_test=>ty_context(
      schedule_mode = zif_job_test=>gc_mode-app_job ).

    MESSAGE |APJ start: tag={ ls_params-run_tag } count={ ls_params-rec_count } | &&
            |sleep={ ls_params-sleep_secs } fail={ ls_params-force_fail }| TYPE 'I'.

    TRY.

        DATA(lo_core) = NEW zcl_job_test_core( ).
        DATA(ls_summary) = lo_core->zif_job_test~run( is_params  = ls_params
                                                      is_context = ls_context ).

        MESSAGE |APJ end: written={ ls_summary-written } / | &&
                |requested={ ls_summary-requested }| TYPE 'I'.

      CATCH zcx_job_test INTO DATA(lx_job).
        " 예외를 다시 던지면 잡이 오류 종료된다.
        " Application Jobs 앱 상태 vs SM37 상태를 비교할 것.
        MESSAGE lx_job->message TYPE 'E'.

    ENDTRY.

  ENDMETHOD.


*----------------------------------------------------------------------*
* 헬퍼
*----------------------------------------------------------------------*
  METHOD get_value.

    rv_value = VALUE #( it_params[ selname = iv_selname ]-low OPTIONAL ).

  ENDMETHOD.


  METHOD map_parameters.

    rs_params-run_tag    = get_value( it_params  = it_params
                                      iv_selname = zif_job_test=>gc_param-run_tag ).
    rs_params-force_fail = xsdbool( get_value( it_params  = it_params
                                               iv_selname = zif_job_test=>gc_param-force_fail ) = 'X' ).

    DATA(lv_count) = get_value( it_params = it_params iv_selname = zif_job_test=>gc_param-rec_count ).
    IF lv_count IS NOT INITIAL.
      rs_params-rec_count = CONV i( lv_count ).
    ENDIF.

    DATA(lv_sleep) = get_value( it_params = it_params iv_selname = zif_job_test=>gc_param-sleep_secs ).
    IF lv_sleep IS NOT INITIAL.
      rs_params-sleep_secs = CONV i( lv_sleep ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
