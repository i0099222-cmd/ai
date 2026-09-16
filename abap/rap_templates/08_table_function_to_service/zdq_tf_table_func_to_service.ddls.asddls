@EndUserText.label: 'Case8: 주문-자재별 집계 (Table Function)'
@ClientHandling.algorithm: #SESSION_VARIABLE
define table function ZDQ_TF_TABLE_FUNC_TO_SERVICE
  with parameters
    @Environment.systemField: #CLIENT
    p_client     : abap.clnt,
    @Environment.systemField: #SYSTEM_LANGUAGE
    p_langu      : abap.lang
  returns {
    client       : abap.clnt;
    orderid      : abap.char(10);
    product      : matnr;
    productname  : abap.char(40);

    @Semantics.quantity.unitOfMeasure: 'quantityunit'
    totalqty     : abap.quan(13,3);
    @Semantics.unitOfMeasure: true
    quantityunit : meins;

    @Semantics.amount.currencyCode: 'currency'
    totalamount  : abap.curr(15,2);
    @Semantics.currencyCode: true
    currency     : waers;

    itemcount    : abap.int4;
  }
  implemented by method zcl_dq_table_func_to_service=>get_order_summary;
