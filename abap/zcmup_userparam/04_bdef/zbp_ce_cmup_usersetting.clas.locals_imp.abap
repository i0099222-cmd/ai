"! ③ 저장 (정적 액션 saveSettings) · ZCE_CMUP_UserSetting
"!
"! 흐름
"!   saveSettings (상호작용 단계) : 검증 → 현재값과 다른 항목만 버퍼에. 에러는 바로 응답으로 나간다.
"!   save         (저장 단계)     : 사용자별로 모아 래퍼 → BAPI_USER_CHANGE 1번
"!   cleanup                      : 버퍼 비우기
"!
"! 검증 (하나라도 틀리면 그 요청 전체를 저장하지 않는다)
"!   사용자 : 로그온 사용자 본인만 (UserId 를 비우면 로그온 사용자)
"!   항목   : zcl_cmup_value_help 가 아는 항목만 (get_item_ids), 같은 항목 두 번은 안 됨
"!   값     : 빈 값은 그대로 BAPI 로 (파라미터 = 삭제, 기본값 항목 = BAPI 가 판단)
"!            그 외는 Value Help 목록에 있는 값만 (SU3·BAPI 는 마스터와 대조하지 않는다)

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

    METHODS savesettings FOR MODIFY
      IMPORTING keys FOR ACTION UserSetting~saveSettings RESULT result.

    METHODS read FOR READ
      IMPORTING keys FOR READ UserSetting RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK UserSetting.
ENDCLASS.


