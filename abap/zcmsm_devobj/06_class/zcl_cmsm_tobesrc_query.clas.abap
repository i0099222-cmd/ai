"! To-Be 데이터 소스 (최하위까지) — custom entity ZCE_CMSM_TobeSource 의 쿼리 클래스
"!
"! 래퍼 ZCL_CMSM_DDL_WHERE_USED=>source_chain( )(12_wrapper, Standard ABAP)이 CDS 소스 원문(DDDDLSRC)에서
"!   메인 데이터 소스(as select from … / as projection on …)를 읽고, 그게 CDS 면 또 그 CDS 의 메인 소스를…
"!   테이블(최하위)이 나올 때까지 따라 내려간다 (최대 10단계, 같은 이름이 다시 나오면 멈춤). 여기선 행만 만든다.
"! view entity·DDIC 기반 define view·projection·표준 SAP CDS 다 된다 (예전 XCO 방식은 view entity 가 아니면 멈췄다)
"! 안 나오는 것: join 대상·연관(메인 소스만 따라감). To-Be 가 CDS 가 아니면(테이블·클래스 등) 빈 목록
CLASS zcl_cmsm_tobesrc_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

ENDCLASS.


CLASS zcl_cmsm_tobesrc_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

    DATA lt_result TYPE STANDARD TABLE OF zce_cmsm_tobesource WITH EMPTY KEY.
    DATA lt_page   LIKE lt_result.

    " 1) 필터에서 To-Be 이름 (매핑 상세에서 열면 연관 조건 TobeName = 그 To-Be 이름이 들어온다)
    TRY.
        DATA(lt_filter) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR lt_filter.
    ENDTRY.

    LOOP AT lt_filter INTO DATA(ls_filter) WHERE name = 'TOBENAME'.
      LOOP AT ls_filter-range INTO DATA(ls_range) WHERE sign = 'I' AND option = 'EQ'.

        DATA(lv_tobe) = to_upper( condense( CONV string( ls_range-low ) ) ).
        IF lv_tobe IS INITIAL OR line_exists( lt_result[ tobename = lv_tobe ] ).
          CONTINUE.
        ENDIF.

        " 2) 래퍼: 메인 데이터 소스를 최하위까지 (위에서 아래 순)
        DATA(lt_chain) = zcl_cmsm_ddl_where_used=>source_chain( lv_tobe ).
        LOOP AT lt_chain INTO DATA(ls_chain).
          APPEND VALUE #( tobename = lv_tobe
                          srcname  = ls_chain-srcname
                          srckind  = ls_chain-srckind
                          usedby   = ls_chain-usedby ) TO lt_result.
        ENDLOOP.

      ENDLOOP.
    ENDLOOP.

    " 3) 건수·페이징 (순서는 위에서 아래 순, 요청 정렬 정보는 읽기만)
    DATA(lt_sort) = io_request->get_sort_elements( ).

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_result ) ).
    ENDIF.

    IF io_request->is_data_requested( ).
      DATA(lv_offset) = io_request->get_paging( )->get_offset( ).
      DATA(lv_size)   = io_request->get_paging( )->get_page_size( ).
      IF lv_size = if_rap_query_paging=>page_size_unlimited.
        lv_size = lines( lt_result ).
      ENDIF.
      DATA(lv_from) = lv_offset + 1.
      LOOP AT lt_result INTO DATA(ls_row) FROM lv_from.
        IF lines( lt_page ) >= lv_size.
          EXIT.
        ENDIF.
        APPEND ls_row TO lt_page.
      ENDLOOP.
      io_response->set_data( lt_page ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
