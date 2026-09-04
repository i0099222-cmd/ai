"! <p class="shorttext synchronized">예시: Application Job 실행 오브젝트</p>
"!
"! 배치 하나 = 이 형태의 클래스 하나 + 잡 카탈로그 엔트리 1개 + 잡 템플릿 1개.
"! 별도의 런처나 동적 생성이 없다. APJ 가 이 클래스를 직접 실행한다.
"!
"! 생성 순서 (ADT):
"!   1) 이 클래스 (ABAP for Cloud Development)
"!   2) Application Job Catalog Entry  ZJC_BATCH_SAMPLE -> 실행클래스 지정
"!   3) Application Job Template       ZJT_BATCH_SAMPLE -> 카탈로그 엔트리 지정
"!   4) createJob 액션에 JobTemplateName='ZJT_BATCH_SAMPLE' 로 호출
"!
"! 기존 배치 리포트 이관:
"!   리포트의 START-OF-SELECTION 로직 -> IF_APJ_RT_EXEC_OBJECT~EXECUTE
"!   셀렉션 스크린 파라미터           -> IF_APJ_DT_EXEC_OBJECT~GET_PARAMETERS
"!   배리언트                         -> 잡 템플릿 (파라미터 값 세트)
"!   WRITE 리스트                     -> MESSAGE (잡 로그)
"!
"! 이 클래스는 실제 오브젝트가 아니라 참고용 예시다.
"!
"! !! IF_APJ_* 시그니처는 릴리스마다 다르다. ADT 에서 F2 로 확인 후
"!    "TODO: 시그니처 확인" 표시된 곳만 맞출 것. !!
CLASS zcl_apj_batch_sample DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.

  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF gc_param,
        company_code TYPE c LENGTH 8 VALUE 'P_BUKRS',
        posting_date TYPE c LENGTH 8 VALUE 'P_BUDAT',
        test_run     TYPE c LENGTH 8 VALUE 'P_TEST',
      END OF gc_param.

    METHODS get_value
      IMPORTING
        it_params       TYPE if_apj_rt_exec_object=>tt_templ_val
        iv_selname      TYPE clike
      RETURNING
        VALUE(rv_value) TYPE string.

ENDCLASS.


CLASS zcl_apj_batch_sample IMPLEMENTATION.

*----------------------------------------------------------------------*
* 디자인타임 - 파라미터 정의
*   리포트의 셀렉션 스크린에 해당한다.
*   Application Jobs 앱에서 이 정의대로 입력 화면이 뜬다.
*----------------------------------------------------------------------*
  METHOD if_apj_dt_exec_object~get_parameters.
    " TODO: 시그니처 확인

    et_parameter_def = VALUE #(
      kind           = if_apj_dt_exec_object=>parameter
      changeable_ind = abap_true
      ( selname       = gc_param-company_code
        datatype      = 'CHAR' length = 4
        param_text    = '회사코드'
        mandatory_ind = abap_true )
      ( selname       = gc_param-posting_date
        datatype      = 'DATS' length = 8
        param_text    = '전기일' )
      ( selname       = gc_param-test_run
        datatype      = 'CHAR' length = 1
        param_text    = '테스트런' ) ).

    et_parameter_val = VALUE #(
      kind   = if_apj_dt_exec_object=>parameter
      sign   = 'I'
      option = 'EQ'
      ( selname = gc_param-test_run low = 'X' ) ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 디자인타임 - 검증
*   SM36 배리언트에는 없는 계층. 스케줄 저장 시점에 값을 막을 수 있다.
*----------------------------------------------------------------------*
  METHOD if_apj_dt_exec_object~check_parameters.
    " TODO: 시그니처 확인 - 파라미터명이 it_parameters / it_parameter_val 중 무엇인지

    DATA(lt_vals) = CORRESPONDING if_apj_rt_exec_object=>tt_templ_val( it_parameters ).

    IF get_value( it_params = lt_vals iv_selname = gc_param-company_code ) IS INITIAL.
      RAISE EXCEPTION NEW cx_apj_dt_content( ).
    ENDIF.

  ENDMETHOD.


*----------------------------------------------------------------------*
* 런타임 - 실제 실행
*   리포트의 START-OF-SELECTION 에 해당한다.
*----------------------------------------------------------------------*
  METHOD if_apj_rt_exec_object~execute.
    " TODO: 시그니처 확인

    DATA(lv_bukrs) = get_value( it_params  = it_parameters
                                iv_selname = gc_param-company_code ).
    DATA(lv_test)  = get_value( it_params  = it_parameters
                                iv_selname = gc_param-test_run ).

    " MESSAGE 로 남긴 내용은 잡 로그에 수집된다. WRITE 를 대신하는 자리다.
    MESSAGE |Sample batch start: bukrs={ lv_bukrs } testrun={ lv_test }| TYPE 'I'.

    " ... 업무 로직 ...
    DATA(lv_processed) = 0.

    MESSAGE |Sample batch end: processed={ lv_processed }| TYPE 'I'.

    " 실패를 알리려면 예외를 던진다. 잡이 오류 종료된다.
    " RAISE EXCEPTION NEW zcx_batch_job( message = '...' ).

  ENDMETHOD.


  METHOD get_value.

    rv_value = VALUE #( it_params[ selname = iv_selname ]-low OPTIONAL ).

  ENDMETHOD.

ENDCLASS.
