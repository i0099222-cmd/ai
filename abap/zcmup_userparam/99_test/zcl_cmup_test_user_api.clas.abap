"! SU3 래퍼(zif_cmup_user_api) 테스트 · ADT 에서 F9 (Run As → ABAP Application (Console))
"!
"! 1차: c_run_change = abap_false → 조회만
"! 2차: c_run_change = abap_true  → 변경 → 다시 읽어서 확인 → 원래 값으로 복구
"!      복구 전에 SU3 에서 직접 보고 싶으면 c_restore = abap_false
"!
"! 확인하는 것
"!   - 바꾼 항목이 기대값으로 바뀌었는지
"!   - 나머지 항목(다른 파라미터)이 그대로인지 ← 파라미터 통째 교체로 지워지지 않았는지
"!   - 복구 후 처음 상태와 같은지
CLASS zcl_cmup_test_user_api DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    CONSTANTS:
      "! 테스트 사용자 (빈 값 = 나)
      c_user       TYPE zif_cmup_user_api=>ty_user  VALUE '',
      "! 바꿔 볼 항목 (파라미터 ID 또는 DATFM 같은 기본값 항목)
      c_test_item  TYPE zif_cmup_user_api=>ty_item  VALUE 'EKO',
      "! 바꿔 볼 값 (실제로 있는 값으로)
      c_test_value TYPE zif_cmup_user_api=>ty_value VALUE '1000',
      "! abap_false = 조회만 / abap_true = 변경 테스트
      c_run_change TYPE abap_boolean VALUE abap_false,
      "! abap_true = 테스트 끝나면 원래 값으로 복구
      c_restore    TYPE abap_boolean VALUE abap_true.

    DATA: mo_api  TYPE REF TO zif_cmup_user_api,
          mo_out  TYPE REF TO if_oo_adt_classrun_out,
          mv_user TYPE zif_cmup_user_api=>ty_user.

    METHODS test_change
      IMPORTING it_before TYPE zif_cmup_user_api=>tt_setting
      RAISING   zcx_cmup_user_api.

    "! 바꾼 항목 값 + 나머지 항목이 그대로인지
    METHODS check_changed
      IMPORTING it_before TYPE zif_cmup_user_api=>tt_setting
                it_after  TYPE zif_cmup_user_api=>tt_setting.

    "! 다른 것만 출력. 같으면 abap_true
    METHODS compare
      IMPORTING it_old         TYPE zif_cmup_user_api=>tt_setting
                it_new         TYPE zif_cmup_user_api=>tt_setting
      RETURNING VALUE(rv_same) TYPE abap_boolean.
ENDCLASS.


CLASS zcl_cmup_test_user_api IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    mo_out  = out.
    mo_api  = zcl_cmup_user_api=>create( ).
    mv_user = COND #( WHEN c_user IS INITIAL THEN cl_abap_context_info=>get_user_technical_name( )
                      ELSE c_user ).

    TRY.
        out->write( |===== 1. 조회 : { mv_user } =====| ).
        DATA(lt_before) = mo_api->get_settings( mv_user ).
        out->write( lt_before ).

        IF c_run_change = abap_false.
          out->write( `조회만 했습니다. 변경 테스트는 c_run_change = abap_true` ).
          RETURN.
        ENDIF.

        test_change( lt_before ).

      CATCH cx_root INTO DATA(lx_error).
        out->write( |에러: { lx_error->get_text( ) }| ).
        DATA(lx_prev) = lx_error->previous.
        WHILE lx_prev IS BOUND.
          out->write( |  원인: { lx_prev->get_text( ) }| ).
          lx_prev = lx_prev->previous.
        ENDWHILE.
    ENDTRY.
  ENDMETHOD.


  METHOD test_change.
    DATA(lv_old) = VALUE zif_cmup_user_api=>ty_value( it_before[ item_id = c_test_item ]-value OPTIONAL ).

    " 변경
    mo_out->write( |===== 2. 변경 : { c_test_item }  '{ lv_old }' → '{ c_test_value }' =====| ).
    mo_api->change_settings( iv_user    = mv_user
                             it_setting = VALUE #( ( item_id = c_test_item value = c_test_value ) ) ).
    COMMIT WORK.
    check_changed( it_before = it_before
                   it_after  = mo_api->get_settings( mv_user ) ).

    IF c_restore = abap_false.
      mo_out->write( `복구 안 함 → SU3 에서 직접 확인하세요` ).
      RETURN.
    ENDIF.

    " 복구 (원래 없던 파라미터면 빈 값 = 삭제)
    mo_out->write( |===== 3. 복구 : { c_test_item } → '{ lv_old }' =====| ).
    mo_api->change_settings( iv_user    = mv_user
                             it_setting = VALUE #( ( item_id = c_test_item value = lv_old ) ) ).
    COMMIT WORK.
    IF compare( it_old = it_before
                it_new = mo_api->get_settings( mv_user ) ) = abap_true.
      mo_out->write( `OK  처음 상태로 돌아왔습니다` ).
    ELSE.
      mo_out->write( `NG  처음 상태와 다릅니다 (위 목록)` ).
    ENDIF.
  ENDMETHOD.


  METHOD check_changed.
    DATA(lv_new) = VALUE zif_cmup_user_api=>ty_value( it_after[ item_id = c_test_item ]-value OPTIONAL ).
    IF lv_new = c_test_value.
      mo_out->write( |OK  { c_test_item } = { lv_new }| ).
    ELSE.
      mo_out->write( |NG  { c_test_item } = '{ lv_new }'  (기대값 '{ c_test_value }')| ).
    ENDIF.

    DATA(lt_old) = it_before.
    DATA(lt_new) = it_after.
    DELETE lt_old WHERE item_id = c_test_item.
    DELETE lt_new WHERE item_id = c_test_item.
    IF compare( it_old = lt_old it_new = lt_new ) = abap_true.
      mo_out->write( |OK  나머지 { lines( lt_old ) }개 항목 그대로| ).
    ELSE.
      mo_out->write( `NG  나머지 항목이 바뀌었습니다 (위 목록)` ).
    ENDIF.
  ENDMETHOD.


  METHOD compare.
    rv_same = abap_true.

    LOOP AT it_old INTO DATA(ls_old).
      READ TABLE it_new INTO DATA(ls_new) WITH TABLE KEY item_id = ls_old-item_id.
      IF sy-subrc <> 0.
        mo_out->write( |    사라짐  { ls_old-item_id } = { ls_old-value }| ).
        rv_same = abap_false.
      ELSEIF ls_new-value <> ls_old-value.
        mo_out->write( |    바뀜    { ls_old-item_id } : { ls_old-value } → { ls_new-value }| ).
        rv_same = abap_false.
      ENDIF.
    ENDLOOP.

    LOOP AT it_new INTO ls_new.
      IF NOT line_exists( it_old[ item_id = ls_new-item_id ] ).
        mo_out->write( |    생김    { ls_new-item_id } = { ls_new-value }| ).
        rv_same = abap_false.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
