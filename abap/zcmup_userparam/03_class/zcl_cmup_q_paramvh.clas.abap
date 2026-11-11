"! ② Value Help 조회 · ZCE_CMUP_ParamVH
"!
"!   GET ParamValueHelp(p_itemid='BUK')/Set?$search=서울&$top=50&$skip=0&$count=true
"!   p_itemid = 항목 ID: 파라미터(BUK …) 또는 사용자정보(DATFM, TZONE …) · zcl_cmup_value_help 상수에 있는 것만
"!   $search  = 코드·텍스트에 포함된 것 (대소문자 무시)
"!   $orderby 는 받지 않는다 (코드 순 고정)
CLASS zcl_cmup_q_paramvh DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.


CLASS zcl_cmup_q_paramvh IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    TYPES tt_row TYPE STANDARD TABLE OF zce_cmup_paramvh WITH EMPTY KEY.
    DATA lv_param_id TYPE zcl_cmup_value_help=>ty_param_id.

    " 파라미터 p_itemid
    DATA(lt_param) = io_request->get_parameters( ).
    LOOP AT lt_param INTO DATA(ls_param).
      IF to_upper( ls_param-parameter_name ) = 'P_ITEMID'.
        lv_param_id = to_upper( ls_param-value ).
      ENDIF.
    ENDLOOP.

    " 목록 (지원하지 않는 파라미터 ID 면 zcx_cmup_query → OData 에러 응답)
    DATA(lt_value) = zcl_cmup_value_help=>read_source( lv_param_id ).

    " 검색어 ($search, 따옴표 제거 / CS = 대소문자 구분 없는 '포함' 비교)
    DATA(lv_search) = io_request->get_search_expression( ).
    REPLACE ALL OCCURRENCES OF `"` IN lv_search WITH ``.
    CONDENSE lv_search.
    IF lv_search IS NOT INITIAL.
      DELETE lt_value WHERE NOT ( code CS lv_search OR text CS lv_search ).
    ENDIF.

    DATA(lt_row) = VALUE tt_row( FOR ls_value IN lt_value
                                 ( itemid     = lv_param_id
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
