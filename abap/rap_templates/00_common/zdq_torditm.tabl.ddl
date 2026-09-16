@EndUserText.label : '구매주문 아이템 (RAP 템플릿 공통 CBO)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #ALLOWED
define table zdq_torditm {

  key client       : abap.clnt not null;

  @EndUserText.label : '주문번호'
  key order_id     : abap.char(10) not null;

  @EndUserText.label : '주문아이템'
  key item_no      : abap.numc(5) not null;

  @EndUserText.label : '자재'
  product          : matnr;

  @EndUserText.label : '주문수량'
  @Semantics.quantity.unitOfMeasure : 'zdq_torditm.quantity_unit'
  quantity         : abap.quan(13,3);

  @EndUserText.label : '수량단위'
  quantity_unit    : meins;

  @EndUserText.label : '아이템금액'
  @Semantics.amount.currencyCode : 'zdq_torditm.currency'
  net_amount       : abap.curr(15,2);

  @EndUserText.label : '통화'
  currency         : waers;

  @EndUserText.label : '납기일'
  delivery_date    : abap.dats;

  include zscm00010;

}
