"! ② Value Help 조회 · ZCE_CMUP_ParamVH
"!
"!   GET ParamValueHelp(p_itemid='BUK')/Set?$search=서울&$top=50&$skip=0&$count=true
"!   p_itemid = 파라미터 ID (사용자정보 항목은 팝업 대상이 아님)
"!   $search  = 코드·텍스트에 포함된 것 (대소문자 무시)
"!   $orderby 는 받지 않는다 (코드 순 고정)
CLASS zcl_cmup_q_paramvh DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.


CLASS zcl_cmup_q_paramvh IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    TYPES tt_row TYPE STANDARD TABLE OF zce_cmup_paramvh WITH EMPTY KEY.
    DATA lv_item_id TYPE zif_cmup_user_api=>ty_item.

    " 파라미터 p_itemid (필수)
    DATA(lt_param) = io_request->get_parameters( ).
    LOOP AT lt_param INTO DATA(ls_param).
      IF to_upper( ls_param-parameter_name ) = 'P_ITEMID'.
        lv_item_id = to_upper( ls_param-value ).
      ENDIF.
    ENDLOOP.

    IF zcl_cmup_config=>get_item( lv_item_id )-category <> zcl_cmup_config=>c_category-parameter.
      RAISE EXCEPTION TYPE zcx_cmup_query
        EXPORTING
          iv_text = |{ lv_item_id } 는 Value Help 대상 파라미터가 아닙니다|.
    ENDIF.

    " 목록 + 검색어 ($search, 따옴표 제거 / CS = 대소문자 구분 없는 '포함' 비교)
    DATA(lt_value)  = zcl_cmup_value_help=>read_source( lv_item_id ).
    DATA(lv_search) = io_request->get_search_expression( ).
    REPLACE ALL OCCURRENCES OF `"` IN lv_search WITH ``.
    CONDENSE lv_search.
    IF lv_search IS NOT INITIAL.
      DELETE lt_value WHERE NOT ( code CS lv_search OR text CS lv_search ).
    ENDIF.

    DATA(lt_row) = VALUE tt_row( FOR ls_value IN lt_value
                                 ( itemid     = lv_item_id
                                   paramvalue = ls_value-code
                                   valuetext  = ls_value-text ) ).

    " 응답: 전체 건수($count) → 페이징($skip / $top)
    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_row ) ).
    ENDIF.

    IF io_request->is_data_requested( ).
      DATA(lo_paging) = io_request->get_paging( ).
      DATA(lv_from)   = CONV i( lo_paging->get_offset( ) + 1 ).
      DATA(lv_to)     = COND i( WHEN lo_paging->get_page_size( ) = if_rap_query_paging=>page_size_unlimited
                                THEN lines( lt_row )
                                ELSE lo_paging->get_offset( ) + lo_paging->get_page_size( ) ).
      io_response->set_data( VALUE tt_row( FOR ls_row IN lt_row FROM lv_from TO lv_to ( ls_row ) ) ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