CLASS lhc_usersetting IMPLEMENTATION.

  METHOD get_global_authorizations.
    " strict 모드라 권한 제어 선언이 필수라서 둔 자리. 지금은 전부 허용.
    " 포털 전용 권한 오브젝트를 만들면 여기서 AUTHORITY-CHECK 후 auth-unauthorized 로 막는다.
    IF requested_authorizations-%action-saveSettings = if_abap_behv=>mk-on.
      result-%action-saveSettings = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.


  METHOD savesettings.
    DATA: lt_error   TYPE string_table,
          lt_current TYPE zif_cmup_user_api=>tt_setting,
          lt_change  TYPE lcl_buffer=>tt_change,
          lt_row     TYPE zcl_cmup_q_usersetting=>tt_row,
          lt_seen    TYPE SORTED TABLE OF zif_cmup_user_api=>ty_item WITH UNIQUE KEY table_line.

    DATA(lv_me) = CONV zif_cmup_user_api=>ty_user( cl_abap_context_info=>get_user_technical_name( ) ).

    LOOP AT keys INTO DATA(ls_key).
      CLEAR: lt_error, lt_current, lt_change, lt_row, lt_seen.

      " 사용자 (비우면 로그온 사용자, 다른 사용자는 안 됨)
      DATA(lv_user) = COND zif_cmup_user_api=>ty_user( WHEN ls_key-%param-UserId IS INITIAL THEN lv_me
                                                       ELSE to_upper( ls_key-%param-UserId ) ).
      IF lv_user <> lv_me.
        APPEND |다른 사용자({ lv_user })의 설정은 바꿀 수 없습니다| TO lt_error.
      ELSE.
        " 현재값 (같은 값이면 BAPI 대상에서 빼려고)
        TRY.
            lt_current = zcl_cmup_user_api=>create( )->get_settings( lv_user ).
          CATCH zcx_cmup_user_api INTO DATA(lx_api).
            APPEND lx_api->get_text( ) TO lt_error.
        ENDTRY.
      ENDIF.

      " 항목별 검증
      IF lt_error IS INITIAL.
        LOOP AT ls_key-%param-_Items INTO DATA(ls_item).
          DATA(lv_item_id) = CONV zif_cmup_user_api=>ty_item( to_upper( ls_item-ItemId ) ).
          DATA(lv_value)   = CONV zif_cmup_user_api=>ty_value( to_upper( ls_item-ParamValue ) ).

          INSERT lv_item_id INTO TABLE lt_seen.
          IF sy-subrc <> 0.
            APPEND |{ lv_item_id }: 같은 항목이 두 번 있습니다| TO lt_error.
            CONTINUE.
          ENDIF.

          " 이 API 가 다루는 항목인지 (모르는 항목이면 read_source 가 예외)
          TRY.
              DATA(lt_value) = zcl_cmup_value_help=>read_source( lv_item_id ).
            CATCH zcx_cmup_query.
              APPEND |{ lv_item_id } 는 수정할 수 없는 항목입니다| TO lt_error.
              CONTINUE.
          ENDTRY.

          IF lv_value IS NOT INITIAL AND NOT line_exists( lt_value[ code = lv_value ] ).
            APPEND |{ lv_item_id }: { lv_value } 는 고를 수 없는 값입니다| TO lt_error.
            CONTINUE.
          ENDIF.

          " 응답용: 저장될 값과 텍스트
          APPEND VALUE #( userid     = lv_user
                          itemid     = lv_item_id
                          paramvalue = lv_value
                          valuetext  = VALUE #( lt_value[ code = lv_value ]-text OPTIONAL ) ) TO lt_row.

          " 현재값과 다를 때만 BAPI 대상
          IF lv_value <> VALUE zif_cmup_user_api=>ty_value( lt_current[ item_id = lv_item_id ]-value OPTIONAL ).
            INSERT VALUE #( user_id = lv_user
                            item_id = lv_item_id
                            value   = lv_value ) INTO TABLE lt_change.
          ENDIF.
        ENDLOOP.
      ENDIF.

      " 하나라도 틀리면 이 요청은 전부 저장하지 않는다
      IF lt_error IS NOT INITIAL.
        APPEND VALUE #( %cid = ls_key-%cid ) TO failed-usersetting.
        LOOP AT lt_error INTO DATA(lv_text).
          APPEND VALUE #( %cid = ls_key-%cid
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = lv_text ) ) TO reported-usersetting.
        ENDLOOP.
        CONTINUE.
      ENDIF.

      " 버퍼에 반영 (같은 트랜잭션에서 같은 항목이 또 오면 마지막 값)
      LOOP AT lt_change INTO DATA(ls_change).
        DELETE lcl_buffer=>gt_change WHERE user_id = ls_change-user_id AND item_id = ls_change-item_id.
        INSERT ls_change INTO TABLE lcl_buffer=>gt_change.
      ENDLOOP.

      " 결과: 보낸 항목들의 저장될 값
      LOOP AT lt_row INTO DATA(ls_row).
        APPEND VALUE #( %cid   = ls_key-%cid
                        %param = CORRESPONDING #( ls_row ) ) TO result.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD read.
    " 프레임워크가 읽을 때. 저장 전 바꾼 값이 있으면 그 값을 보여준다.
    DATA lt_row TYPE zcl_cmup_q_usersetting=>tt_row.
    DATA(lv_me) = CONV zif_cmup_user_api=>ty_user( cl_abap_context_info=>get_user_technical_name( ) ).

    LOOP AT keys INTO DATA(ls_key) GROUP BY ls_key-UserId INTO DATA(lv_user).

      " 다른 사용자 것은 읽지 않는다
      IF lv_user <> lv_me.
        LOOP AT GROUP lv_user INTO DATA(ls_other).
          APPEND VALUE #( %tky        = ls_other-%tky
                          %fail-cause = if_abap_behv=>cause-unauthorized ) TO failed-usersetting.
        ENDLOOP.
        CONTINUE.
      ENDIF.

      TRY.
          lt_row = zcl_cmup_q_usersetting=>build_rows( lv_user ).
        CATCH zcx_cmup_user_api zcx_cmup_query.
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
          TRY.
              DATA(lt_value) = zcl_cmup_value_help=>read_source( ls_row-itemid ).
              ls_row-valuetext = VALUE #( lt_value[ code = ls_change-value ]-text OPTIONAL ).
            CATCH zcx_cmup_query.
              CLEAR ls_row-valuetext.
          ENDTRY.
        ENDIF.

        APPEND CORRESPONDING #( ls_row ) TO result.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD lock.
    " 잠금은 BAPI_USER_CHANGE 가 저장할 때 직접 건다 (SU01 에서 같은 사용자를 열고 있으면 그때 에러).
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
          " 저장 단계라 되돌릴 수 없다 → 메시지만 남긴다 (액션에서 미리 검증하는 이유)
          APPEND new_message_with_text( severity = if_abap_behv_message=>severity-error
                                        text     = |{ lv_user }: { lx_api->get_text( ) }| ) TO reported-%other.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD cleanup.
    CLEAR lcl_buffer=>gt_change.
  ENDMETHOD.

ENDCLASS.
