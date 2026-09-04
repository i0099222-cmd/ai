"! <p class="shorttext synchronized">잡 파라미터 값 변환</p>
"!
"! ZTBATCH_SCHED-PARAM (JSON) <-> APJ 파라미터 테이블(tt_templ_val).
"!
"! JSON 형태:
"!   [{"name":"P_BUKRS","value":"1000"},{"name":"P_TEST","value":"X"}]
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

    "! JSON -> APJ 파라미터 테이블
    CLASS-METHODS to_apj
      IMPORTING
        iv_json        TYPE string
      RETURNING
        VALUE(rt_vals) TYPE if_apj_rt_exec_object=>tt_templ_val.

    "! APJ 파라미터 테이블 -> JSON
    CLASS-METHODS from_apj
      IMPORTING
        it_vals        TYPE if_apj_rt_exec_object=>tt_templ_val
      RETURNING
        VALUE(rv_json) TYPE string.

ENDCLASS.


CLASS zcl_batch_param IMPLEMENTATION.

  METHOD to_apj.

    CHECK iv_json IS NOT INITIAL.

    DATA lt_kv TYPE zif_batch_job=>tt_param_value.

    TRY.
        xco_cp_json=>data->from_string( iv_json )->write_to( REF #( lt_kv ) ).
      CATCH cx_root.
        RETURN.
    ENDTRY.

    rt_vals = VALUE #(
      kind   = if_apj_dt_exec_object=>parameter
      sign   = 'I'
      option = 'EQ'
      FOR ls_kv IN lt_kv
      ( selname = ls_kv-name
        low     = ls_kv-value ) ).

  ENDMETHOD.


  METHOD from_apj.

    DATA(lt_kv) = VALUE zif_batch_job=>tt_param_value(
      FOR ls_val IN it_vals
      ( name  = ls_val-selname
        value = CONV #( ls_val-low ) ) ).

    TRY.
        rv_json = xco_cp_json=>data->from_abap( lt_kv )->to_string( ).
      CATCH cx_root.
        CLEAR rv_json.
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
