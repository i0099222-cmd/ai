"! <p class="shorttext synchronized">ZTBATCH_SCHED-PARAM 직렬화</p>
"!
"! 런처가 실행 시점에 읽어야 하는 값들을 JSON 한 필드에 담는다.
"! 컬럼을 늘리는 대신 param 하나로 묶는 이유:
"!   - APJ 가 이미 갖고 있는 값(시작일시/주기/타임존)은 저장할 필요가 없고
"!   - 나머지는 런처만 읽으므로 SQL 조건으로 쓸 일이 없다
"!
"! XCO 는 ABAP Cloud 에서 released 된 직렬화 API 다.
"! TODO: 시그니처 확인 - XCO_CP_JSON 의 메서드 체인은 릴리스별로 차이가 있을 수 있다.
CLASS zcl_batch_param DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CLASS-METHODS serialize
      IMPORTING
        is_param       TYPE zif_batch_job=>ty_param
      RETURNING
        VALUE(rv_json) TYPE string.

    CLASS-METHODS deserialize
      IMPORTING
        iv_json         TYPE string
      RETURNING
        VALUE(rs_param) TYPE zif_batch_job=>ty_param.

ENDCLASS.


CLASS zcl_batch_param IMPLEMENTATION.

  METHOD serialize.

    TRY.
        rv_json = xco_cp_json=>data->from_abap( is_param )->to_string( ).
      CATCH cx_root.
        CLEAR rv_json.
    ENDTRY.

  ENDMETHOD.


  METHOD deserialize.

    CLEAR rs_param.

    CHECK iv_json IS NOT INITIAL.

    TRY.
        xco_cp_json=>data->from_string( iv_json )->write_to( REF #( rs_param ) ).
      CATCH cx_root.
        CLEAR rs_param.
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
