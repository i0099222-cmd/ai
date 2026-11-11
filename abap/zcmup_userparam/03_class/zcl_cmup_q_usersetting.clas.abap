"! ① 현재 설정 조회 · ZCE_CMUP_UserSetting
"!
"!   GET UserSetting   → 로그온 사용자의 항목 전체 (zcl_cmup_value_help=>get_item_ids 순서)
"!   필터·정렬·페이징은 받지 않는다 (본인 것만, 항목 수십 개)
CLASS zcl_cmup_q_usersetting DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

    TYPES tt_row TYPE STANDARD TABLE OF zce_cmup_usersetting WITH EMPTY KEY.

    "! 사용자 한 명의 행. 설정 안 한 항목도 빈 값으로 한 줄씩. 행위 클래스 read 에서도 쓴다.
    CLASS-METHODS build_rows
      IMPORTING iv_user       TYPE zif_cmup_user_api=>ty_user
      RETURNING VALUE(rt_row) TYPE tt_row
      RAISING   zcx_cmup_user_api
                zcx_cmup_query.
ENDCLASS.


CLASS zcl_cmup_q_usersetting IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    TRY.
        DATA(lt_row) = build_rows( CONV #( cl_abap_context_info=>get_user_technical_name( ) ) ).
      CATCH zcx_cmup_user_api INTO DATA(lx_api).
        RAISE EXCEPTION TYPE zcx_cmup_query
          EXPORTING
            iv_text  = lx_api->get_text( )
            previous = lx_api.
    ENDTRY.

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_row ) ).
    ENDIF.
    IF io_request->is_data_requested( ).
      io_response->set_data( lt_row ).
    ENDIF.
  ENDMETHOD.


  METHOD build_rows.
    DATA(lt_setting) = zcl_cmup_user_api=>create( )->get_settings( iv_user ).
    DATA(lt_item_id) = zcl_cmup_value_help=>get_item_ids( ).

    LOOP AT lt_item_id INTO DATA(lv_item_id).
      DATA(lv_value) = VALUE zif_cmup_user_api=>ty_value( lt_setting[ item_id = lv_item_id ]-value OPTIONAL ).

      " 값 텍스트 (1000 → 서울 본사, 4 → YYYY.MM.DD)
      DATA(lt_value) = zcl_cmup_value_help=>read_source( lv_item_id ).

      APPEND VALUE #( userid     = iv_user
                      itemid     = lv_item_id
                      paramvalue = lv_value
                      valuetext  = VALUE #( lt_value[ code = lv_value ]-text OPTIONAL ) ) TO rt_row.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
