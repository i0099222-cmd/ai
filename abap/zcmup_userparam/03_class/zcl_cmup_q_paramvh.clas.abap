"! ② Value Help 조회 · ZCE_CMUP_ParamVH
"!
"!   GET ParamValueHelp(p_itemid='BUK')/Set?$search="서울"&$top=50&$skip=0&$count=true
"!   p_itemid = 항목 ID (zcl_cmup_value_help 상수에 있는 것만, '/' 가 들어간 PID 는 별칭)
"!   $search  = 코드나 이름에 포함된 것 (대소문자 무시, 따옴표로 감싸 보내도 됨)
"!   $count   = 검색 후 전체 건수
"!   $top     = 없으면 100건. 더 있으면 응답에 @odata.nextLink ($skiptoken) 가 붙는다
"!   $filter / $orderby 는 받지 않는다 (코드 순 고정)
CLASS zcl_cmup_q_paramvh DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

  PRIVATE SECTION.
    CONSTANTS c_default_page_size TYPE i VALUE 100.
ENDCLASS.


CLASS zcl_cmup_q_paramvh IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    TYPES tt_row TYPE STANDARD TABLE OF zce_cmup_paramvh WITH EMPTY KEY.

    DATA: lv_param_id TYPE zcl_cmup_value_help=>ty_param_id,
          lt_page     TYPE tt_row.

    " 1) 파라미터 p_itemid
    DATA(lt_param) = io_request->get_parameters( ).
    LOOP AT lt_param INTO DATA(ls_param).
      IF to_upper( ls_param-parameter_name ) = 'P_ITEMID'.
        lv_param_id = to_upper( ls_param-value ).
      ENDIF.
    ENDLOOP.

    " 2) 목록 (모르는 항목 ID 면 zcx_cmup_query → 400 에러)
    DATA(lt_value) = zcl_cmup_value_help=>read_source( lv_param_id ).

    " 3) 검색 ($search) · 코드나 이름에 포함된 것, 대소문자 무시
    "    검색어가 없어도 꼭 호출한다 (안 받아 가면 프레임워크가 501)
    "    웹이 "…" 로 감싸 보내면 따옴표를 떼고 문구 그대로 찾는다
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

    " 4) 전체 건수 ($count) · 검색으로 거른 뒤 기준
    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_row ) ).
    ENDIF.

    " 5) 페이징 ($skip / $top / nextLink 의 $skiptoken)
    "    요청한 페이지 크기를 넘으면 프레임워크가 page size overrun → 직접 세면서 담는다
    DATA(lo_paging) = io_request->get_paging( ).
    IF io_request->is_data_requested( ).
      DATA(lv_start) = CONV i( lo_paging->get_offset( ) + 1 ).
      DATA(lv_size)  = lo_paging->get_page_size( ).
      IF lv_size = if_rap_query_paging=>page_size_unlimited.
        lv_size = c_default_page_size.
      ENDIF.

      LOOP AT lt_row INTO DATA(ls_row) FROM lv_start.
        IF lines( lt_page ) >= lv_size.
          EXIT.
        ENDIF.
        APPEND ls_row TO lt_page.
      ENDLOOP.

      io_response->set_data( lt_page ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
