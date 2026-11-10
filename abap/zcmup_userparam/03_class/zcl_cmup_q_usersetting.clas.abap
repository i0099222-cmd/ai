"! ① 현재 설정 조회 · ZCE_CMUP_UserSetting
"!
"!   GET UserSetting?$filter=UserId eq 'HONG'   → 그 사용자의 항목 전체
"!   GET UserSetting                            → 로그온 사용자 본인
"!   지원 필터: UserId (eq 하나), ItemId, Category
CLASS zcl_cmup_q_usersetting DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

    TYPES tt_row TYPE STANDARD TABLE OF zce_cmup_usersetting WITH EMPTY KEY.

    "! 사용자 한 명의 화면용 행 (항목 목록 순서). 행위 클래스 read 에서도 쓴다.
    CLASS-METHODS build_rows
      IMPORTING iv_user       TYPE zif_cmup_user_api=>ty_user
      RETURNING VALUE(rt_row) TYPE tt_row
      RAISING   zcx_cmup_user_api.
ENDCLASS.


CLASS zcl_cmup_q_usersetting IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    DATA: lv_user     TYPE zif_cmup_user_api=>ty_user,
          lt_item_rng TYPE if_rap_query_filter=>tt_range_option,
          lt_cat_rng  TYPE if_rap_query_filter=>tt_range_option.

    " 필터
    DATA(lt_filter) = zcl_cmup_query_util=>get_ranges( io_request ).
    LOOP AT lt_filter INTO DATA(ls_filter).
      CASE ls_filter-name.
        WHEN 'USERID'.
          IF    lines( ls_filter-range ) <> 1
             OR ls_filter-range[ 1 ]-sign   <> 'I'
             OR ls_filter-range[ 1 ]-option <> 'EQ'.
            RAISE EXCEPTION TYPE zcx_cmup_query
              EXPORTING
                iv_text = `UserId 는 eq 조건 하나만 됩니다`.
          ENDIF.
          lv_user = to_upper( ls_filter-range[ 1 ]-low ).
        WHEN 'ITEMID'.
          lt_item_rng = ls_filter-range.
        WHEN 'CATEGORY'.
          lt_cat_rng = ls_filter-range.
        WHEN OTHERS.
          RAISE EXCEPTION TYPE zcx_cmup_query
            EXPORTING
              iv_text = |{ ls_filter-name } 필터는 지원하지 않습니다|.
      ENDCASE.
    ENDLOOP.

    " 사용자
    lv_user = zcl_cmup_config=>resolve_user( lv_user ).
    IF zcl_cmup_config=>is_user_allowed( lv_user ) = abap_false.
      RAISE EXCEPTION TYPE zcx_cmup_query
        EXPORTING
          iv_text = |다른 사용자({ lv_user })의 설정은 조회할 수 없습니다|.
    ENDIF.

    " 데이터
    TRY.
        DATA(lt_row) = build_rows( lv_user ).
      CATCH zcx_cmup_user_api INTO DATA(lx_api).
        RAISE EXCEPTION TYPE zcx_cmup_query
          EXPORTING
            iv_text  = lx_api->get_text( )
            previous = lx_api.
    ENDTRY.

    DELETE lt_row WHERE itemid NOT IN lt_item_rng OR category NOT IN lt_cat_rng.

    zcl_cmup_query_util=>respond( EXPORTING io_request  = io_request
                                            io_response = io_response
                                  CHANGING  ct_data     = lt_row ).
  ENDMETHOD.


  METHOD build_rows.
    DATA(lt_setting) = zcl_cmup_user_api=>create( )->get_settings( iv_user ).

    " 포털 항목만, 설정 안 한 항목도 빈 값으로 한 줄씩 (웹 화면 칸이 항상 다 나오게)
    DATA(lt_item) = zcl_cmup_config=>get_items( ).
    LOOP AT lt_item INTO DATA(ls_item).
      DATA(lv_value) = VALUE zif_cmup_user_api=>ty_value( lt_setting[ item_id = ls_item-item_id ]-value OPTIONAL ).

      APPEND VALUE #( userid     = iv_user
                      itemid     = ls_item-item_id
                      category   = ls_item-category
                      areaname   = ls_item-area_name
                      itemname   = ls_item-item_name
                      paramvalue = lv_value
                      valuetext  = zcl_cmup_value_help=>get_text( iv_item_id = ls_item-item_id
                                                                  iv_value   = lv_value )
                      sortorder  = ls_item-sort_no ) TO rt_row.
    ENDLOOP.

    SORT rt_row BY sortorder.
  ENDMETHOD.

ENDCLASS.
