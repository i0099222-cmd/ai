"! Case7 custom entity 조회 구현.
CLASS zcl_dq_ce_action_query DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

ENDCLASS.


CLASS zcl_dq_ce_action_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

    DATA product_range TYPE RANGE OF matnr.
    DATA type_range    TYPE RANGE OF mtart.
    DATA reviews       TYPE STANDARD TABLE OF zdq_ce_custom_ent_action WITH EMPTY KEY.

    TRY.
        DATA(filters) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range INTO DATA(filter_error).
        RAISE EXCEPTION TYPE cx_rap_query_provider
          EXPORTING previous = filter_error.
    ENDTRY.

    LOOP AT filters INTO DATA(filter).
      CASE to_upper( filter-name ).
        WHEN 'PRODUCT'.     product_range = CORRESPONDING #( filter-range ).
        WHEN 'PRODUCTTYPE'. type_range    = CORRESPONDING #( filter-range ).
      ENDCASE.
    ENDLOOP.

    IF io_request->is_total_numb_of_rec_requested( ).
      SELECT COUNT(*) FROM I_Product AS prd
        WHERE prd~Product     IN @product_range
          AND prd~ProductType IN @type_range
        INTO @DATA(record_count).

      io_response->set_total_number_of_records( record_count ).
    ENDIF.

    IF io_request->is_data_requested( ).
      DATA(paging)    = io_request->get_paging( ).
      DATA(max_rows)  = paging->get_page_size( ).
      DATA(skip_rows) = paging->get_offset( ).

      IF max_rows = if_rap_query_paging=>page_size_unlimited.
        max_rows = 0.
      ENDIF.

      SELECT FROM I_Product AS prd
             LEFT OUTER JOIN zdq_tprdrev AS rev
               ON rev~product = prd~Product
             LEFT OUTER JOIN I_ProductDescription AS txt
               ON  txt~Product  = prd~Product
               AND txt~Language = @sy-langu
        FIELDS prd~Product            AS product,
               txt~ProductDescription AS productdescription,
               prd~ProductType        AS producttype,
               rev~review_status      AS reviewstatus,
               rev~review_note        AS reviewnote,
               rev~last_changed_by    AS lastchangedby,
               rev~last_changed_at    AS lastchangedat
        WHERE prd~Product     IN @product_range
          AND prd~ProductType IN @type_range
        ORDER BY prd~Product
        INTO CORRESPONDING FIELDS OF TABLE @reviews
        UP TO @max_rows ROWS
        OFFSET @skip_rows.

      io_response->set_data( reviews ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
