@EndUserText.label : '구매주문 아이템 Draft (Case 3)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zdq_torditm_d {

  key client    : abap.clnt not null;
  key orderuuid : sysuuid_x16 not null;
  key itemuuid  : sysuuid_x16 not null;

  itemno        : abap.numc(5);
  product       : matnr;

  @Semantics.quantity.unitOfMeasure : 'zdq_torditm_d.quantityunit'
  quantity      : abap.quan(13,3);
  quantityunit  : meins;

  @Semantics.amount.currencyCode : 'zdq_torditm_d.currency'
  netamount     : abap.curr(15,2);
  currency      : waers;

  deliverydate  : abap.dats;

  include zscm00010;

  -- RAP draft 관리 필드
  include sych_bdl_draft_admin_inc;

}
