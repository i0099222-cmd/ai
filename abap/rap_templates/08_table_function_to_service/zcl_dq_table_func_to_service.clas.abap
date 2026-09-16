"! Case8 table function 구현 (AMDP / SQLScript).
CLASS zcl_dq_table_func_to_service DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_amdp_marker_hdb.

    CLASS-METHODS get_order_summary
      FOR TABLE FUNCTION zdq_tf_table_func_to_service.

ENDCLASS.


CLASS zcl_dq_table_func_to_service IMPLEMENTATION.

  METHOD get_order_summary BY DATABASE FUNCTION FOR HDB
                           LANGUAGE SQLSCRIPT
                           OPTIONS READ-ONLY
                           USING zdq_torditm makt.

    -- 단위/통화가 섞인 합계를 만들지 않도록 단위·통화까지 그룹핑 기준에 넣는다.
    RETURN
      SELECT itm.client                     AS client,
             itm.order_id                   AS order_id,
             itm.product                    AS product,
             COALESCE( txt.maktx, '' )      AS product_name,
             SUM( itm.quantity )            AS total_qty,
             itm.quantity_unit              AS quantity_unit,
             SUM( itm.net_amount )          AS total_amount,
             itm.currency                   AS currency,
             CAST( COUNT( * ) AS INTEGER )  AS item_count
        FROM zdq_torditm AS itm
             LEFT OUTER JOIN makt AS txt
               ON  txt.mandt = itm.client
               AND txt.matnr = itm.product
               AND txt.spras = :p_langu
       WHERE itm.client = :p_client
       GROUP BY itm.client,
                itm.order_id,
                itm.product,
                itm.quantity_unit,
                itm.currency,
                txt.maktx;

  ENDMETHOD.

ENDCLASS.
