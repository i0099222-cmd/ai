"! ② Value Help 조회 · ZCE_CMUP_ParamVH
"!
"!   GET ParamValueHelp(p_itemid='BUK')/Set?$search=서울&$top=50&$skip=0&$count=true
"!   지원 필터: ParamValue, ValueText
CLASS zcl_cmup_q_paramvh DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.


CLASS zcl_cmup_q_paramvh IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    DATA: lv_item_id   TYPE zif_cmup_user_api=>ty_item,
          lt_row       TYPE STANDARD TABLE OF zce_cmup_paramvh WITH EMPTY KEY,
          lt_value_rng TYPE if_rap_query_filter=>tt_range_option,
          lt_text_rng  TYPE if_rap_query_filter=>tt_range_option.

    " 파라미터 p_itemid (필수)
    DATA(lt_param) = io_request->get_parameters( ).
    LOOP AT lt_param INTO DATA(ls_param).
      IF to_upper( ls_param-parameter_name ) = 'P_ITEMID'.
        lv_item_id = to_upper( ls_param-value ).
      ENDIF.
    ENDLOOP.

    IF zcl_cmup_config=>get_item( lv_item_id ) IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cmup_query
        EXPORTING
          iv_text = |{ lv_item_id } 는 Value Help 대상 항목이 아닙니다|.
    ENDIF.

    " 필터
    DATA(lt_filter) = zcl_cmup_query_util=>get_ranges( io_request ).
    LOOP AT lt_filter INTO DATA(ls_filter).
      CASE ls_filter-name.
        WHEN 'PARAMVALUE'.
          lt_value_rng = ls_filter-range.
        WHEN 'VALUETEXT'.
          lt_text_rng = ls_filter-range.
        WHEN 'ITEMID'.
          " 파라미터와 같은 값이라 무시
        WHEN OTHERS.
          RAISE EXCEPTION TYPE zcx_cmup_query
            EXPORTING
              iv_text = |{ ls_filter-name } 필터는 지원하지 않습니다|.
      ENDCASE.
    ENDLOOP.

    " 데이터 (검색어는 코드·텍스트 포함 비교)
    DATA(lt_value) = zcl_cmup_value_help=>get_values( iv_item_id = lv_item_id
                                                      iv_search  = zcl_cmup_query_util=>get_search( io_request ) ).
    lt_row = VALUE #( FOR ls_value IN lt_value
                      ( itemid     = lv_item_id
                        paramvalue = ls_value-code
                        valuetext  = ls_value-text ) ).

    DELETE lt_row WHERE paramvalue NOT IN lt_value_rng OR valuetext NOT IN lt_text_rng.

    zcl_cmup_query_util=>respond( EXPORTING io_request  = io_request
                                            io_response = io_response
                                  CHANGING  ct_data     = lt_row ).
  ENDMETHOD.

ENDCLASS.
