"! <p class="shorttext synchronized">예시: Application Job 실행 클래스</p>
"!
"! 배치 하나 = 이 클래스 1개 + 잡 카탈로그 엔트리 1개 + 잡 템플릿 1개.
"! 런처도 동적 생성도 없다. APJ 가 이 클래스를 직접 실행한다.
"!
"! 생성 순서 (ADT)
"!   1) 이 클래스 (ABAP for Cloud Development)
"!   2) Job Catalog Entry  ZJC_BATCH_SAMPLE  -> 실행 클래스 지정
"!   3) Job Template       ZJT_BATCH_SAMPLE  -> 카탈로그 엔트리 지정
"!   4) scheduleJob 액션에 JobTemplateName = 'ZJT_BATCH_SAMPLE' 로 호출
"!
"! 리포트 이관
"!   START-OF-SELECTION  -> IF_APJ_RT_EXEC_OBJECT~EXECUTE( )
"!   셀렉션 스크린        -> GET_PARAMETERS( )
"!   배리언트             -> 잡 템플릿의 파라미터 값
"!   WRITE                -> MESSAGE (잡 로그)
"!
"! 반복 주기가 짧은데 실행이 길어지면 앞 회차가 끝나기 전에 다음 회차가
"! 시작된다. APJ 는 이걸 막아주지 않으므로 ZCL_BATCH_LOCK 으로 막는다.
"! 필요 없는 배치는 그 네 줄을 빼면 된다.
"!
"! 참고용 예시다. IF_APJ_* 시그니처는 릴리스마다 다르니
"! "TODO: 시그니처 확인" 표시된 곳만 ADT 에서 맞출 것.
CLASS zcl_apj_batch_sample DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.

  PRIVATE SECTION.

    " 잠금 단위. 같은 키끼리 겹치지 않는다.
    CONSTANTS c_lock_key TYPE ztbatch_lock-lock_key VALUE 'BATCH_SAMPLE'.

    CONSTANTS:
      BEGIN OF c_param,
        company_code TYPE c LENGTH 8 VALUE 'P_BUKRS',
        posting_date TYPE c LENGTH 8 VALUE 'P_BUDAT',
        test_run     TYPE c LENGTH 8 VALUE 'P_TEST',
      END OF c_param.

ENDCLASS.


CLASS zcl_apj_batch_sample IMPLEMENTATION.

*----------------------------------------------------------------------*
* 실행 - 리포트의 START-OF-SELECTION 자리
*----------------------------------------------------------------------*
  METHOD if_apj_rt_exec_object~execute.
    " TODO: 시그니처 확인

*   이미 돌고 있으면 이번 회차는 거른다.
*   푸는 코드는 없다 - 잡이 끝나면 잠금도 같이 풀린다.
    DATA(lo_lock) = NEW zcl_batch_lock( c_lock_key ).

    IF lo_lock->acquire( ) = abap_false.
      MESSAGE |이미 실행 중이라 건너뜁니다: { c_lock_key }| TYPE 'I'.
      RETURN.
    ENDIF.

    DATA(lv_bukrs) = VALUE #( it_parameters[ selname = c_param-company_code ]-low OPTIONAL ).
    DATA(lv_test)  = VALUE #( it_parameters[ selname = c_param-test_run ]-low OPTIONAL ).

    " MESSAGE 로 남긴 내용이 잡 로그가 된다. WRITE 를 대신하는 자리다.
    MESSAGE |처리 시작 bukrs={ lv_bukrs } testrun={ lv_test }| TYPE 'I'.

    " ... 실제 처리 ...
    DATA(lv_count) = 0.

    MESSAGE |처리 건수 { lv_count }| TYPE 'I'.

    " 실패는 예외로 알린다. 잡이 오류 종료되고 잠금도 풀린다.
    " RAISE EXCEPTION NEW zcx_batch_job( message = '...' ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 파라미터 정의 - 리포트의 셀렉션 스크린 자리
*   Application Jobs 앱에서 이 정의대로 입력 화면이 뜬다.
*----------------------------------------------------------------------*
  METHOD if_apj_dt_exec_object~get_parameters.
    " TODO: 시그니처 확인

    et_parameter_def = VALUE #(
      kind           = if_apj_dt_exec_object=>parameter
      changeable_ind = abap_true
      ( selname       = c_param-company_code
        datatype      = 'CHAR' length = 4
        param_text    = '회사코드'
        mandatory_ind = abap_true )
      ( selname       = c_param-posting_date
        datatype      = 'DATS' length = 8
        param_text    = '전기일' )
      ( selname       = c_param-test_run
        datatype      = 'CHAR' length = 1
        param_text    = '테스트런' ) ).

    et_parameter_val = VALUE #(
      kind   = if_apj_dt_exec_object=>parameter
      sign   = 'I'
      option = 'EQ'
      ( selname = c_param-test_run low = 'X' ) ).

  ENDMETHOD.


*----------------------------------------------------------------------*
* 값 검증 - SM36 배리언트에는 없던 계층
*   스케줄 저장 시점에 잘못된 값을 막는다.
*----------------------------------------------------------------------*
  METHOD if_apj_dt_exec_object~check_parameters.
    " TODO: 시그니처 확인 - 파라미터명이 it_parameters / it_parameter_val 중 무엇인지

    DATA(lt_val) = CORRESPONDING if_apj_rt_exec_object=>tt_templ_val( it_parameters ).

    IF VALUE #( lt_val[ selname = c_param-company_code ]-low OPTIONAL ) IS INITIAL.
      RAISE EXCEPTION NEW cx_apj_dt_content( ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
