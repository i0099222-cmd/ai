"! ② Value Help 조회 · ZCE_CMUP_ParamVH
"!
"!   GET ParamValueHelp(p_itemid='BUK')/Set?$search=서울&$top=50&$skip=0&$count=true
"!   p_itemid = 파라미터 ID (사용자정보 항목은 팝업 대상이 아님)
"!   $search  = 코드·텍스트에 포함된 것 (대소문자 무시)
CLASS zcl_cmup_q_paramvh DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.


CLASS zcl_cmup_q_paramvh IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    DATA: lv_item_id TYPE zif_cmup_user_api=>ty_item,
          lt_row     TYPE STANDARD TABLE OF zce_cmup_paramvh WITH EMPTY KEY.

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

    " 목록 + 검색어 (CS = 대소문자 구분 없는 '포함' 비교)
    DATA(lt_value)  = zcl_cmup_value_help=>read_source( lv_item_id ).
    DATA(lv_search) = zcl_cmup_query_util=>get_search( io_request ).
    IF lv_search IS NOT INITIAL.
      DELETE lt_value WHERE NOT ( code CS lv_search OR text CS lv_search ).
    ENDIF.

    lt_row = VALUE #( FOR ls_value IN lt_value
                      ( itemid     = lv_item_id
                        paramvalue = ls_value-code
                        valuetext  = ls_value-text ) ).

    zcl_cmup_query_util=>respond( EXPORTING io_request  = io_request
                                            io_response = io_response
                                  CHANGING  ct_data     = lt_row ).
  ENDMETHOD.

ENDCLASS.
