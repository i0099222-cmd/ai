"! <p class="shorttext synchronized">잡 파라미터 값 변환</p>
"!
"! ZTBATCH_SCHED-PARAM <-> APJ 파라미터 테이블(tt_templ_val).
"!
"! APJ 의 tt_templ_val 은 selname + sign/option/low/high 구조라
"! 파라미터 하나에 여러 행(range)이 올 수 있다. 그래서 PARAM 도
"! name + t_value(range 테이블) 형태로 담는다.
"!
"! 두 가지 입력 형식을 받는다. 첫 글자로 구분한다.
"!
"!   1) JSON 배열 - 전체 표현 가능 (select-option 포함)
"!        [{"name":"P_MODU","t_value":[{"sign":"I","option":"EQ","low":"SD"}]},
"!         {"name":"P_DATS","t_value":[{"sign":"I","option":"BT",
"!                                      "low":"20260101","high":"20261231"}]}]
"!
"!   2) 구분자 형식 - 단일 EQ 값 축약형. API 테스트용.
"!        P_MODU=SD;P_ZUID=X
"!      Parameters 가 string 필드라 JSON 은 페이로드에서 따옴표를 전부
"!      이스케이프해야 하는데, 이 형식은 그럴 필요가 없다.
"!      값에 ';' 나 '=' 가 들어가거나 range 가 필요하면 JSON 을 쓴다.
"!
"! NOTE 직렬화는 XCO 를 쓴다. /UI2/CL_JSON 은 ABAP Cloud 에서 사용할 수 없다.
"! TODO: 시그니처 확인 - XCO_CP_JSON 의 메서드 체인과 JSON 필드명 대소문자 규칙.
"!       실제 직렬화 결과를 한 번 찍어보고 호출자와 맞출 것.
CLASS zcl_batch_param DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! PARAM 문자열 -> APJ 파라미터 테이블
    CLASS-METHODS to_apj
      IMPORTING
        iv_param       TYPE string
      RETURNING
        VALUE(rt_vals) TYPE if_apj_rt_exec_object=>tt_templ_val.

    "! APJ 파라미터 테이블 -> PARAM JSON
    CLASS-METHODS from_apj
      IMPORTING
        it_vals         TYPE if_apj_rt_exec_object=>tt_templ_val
      RETURNING
        VALUE(rv_param) TYPE string.

  PRIVATE SECTION.

    "! JSON 배열 파싱
    CLASS-METHODS parse_json
      IMPORTING
        iv_param        TYPE string
      RETURNING
        VALUE(rt_param) TYPE zif_batch_job=>tt_param.

    "! 'P_A=1;P_B=2' 파싱. 각각 단일 EQ range 로 만든다.
    CLASS-METHODS parse_delimited
      IMPORTING
        iv_param        TYPE string
      RETURNING
        VALUE(rt_param) TYPE zif_batch_job=>tt_param.

    "! KIND 가 비어 있으면 t_value 모양으로 추정한다.
    CLASS-METHODS derive_kind
      IMPORTING
        is_param       TYPE zif_batch_job=>ty_param
      RETURNING
        VALUE(rv_kind) TYPE c.

ENDCLASS.


CLASS zcl_batch_param IMPLEMENTATION.

  METHOD to_apj.

    DATA(lv_param) = condense( iv_param ).
    CHECK lv_param IS NOT INITIAL.

    DATA(lt_param) = COND #(
      WHEN lv_param(1) = '[' OR lv_param(1) = '{'
      THEN parse_json( lv_param )
      ELSE parse_delimited( lv_param ) ).

    LOOP AT lt_param INTO DATA(ls_param).

      CHECK ls_param-name IS NOT INITIAL.

      DATA(lv_kind) = derive_kind( ls_param ).

      LOOP AT ls_param-t_value INTO DATA(ls_range).
        APPEND VALUE #(
          selname = to_upper( ls_param-name )
          kind    = lv_kind
          sign    = COND #( WHEN ls_range-sign   IS INITIAL THEN 'I'  ELSE ls_range-sign )
          option  = COND #( WHEN ls_range-option IS INITIAL THEN 'EQ' ELSE ls_range-option )
          low     = ls_range-low
          high    = ls_range-high ) TO rt_vals.
      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.


  METHOD from_apj.

    DATA lt_param TYPE zif_batch_job=>tt_param.

    LOOP AT it_vals INTO DATA(ls_val).

      DATA(lv_name) = CONV zif_batch_job=>ty_param-name( ls_val-selname ).

      ASSIGN lt_param[ name = lv_name ] TO FIELD-SYMBOL(<ls_param>).
      IF sy-subrc <> 0.
        APPEND VALUE #( name = lv_name kind = ls_val-kind ) TO lt_param
               ASSIGNING <ls_param>.
      ENDIF.

      APPEND VALUE #( sign   = ls_val-sign
                      option = ls_val-option
                      low    = CONV #( ls_val-low )
                      high   = CONV #( ls_val-high ) ) TO <ls_param>-t_value.

    ENDLOOP.

    TRY.
        rv_param = xco_cp_json=>data->from_abap( lt_param )->to_string( ).
      CATCH cx_root.
        CLEAR rv_param.
    ENDTRY.

  ENDMETHOD.


  METHOD parse_json.

    TRY.
        xco_cp_json=>data->from_string( iv_param )->write_to( REF #( rt_param ) ).
      CATCH cx_root.
        CLEAR rt_param.
    ENDTRY.

  ENDMETHOD.


  METHOD parse_delimited.

    SPLIT iv_param AT ';' INTO TABLE DATA(lt_pair).

    LOOP AT lt_pair INTO DATA(lv_pair).

      DATA(lv_entry) = condense( lv_pair ).
      CHECK lv_entry IS NOT INITIAL.

      SPLIT lv_entry AT '=' INTO DATA(lv_name) DATA(lv_value).

      DATA(lv_sel) = condense( lv_name ).
      CHECK lv_sel IS NOT INITIAL.

      APPEND VALUE #(
        name    = to_upper( lv_sel )
        kind    = zif_batch_job=>gc_kind-parameter
        t_value = VALUE #( ( sign   = 'I'
                             option = 'EQ'
                             low    = condense( lv_value ) ) ) ) TO rt_param.

    ENDLOOP.

  ENDMETHOD.


  METHOD derive_kind.

    " 호출자가 명시했으면 그대로 쓴다
    IF is_param-kind IS NOT INITIAL.
      rv_kind = is_param-kind.
      RETURN.
    ENDIF.

    " 단일 행이고 EQ 면 PARAMETER, 그 밖에는 SELECT-OPTION 으로 본다.
    " 실행 클래스의 GET_PARAMETERS 가 선언한 KIND 와 맞아야 하므로,
    " 다르면 JSON 에 kind 를 명시할 것.
    rv_kind = COND #(
      WHEN lines( is_param-t_value ) = 1
       AND ( is_param-t_value[ 1 ]-option = 'EQ' OR is_param-t_value[ 1 ]-option IS INITIAL )
      THEN zif_batch_job=>gc_kind-parameter
      ELSE zif_batch_job=>gc_kind-select_option ).

  ENDMETHOD.

ENDCLASS.
