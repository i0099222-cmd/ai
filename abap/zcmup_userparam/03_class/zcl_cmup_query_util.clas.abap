"! custom entity 쿼리 공통 처리
"!
"! 요청에 $filter / $orderby / $skip·$top 이 있는데 쿼리 클래스가 꺼내 가지 않으면
"! 프레임워크가 에러를 내므로, 두 쿼리 클래스 모두 여기를 거친다.
CLASS zcl_cmup_query_util DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    "! $filter → 필드별 범위 테이블. 범위로 못 바꾸는 조건(contains 등)은 에러
    CLASS-METHODS get_ranges
      IMPORTING io_request      TYPE REF TO if_rap_query_request
      RETURNING VALUE(rt_range) TYPE if_rap_query_filter=>tt_name_range_pairs
      RAISING   cx_rap_query_provider.

    "! $search 검색어 (따옴표 제거)
    CLASS-METHODS get_search
      IMPORTING io_request       TYPE REF TO if_rap_query_request
      RETURNING VALUE(rv_search) TYPE string
      RAISING   cx_rap_query_provider.

    "! 정렬($orderby) → 전체 건수($count) → 페이징($skip/$top) → 응답
    "! ct_data = 필터·검색이 끝난 전체 결과
    CLASS-METHODS respond
      IMPORTING io_request  TYPE REF TO if_rap_query_request
                io_response TYPE REF TO if_rap_query_response
      CHANGING  ct_data     TYPE STANDARD TABLE
      RAISING   cx_rap_query_provider.
ENDCLASS.


CLASS zcl_cmup_query_util IMPLEMENTATION.

  METHOD get_ranges.
    TRY.
        rt_range = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range INTO DATA(lx_range).
        RAISE EXCEPTION TYPE zcx_cmup_query
          EXPORTING
            iv_text  = `필터는 eq / ne / 범위(ge, le …) 조건만 지원합니다`
            previous = lx_range.
    ENDTRY.
  ENDMETHOD.


  METHOD get_search.
    rv_search = io_request->get_search_expression( ).
    REPLACE ALL OCCURRENCES OF `"` IN rv_search WITH ``.
    CONDENSE rv_search.
  ENDMETHOD.


  METHOD respond.
    " 정렬
    DATA lt_order TYPE abap_sortorder_tab.
    DATA(lt_sort) = io_request->get_sort_elements( ).
    LOOP AT lt_sort INTO DATA(ls_sort).
      APPEND VALUE #( name = ls_sort-element_name descending = ls_sort-descending ) TO lt_order.
    ENDLOOP.
    IF lt_order IS NOT INITIAL.
      SORT ct_data BY (lt_order).
    ENDIF.

    " 전체 건수 (페이징 전)
    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( ct_data ) ).
    ENDIF.

    " 페이징
    DATA(lo_paging) = io_request->get_paging( ).
    DATA(lv_offset) = lo_paging->get_offset( ).
    DATA(lv_size)   = lo_paging->get_page_size( ).

    IF lv_offset >= lines( ct_data ).
      CLEAR ct_data.
    ELSEIF lv_offset > 0.
      DELETE ct_data TO lv_offset.
    ENDIF.

    IF lv_size <> if_rap_query_paging=>page_size_unlimited AND lines( ct_data ) > lv_size.
      DATA(lv_from) = lv_size + 1.
      DELETE ct_data FROM lv_from.
    ENDIF.

    IF io_request->is_data_requested( ).
      io_response->set_data( ct_data ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
