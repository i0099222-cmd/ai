"! ③ 저장 (정적 액션 saveSettings) · ZCE_CMUP_UserSetting
"!
"! 흐름
"!   saveSettings : 검증 → 현재값과 다른 항목만 모아서 바로 래퍼 change_settings 호출
"!                  (래퍼 = BAPI_USER_CHANGE + BAPI_TRANSACTION_COMMIT, 별도 RFC 세션)
"!   save         : 비워 둔다. RAP 저장 단계에서 RFC·COMMIT 을 하면 LUW 덤프가 나기 때문.
"!
"! 검증 (하나라도 틀리면 그 요청 전체를 저장하지 않는다)
"!   사용자 : 로그온 사용자 본인만 (UserId 를 비우면 로그온 사용자)
"!   항목   : zcl_cmup_value_help 가 아는 항목만 (get_item_ids), 같은 항목 두 번은 안 됨
"!   값     : 빈 값은 그대로 BAPI 로 (파라미터 = 삭제, 기본값 항목 = BAPI 가 판단)
"!            그 외는 Value Help 목록에 있는 값만 (SU3·BAPI 는 마스터와 대조하지 않는다)
"!
"! 응답
"!   성공 : 200 + 항목마다 한 줄 (Status CHANGED / UNCHANGED, Message) + 요약 메시지 (sap-messages 헤더)
"!   실패 : 400 + 에러 메시지 (아무것도 저장되지 않음)
"!
"! 주의: 액션에서 바로 커밋하므로 RAP 트랜잭션으로 되돌릴 수 없다.
"!       한 번 호출에 저장 액션 하나만 보내는 전제 ($batch 로 다른 변경과 묶지 않는다).
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
          lt_change  TYPE zif_cmup_user_api=>tt_setting,
          lt_result  TYPE STANDARD TABLE OF zd_cmup_saveresult WITH EMPTY KEY,
          lt_seen    TYPE SORTED TABLE OF zif_cmup_user_api=>ty_item WITH UNIQUE KEY table_line.

    DATA(lv_me) = CONV zif_cmup_user_api=>ty_user( cl_abap_context_info=>get_user_technical_name( ) ).

    LOOP AT keys INTO DATA(ls_key).
      CLEAR: lt_error, lt_current, lt_change, lt_result, lt_seen.

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

          " 현재값과 다를 때만 BAPI 대상
          DATA(lv_changed) = xsdbool( lv_value <> VALUE zif_cmup_user_api=>ty_value( lt_current[ item_id = lv_item_id ]-value OPTIONAL ) ).
          IF lv_changed = abap_true.
            INSERT VALUE #( item_id = lv_item_id value = lv_value ) INTO TABLE lt_change.
          ENDIF.

          " 응답용 한 줄
          APPEND VALUE #( itemid     = lv_item_id
                          paramvalue = lv_value
                          valuetext  = VALUE #( lt_value[ code = lv_value ]-text OPTIONAL )
                          status     = COND #( WHEN lv_changed = abap_true THEN 'CHANGED' ELSE 'UNCHANGED' )
                          message    = COND #( WHEN lv_changed = abap_true AND lv_value IS INITIAL THEN `삭제했습니다`
                                               WHEN lv_changed = abap_true                       THEN `변경했습니다`
                                               ELSE `현재값과 같아서 변경하지 않았습니다` ) ) TO lt_result.
        ENDLOOP.
      ENDIF.

      " 바뀐 항목이 있으면 바로 저장 (래퍼가 BAPI_USER_CHANGE + COMMIT, 에러면 ROLLBACK)
      IF lt_error IS INITIAL AND lt_change IS NOT INITIAL.
        TRY.
            zcl_cmup_user_api=>create( )->change_settings( iv_user    = lv_user
                                                           it_setting = lt_change ).
          CATCH zcx_cmup_user_api INTO lx_api.
            APPEND lx_api->get_text( ) TO lt_error.
        ENDTRY.
      ENDIF.

      " 에러: 이 요청은 저장되지 않았다
      IF lt_error IS NOT INITIAL.
        APPEND VALUE #( %cid = ls_key-%cid ) TO failed-usersetting.
        LOOP AT lt_error INTO DATA(lv_text).
          APPEND VALUE #( %cid = ls_key-%cid
                          %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                        text     = lv_text ) ) TO reported-usersetting.
        ENDLOOP.
        CONTINUE.
      ENDIF.

      " 결과: 보낸 항목마다 한 줄 + 요약 메시지
      LOOP AT lt_result INTO DATA(ls_result).
        APPEND VALUE #( %cid   = ls_key-%cid
                        %param = ls_result ) TO result.
      ENDLOOP.

      APPEND VALUE #( %cid = ls_key-%cid
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-success
                               text     = |저장 완료: { lines( lt_change ) }건 변경, { lines( lt_result ) - lines( lt_change ) }건 변경 없음| ) )
             TO reported-usersetting.
    ENDLOOP.
  ENDMETHOD.


  METHOD read.
    " 지금 API 는 여기를 안 탄다 (조회 = 쿼리 클래스, 액션 응답 = 액션이 직접 채움).
    " READ ENTITIES 로 읽을 때를 위한 최소 구현. 본인 것만.
    DATA lt_row TYPE zcl_cmup_q_usersetting=>tt_row.
    DATA(lv_me) = CONV zif_cmup_user_api=>ty_user( cl_abap_context_info=>get_user_technical_name( ) ).

    LOOP AT keys INTO DATA(ls_key) GROUP BY ls_key-UserId INTO DATA(lv_user).
      CLEAR lt_row.
      IF lv_user = lv_me.
        TRY.
            lt_row = zcl_cmup_q_usersetting=>build_rows( lv_user ).
          CATCH zcx_cmup_user_api zcx_cmup_query.
            CLEAR lt_row.
        ENDTRY.
      ENDIF.

      LOOP AT GROUP lv_user INTO DATA(ls_member).
        READ TABLE lt_row INTO DATA(ls_row) WITH KEY itemid = ls_member-ItemId.
        IF sy-subrc = 0.
          APPEND CORRESPONDING #( ls_row ) TO result.
        ELSE.
          APPEND VALUE #( %tky        = ls_member-%tky
                          %fail-cause = COND #( WHEN lv_user = lv_me THEN if_abap_behv=>cause-not_found
                                                ELSE if_abap_behv=>cause-unauthorized ) ) TO failed-usersetting.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD lock.
    " 잠금은 BAPI_USER_CHANGE 가 직접 건다 (SU01 에서 같은 사용자를 열고 있으면 그때 에러).
  ENDMETHOD.

ENDCLASS.


CLASS lsc_usersetting DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save REDEFINITION.
ENDCLASS.


CLASS lsc_usersetting IMPLEMENTATION.

  METHOD save.
    " 저장은 액션 saveSettings 안에서 바로 한다 (래퍼 → BAPI_USER_CHANGE + BAPI_TRANSACTION_COMMIT).
    " RAP 저장 단계에서 RFC·COMMIT 을 하면 LUW 덤프가 나기 때문에 여기는 비워 둔다.
  ENDMETHOD.

ENDCLASS.
