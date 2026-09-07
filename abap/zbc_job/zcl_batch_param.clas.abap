"! <p class="shorttext synchronized">잡 파라미터 값 변환</p>
"!
"! ZTBATCH_SCHED-PARAM <-> APJ 파라미터 테이블(tt_templ_val).
"!
"! 두 가지 형식을 모두 받는다. 첫 글자로 구분한다.
"!
"!   1) 구분자 형식 (권장 - API 테스트용)
"!        P_BUKRS=1000;P_TEST=X
"!      OData 페이로드에서 이스케이프가 필요 없다.
"!
"!   2) JSON 배열 (구조화된 호출자용)
"!        [{"name":"P_BUKRS","value":"1000"},{"name":"P_TEST","value":"X"}]
"!      Parameters 가 string 필드라 OData 페이로드에서는 따옴표를
"!      이스케이프해야 한다: "[{\"name\":...}]"
"!
"! 값에 ';' 나 '=' 가 들어가야 하면 JSON 형식을 쓸 것.
"!
"! name 은 실행 클래스의 IF_APJ_DT_EXEC_OBJECT~GET_PARAMETERS 가 정의한
"! SELNAME 과 일치해야 한다. 값 검증은 실행 클래스의 CHECK_PARAMETERS 가 한다.
"!
"! XCO 는 ABAP Cloud 에서 released 된 직렬화 API 다.
"! TODO: 시그니처 확인 - XCO_CP_JSON 의 메서드 체인은 릴리스별로 차이가 있을 수 있다.
CLASS zcl_batch_param DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! PARAM 문자열 -> APJ 파라미터 테이블.
    "! 구분자 형식과 JSON 배열을 모두 받는다.
    CLASS-METHODS to_apj
      IMPORTING
        iv_param       TYPE string
      RETURNING
        VALUE(rt_vals) TYPE if_apj_rt_exec_object=>tt_templ_val.

    "! APJ 파라미터 테이블 -> 구분자 형식 문자열
    CLASS-METHODS from_apj
      IMPORTING
        it_vals         TYPE if_apj_rt_exec_object=>tt_templ_val
      RETURNING
        VALUE(rv_param) TYPE string.

ENDCLASS.


CLASS zcl_batch_param IMPLEMENTATION.

  METHOD to_apj.

    DATA(lv_param) = condense( iv_param ).

    CHECK lv_param IS NOT INITIAL.

    DATA lt_kv TYPE zif_batch_job=>tt_param_value.

    IF lv_param(1) = '[' OR lv_param(1) = '{'.

      " --- JSON 배열 ---
      TRY.
          xco_cp_json=>data->from_string( lv_param )->write_to( REF #( lt_kv ) ).
        CATCH cx_root.
          RETURN.
      ENDTRY.

    ELSE.

      " --- 구분자 형식: P_A=1;P_B=2 ---
      SPLIT lv_param AT ';' INTO TABLE DATA(lt_pair).

      LOOP AT lt_pair INTO DATA(lv_pair).

        DATA(lv_entry) = condense( lv_pair ).
        CHECK lv_entry IS NOT INITIAL.

        SPLIT lv_entry AT '=' INTO DATA(lv_name) DATA(lv_value).

        DATA(lv_sel) = condense( lv_name ).
        CHECK lv_sel IS NOT INITIAL.

        APPEND VALUE #( name  = to_upper( lv_sel )
                        value = condense( lv_value ) ) TO lt_kv.

      ENDLOOP.

    ENDIF.

    rt_vals = VALUE #(
      kind   = if_apj_dt_exec_object=>parameter
      sign   = 'I'
      option = 'EQ'
      FOR ls_kv IN lt_kv
      ( selname = ls_kv-name
        low     = ls_kv-value ) ).

  ENDMETHOD.


  METHOD from_apj.

    LOOP AT it_vals INTO DATA(ls_val).
      rv_param = COND #( WHEN rv_param IS INITIAL
                         THEN |{ ls_val-selname }={ ls_val-low }|
                         ELSE |{ rv_param };{ ls_val-selname }={ ls_val-low }| ).
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
