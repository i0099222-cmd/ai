"! <p class="shorttext synchronized">잡 파라미터 값 변환</p>
"!
"! ZTBATCH_SCHED-PARAM (JSON) -> APJ 파라미터 테이블(tt_templ_val).
"!
"! PARAM 형식 - 호출자가 /UI2/CL_JSON 으로 직렬화해서 보낸다.
"!
"!   [{"name":"P_MODU",
"!     "t_value":[{"sign":"I","option":"EQ","low":"SD"}]},
"!    {"name":"P_DATS",
"!     "t_value":[{"sign":"I","option":"BT","low":"20260101","high":"20261231"}]}]
"!
"! APJ 의 tt_templ_val 이 selname + sign/option/low/high 구조라
"! 파라미터 하나에 여러 행(range)이 올 수 있다. t_value 를 그대로 펼친다.
"!
"! name 은 실행 클래스가 GET_PARAMETERS 에서 정의한 SELNAME 과 일치해야 한다.
"! 값 검증은 그 클래스의 CHECK_PARAMETERS 가 한다.
CLASS zcl_batch_param DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS to_apj
      IMPORTING
        iv_param       TYPE string
      RETURNING
        VALUE(rt_vals) TYPE if_apj_rt_exec_object=>tt_templ_val.

ENDCLASS.


CLASS zcl_batch_param IMPLEMENTATION.

  METHOD to_apj.

    CHECK iv_param IS NOT INITIAL.

    DATA lt_param TYPE zif_batch_job=>tt_param.

    /ui2/cl_json=>deserialize( EXPORTING json = iv_param
                               CHANGING  data = lt_param ).

    LOOP AT lt_param INTO DATA(ls_param).
      LOOP AT ls_param-t_value INTO DATA(ls_range).
        APPEND VALUE #( selname = ls_param-name
                        kind    = ls_param-kind
                        sign    = ls_range-sign
                        option  = ls_range-option
                        low     = ls_range-low
                        high    = ls_range-high ) TO rt_vals.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
