@EndUserText.label : '구매주문 아이템 (RAP 템플릿 공통 CBO)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #ALLOWED
define table zdq_torditm {

  key client       : abap.clnt not null;

  -- 상위 헤더 키를 아이템 키에 포함한다.
  -- 삭제 determination 에서도 부모를 알 수 있어야 헤더 총액 재계산이 가능하다.
  @EndUserText.label : '주문 UUID'
  key orderuuid    : sysuuid_x16 not null;

  @EndUserText.label : '아이템 UUID'
  key itemuuid     : sysuuid_x16 not null;

  @EndUserText.label : '주문아이템'
  itemno           : abap.numc(5);

  @EndUserText.label : '자재'
  product          : matnr;

  @EndUserText.label : '주문수량'
  @Semantics.quantity.unitOfMeasure : 'zdq_torditm.quantityunit'
  quantity         : abap.quan(13,3);

  @EndUserText.label : '수량단위'
  quantityunit     : meins;

  @EndUserText.label : '아이템금액'
  @Semantics.amount.currencyCode : 'zdq_torditm.currency'
  netamount        : abap.curr(15,2);

  @EndUserText.label : '통화'
  currency         : waers;

  @EndUserText.label : '납기일'
  deliverydate     : abap.dats;

  include zscm00010;

}
