"! ③ 저장 액션 테스트 · ADT 에서 F9 (Run As → ABAP Application (Console))
"!
"! EML 로 saveSettings 를 실행하고 COMMIT ENTITIES 까지 한다 → 웹이 POST 하는 것과 같은 경로.
"! 저장(BAPI + COMMIT)은 액션 안에서 바로 일어난다. 액션 단계에서 LUW 덤프가 나면
"! 래퍼가 같은 세션에서 COMMIT 하고 있는 것 → 프록시가 RFC 목적지로 호출하는지 확인.
"!
"! 본인 사용자의 SU3 가 실제로 바뀐다.
"! 되돌리려면 c_value 를 원래 값(1번에 출력됨)으로 바꿔 한 번 더 실행한다. 원래 없던 파라미터면 빈 값.
CLASS zcl_cmup_test_save DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.

  PRIVATE SECTION.
    CONSTANTS:
      "! 바꿔 볼 항목 (파라미터 ID 또는 DATFM 같은 사용자정보 항목)
      c_item  TYPE zif_cmup_user_api=>ty_item  VALUE 'EKO',
      "! 바꿔 볼 값 (Value Help 목록에 있는 값, 빈 값 = 파라미터 삭제)
      c_value TYPE zif_cmup_user_api=>ty_value VALUE '1000'.
ENDCLASS.


CLASS zcl_cmup_test_save IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    DATA(lv_me) = CONV zif_cmup_user_api=>ty_user( cl_abap_context_info=>get_user_technical_name( ) ).

    " 1. 저장 전 값
    TRY.
        DATA(lt_before) = zcl_cmup_user_api=>create( )->get_settings( lv_me ).
      CATCH zcx_cmup_user_api INTO DATA(lx_api).
        out->write( |래퍼 조회 에러: { lx_api->get_text( ) }| ).
        RETURN.
    ENDTRY.
    DATA(lv_old) = VALUE zif_cmup_user_api=>ty_value( lt_before[ item_id = c_item ]-value OPTIONAL ).
    out->write( |===== 1. 저장 전 : { lv_me } / { c_item } = '{ lv_old }' =====| ).
    IF lv_old = c_value.
      out->write( `  현재값과 같아서 BAPI 는 호출되지 않습니다. 다른 값으로 테스트하세요.` ).
    ENDIF.

    " 2. 액션 실행 (웹의 POST UserSetting/SAP__self.saveSettings 와 같다)
    MODIFY ENTITIES OF zce_cmup_usersetting
      ENTITY UserSetting
        EXECUTE saveSettings
        FROM VALUE #( ( %cid   = 'SAVE1'
                        %param = VALUE #( _items = VALUE #( ( itemid = c_item paramvalue = c_value ) ) ) ) )
      RESULT DATA(lt_result)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    out->write( `===== 2. 액션 =====` ).
    LOOP AT ls_reported-usersetting INTO DATA(ls_message).
      out->write( |  메시지: { ls_message-%msg->if_message~get_text( ) }| ).
    ENDLOOP.
    IF ls_failed-usersetting IS NOT INITIAL.
      out->write( `NG  검증 또는 BAPI 에서 막혀서 저장하지 않았습니다 (위 메시지)` ).
      ROLLBACK ENTITIES.
      RETURN.
    ENDIF.
    LOOP AT lt_result INTO DATA(ls_result).
      out->write( |OK  { ls_result-%param-ItemId } = '{ ls_result-%param-ParamValue }' { ls_result-%param-ValueText }| ).
    ENDLOOP.

    " 3. RAP 커밋 (저장 단계는 비어 있어 할 일이 없다. 웹 요청과 같은 순서로 맞춘 것)
    COMMIT ENTITIES RESPONSE OF zce_cmup_usersetting
      FAILED DATA(ls_commit_failed)
      REPORTED DATA(ls_commit_reported).
    DATA(lv_commit_rc) = sy-subrc.

    out->write( `===== 3. 커밋 =====` ).
    LOOP AT ls_commit_reported-%other INTO DATA(lo_message).
      out->write( |  메시지: { lo_message->if_message~get_text( ) }| ).
    ENDLOOP.
    IF lv_commit_rc = 0 AND ls_commit_failed IS INITIAL AND ls_commit_reported-%other IS INITIAL.
      out->write( `OK  커밋 성공` ).
    ELSE.
      out->write( `NG  커밋에서 문제가 있습니다 (위 메시지)` ).
    ENDIF.

    " 4. 다시 읽기
    TRY.
        DATA(lt_after) = zcl_cmup_user_api=>create( )->get_settings( lv_me ).
      CATCH zcx_cmup_user_api INTO lx_api.
        out->write( |래퍼 조회 에러: { lx_api->get_text( ) }| ).
        RETURN.
    ENDTRY.
    DATA(lv_new) = VALUE zif_cmup_user_api=>ty_value( lt_after[ item_id = c_item ]-value OPTIONAL ).
    out->write( |===== 4. 저장 후 : { c_item } = '{ lv_new }' =====| ).
    IF lv_new = c_value.
      out->write( `OK  반영됨 → SAP GUI 에서 SU3 를 새로 열어서도 확인하세요` ).
    ELSE.
      out->write( `NG  값이 그대로입니다 (래퍼 커밋 문제일 수 있음)` ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
