"! 사용자 설정 수정 (PATCH) · ZCE_CMUP_UserSetting
"!
"! 흐름
"!   update  (상호작용 단계) : 검증 → 버퍼에 쌓기. 에러는 바로 PATCH 응답으로 나간다.
"!   save    (저장 단계)     : 사용자별로 모아 Tier 2 래퍼 → BAPI_USER_CHANGE 1번
"!   cleanup                 : 버퍼 비우기
"!
"! 검증
"!   사용자 : zcl_cmup_config=>c_self_only 기준 + 존재 여부
"!   항목   : zcl_cmup_config=>get_items 에 있는 것만
"!   값     : 파라미터는 Value Help 목록에 있는 값만 (빈 값 = 삭제 허용), 사용자정보는 BAPI 에 맡김

"! 상호작용 단계 → 저장 단계로 넘기는 변경분
CLASS lcl_buffer DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_change,
        user_id TYPE zif_cmup_user_api=>ty_user,
        item_id TYPE zif_cmup_user_api=>ty_item,
        value   TYPE zif_cmup_user_api=>ty_value,
      END OF ty_change,
      tt_change TYPE SORTED TABLE OF ty_change WITH UNIQUE KEY user_id item_id.

    CLASS-DATA gt_change TYPE tt_change.
ENDCLASS.

CLASS lcl_buffer IMPLEMENTATION.
ENDCLASS.


CLASS lhc_usersetting DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR UserSetting RESULT result.

    METHODS update FOR MODIFY
      IMPORTING entities FOR UPDATE UserSetting.

    METHODS read FOR READ
      IMPORTING keys FOR READ UserSetting RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK UserSetting.

    "! 문제 없으면 빈 값, 있으면 에러 문구
    METHODS check_user
      IMPORTING iv_user         TYPE zif_cmup_user_api=>ty_user
      RETURNING VALUE(rv_error) TYPE string.

    "! 문제 없으면 빈 값, 있으면 에러 문구
    METHODS check_value
      IMPORTING iv_item_id      TYPE zif_cmup_user_api=>ty_item
                iv_value        TYPE zif_cmup_user_api=>ty_value
      RETURNING VALUE(rv_error) TYPE string.
ENDCLASS.


