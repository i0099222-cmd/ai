"! Case6 custom entity 조회 구현. 필터/건수/페이징을 직접 처리한다.
CLASS zcl_dq_ce_display_query DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

ENDCLASS.


CLASS zcl_dq_ce_display_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

    DATA order_range   TYPE RANGE OF zdq_torditm-order_id.
    DATA product_range TYPE RANGE OF zdq_torditm-product.
    DATA items         TYPE STANDARD TABLE OF zdq_ce_custom_ent_display WITH EMPTY KEY.

    " 1) OData 필터를 RANGE 로 변환
    TRY.
        DATA(filters) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range INTO DATA(filter_error).
        RAISE EXCEPTION TYPE cx_rap_query_provider
          EXPORTING previous = filter_error.
    ENDTRY.

    LOOP AT filters INTO DATA(filter).
      CASE to_upper( filter-name ).
        WHEN 'ORDERID'. order_range   = CORRESPONDING #( filter-range ).
        WHEN 'PRODUCT'. product_range = CORRESPONDING #( filter-range ).
      ENDCASE.
    ENDLOOP.

    " 2) 전체 건수 ($count)
    IF io_request->is_total_numb_of_rec_requested( ).
      SELECT COUNT(*) FROM zdq_torditm
        WHERE order_id IN @order_range
          AND product  IN @product_range
        INTO @DATA(record_count).

      io_response->set_total_number_of_records( record_count ).
    ENDIF.

    " 3) 데이터 ($top / $skip)
    IF io_request->is_data_requested( ).
      DATA(paging)    = io_request->get_paging( ).
      DATA(max_rows)  = paging->get_page_size( ).
      DATA(skip_rows) = paging->get_offset( ).

      IF max_rows = if_rap_query_paging=>page_size_unlimited.
        max_rows = 0.
      ENDIF.

      SELECT FROM zdq_torditm AS itm
             LEFT OUTER JOIN I_ProductDescription AS txt
               ON  txt~Product  = itm~product
               AND txt~Language = @sy-langu
        FIELDS itm~order_id           AS orderid,
               itm~item_no            AS itemno,
               itm~product            AS product,
               txt~ProductDescription AS productdescription,
               itm~quantity           AS quantity,
               itm~quantity_unit      AS quantityunit,
               itm~net_amount         AS netamount,
               itm~currency           AS currency,
               itm~delivery_date      AS deliverydate
        WHERE itm~order_id IN @order_range
          AND itm~product  IN @product_range
        ORDER BY itm~order_id, itm~item_no
        INTO CORRESPONDING FIELDS OF TABLE @items
        UP TO @max_rows ROWS
        OFFSET @skip_rows.

      io_response->set_data( items ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
