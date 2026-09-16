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
                           USING zdq_torditm zdq_tordhdr makt.

    -- 아이템 키는 UUID 이므로 업무 주문번호는 헤더에서 가져온다.
    -- 단위/통화가 섞인 합계를 만들지 않도록 단위·통화까지 그룹핑 기준에 넣는다.
    RETURN
      SELECT itm.client                     AS client,
             hdr.orderid                    AS orderid,
             itm.product                    AS product,
             COALESCE( txt.maktx, '' )      AS productname,
             SUM( itm.quantity )            AS totalqty,
             itm.quantityunit               AS quantityunit,
             SUM( itm.netamount )           AS totalamount,
             itm.currency                   AS currency,
             CAST( COUNT( * ) AS INTEGER )  AS itemcount
        FROM zdq_torditm AS itm
             INNER JOIN zdq_tordhdr AS hdr
               ON  hdr.client    = itm.client
               AND hdr.orderuuid = itm.orderuuid
             LEFT OUTER JOIN makt AS txt
               ON  txt.mandt = itm.client
               AND txt.matnr = itm.product
               AND txt.spras = :p_langu
       WHERE itm.client = :p_client
       GROUP BY itm.client,
                hdr.orderid,
                itm.product,
                itm.quantityunit,
                itm.currency,
                txt.maktx;

  ENDMETHOD.

ENDCLASS.