CLASS lhc_usersetting IMPLEMENTATION.

  METHOD get_global_authorizations.
    " strict 모드라 권한 제어 선언이 필수라서 둔 자리. 지금은 전부 허용.
    " 포털 전용 권한 오브젝트를 만들면 여기서 AUTHORITY-CHECK 후 auth-unauthorized 로 막는다.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.


  METHOD update.
    LOOP AT entities INTO DATA(ls_entity).
      " 바꿀 수 있는 필드는 ParamValue 하나
      IF ls_entity-%control-ParamValue <> if_abap_behv=>mk-on.
        CONTINUE.
      ENDIF.

      DATA(lv_value) = CONV zif_cmup_user_api=>ty_value( to_upper( ls_entity-ParamValue ) ).

      DATA(lv_error) = check_user( ls_entity-UserId ).
      IF lv_error IS INITIAL.
        lv_error = check_value( iv_item_id = ls_entity-ItemId
                                iv_value   = lv_value ).
      ENDIF.

      IF lv_error IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_entity-%tky ) TO failed-usersetting.
        APPEND VALUE #( %tky                = ls_entity-%tky
                        %msg                = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                                     text     = lv_error )
                        %element-ParamValue = if_abap_behv=>mk-on ) TO reported-usersetting.
        CONTINUE.
      ENDIF.

      " 같은 항목을 한 트랜잭션에서 두 번 바꾸면 마지막 값
      DELETE lcl_buffer=>gt_change WHERE user_id = ls_entity-UserId AND item_id = ls_entity-ItemId.
      INSERT VALUE #( user_id = ls_entity-UserId
                      item_id = ls_entity-ItemId
                      value   = lv_value ) INTO TABLE lcl_buffer=>gt_change.
    ENDLOOP.
  ENDMETHOD.


  METHOD read.
    " PATCH 응답 등에서 프레임워크가 읽는다. 저장 전 바꾼 값이 있으면 그 값을 보여준다.
    DATA lt_row TYPE zcl_cmup_q_usersetting=>tt_row.

    LOOP AT keys INTO DATA(ls_key) GROUP BY ls_key-UserId INTO DATA(lv_user).
      TRY.
          lt_row = zcl_cmup_q_usersetting=>build_rows( lv_user ).
        CATCH zcx_cmup_user_api.
          CLEAR lt_row.
      ENDTRY.

      LOOP AT GROUP lv_user INTO DATA(ls_member).
        READ TABLE lt_row INTO DATA(ls_row) WITH KEY itemid = ls_member-ItemId.
        IF sy-subrc <> 0.
          APPEND VALUE #( %tky        = ls_member-%tky
                          %fail-cause = if_abap_behv=>cause-not_found ) TO failed-usersetting.
          CONTINUE.
        ENDIF.

        READ TABLE lcl_buffer=>gt_change INTO DATA(ls_change)
             WITH TABLE KEY user_id = lv_user item_id = ls_member-ItemId.
        IF sy-subrc = 0.
          ls_row-paramvalue = ls_change-value.
          CLEAR ls_row-valuetext.
          IF ls_row-category = zcl_cmup_config=>c_category-parameter.
            TRY.
                DATA(lt_value) = zcl_cmup_value_help=>read_source( ls_row-itemid ).
                ls_row-valuetext = VALUE #( lt_value[ code = ls_change-value ]-text OPTIONAL ).
              CATCH zcx_cmup_query.
                " VH 가 없는 파라미터면 텍스트만 비운다
            ENDTRY.
          ENDIF.
        ENDIF.

        APPEND CORRESPONDING #( ls_row ) TO result.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD lock.
    " 잠금은 BAPI_USER_CHANGE 가 저장할 때 직접 건다 (SU01 에서 같은 사용자를 열고 있으면 그때 에러).
    " 미리 잠그려면 Tier 2 래퍼에 사용자 잠금 메서드를 추가해서 여기서 호출한다.
  ENDMETHOD.


  METHOD check_user.
    IF zcl_cmup_config=>is_user_allowed( iv_user ) = abap_false.
      rv_error = |다른 사용자({ iv_user })의 설정은 바꿀 수 없습니다|.
      RETURN.
    ENDIF.

    " 없는 사용자면 저장 단계에서 BAPI 에러가 나므로 미리 확인
    TRY.
        zcl_cmup_user_api=>create( )->get_settings( iv_user ).
      CATCH zcx_cmup_user_api INTO DATA(lx_api).
        rv_error = lx_api->get_text( ).
    ENDTRY.
  ENDMETHOD.


  METHOD check_value.
    DATA(ls_item) = zcl_cmup_config=>get_item( iv_item_id ).
    IF ls_item IS INITIAL.
      rv_error = |{ iv_item_id } 는 포털에서 바꿀 수 없는 항목입니다|.
      RETURN.
    ENDIF.

    " 사용자정보는 목록이 없다 → 값 검증은 BAPI 에 맡긴다
    " 파라미터는 빈 값 = 그 파라미터 삭제
    IF ls_item-category <> zcl_cmup_config=>c_category-parameter OR iv_value IS INITIAL.
      RETURN.
    ENDIF.

    " SU3·BAPI 는 파라미터 값을 마스터와 대조하지 않으므로 여기서 막는다
    TRY.
        DATA(lt_value) = zcl_cmup_value_help=>read_source( iv_item_id ).
      CATCH zcx_cmup_query INTO DATA(lx_vh).
        rv_error = lx_vh->get_text( ).
        RETURN.
    ENDTRY.
    IF NOT line_exists( lt_value[ code = iv_value ] ).
      rv_error = |{ ls_item-item_name }: { iv_value } 는 고를 수 없는 값입니다|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.


CLASS lsc_usersetting DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save    REDEFINITION.
    METHODS cleanup REDEFINITION.
ENDCLASS.


CLASS lsc_usersetting IMPLEMENTATION.

  METHOD save.
    DATA lt_setting TYPE zif_cmup_user_api=>tt_setting.
    DATA(lo_api) = zcl_cmup_user_api=>create( ).

    " 사용자별로 모아서 BAPI 1번 (기존 파라미터와의 병합은 래퍼가 한다)
    LOOP AT lcl_buffer=>gt_change INTO DATA(ls_change) GROUP BY ls_change-user_id INTO DATA(lv_user).
      lt_setting = VALUE #( FOR ls_member IN GROUP lv_user
                            ( item_id = ls_member-item_id
                              value   = ls_member-value ) ).
      TRY.
          lo_api->change_settings( iv_user    = lv_user
                                   it_setting = lt_setting ).
        CATCH zcx_cmup_user_api INTO DATA(lx_api).
          " 저장 단계라 되돌릴 수 없다 → 메시지만 남긴다 (update 에서 미리 검증하는 이유)
          APPEND new_message_with_text( severity = if_abap_behv_message=>severity-error
                                        text     = |{ lv_user }: { lx_api->get_text( ) }| ) TO reported-%other.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD cleanup.
    CLEAR lcl_buffer=>gt_change.
  ENDMETHOD.

ENDCLASS.
