@EndUserText.label: 'Case8: 주문-자재별 집계 (Table Function)'
@ClientHandling.algorithm: #SESSION_VARIABLE
define table function ZDQ_TF_TABLE_FUNC_TO_SERVICE
  with parameters
    @Environment.systemField: #CLIENT
    p_client      : abap.clnt,
    @Environment.systemField: #SYSTEM_LANGUAGE
    p_langu       : abap.lang
  returns {
    client        : abap.clnt;
    order_id      : abap.char(10);
    product       : matnr;
    product_name  : abap.char(40);

    @Semantics.quantity.unitOfMeasure: 'quantity_unit'
    total_qty     : abap.quan(13,3);
    @Semantics.unitOfMeasure: true
    quantity_unit : meins;

    @Semantics.amount.currencyCode: 'currency'
    total_amount  : abap.curr(15,2);
    @Semantics.currencyCode: true
    currency      : waers;

    item_count    : abap.int4;
  }
  implemented by method zcl_dq_table_func_to_service=>get_order_summary;
