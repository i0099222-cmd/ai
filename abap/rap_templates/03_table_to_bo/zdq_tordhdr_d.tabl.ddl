@EndUserText.label : '구매주문 헤더 Draft (Case 3)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table zdq_tordhdr_d {

  key client    : abap.clnt not null;
  key orderuuid : sysuuid_x16 not null;

  orderid       : abap.char(10);
  orderdate     : abap.dats;
  supplier      : lifnr;
  plant         : werks_d;
  currency      : waers;

  @Semantics.amount.currencyCode : 'zdq_tordhdr_d.currency'
  totalamount   : abap.curr(15,2);

  orderstatus   : abap.char(2);

  include zscm00010;

  -- RAP draft 관리 필드
  include sych_bdl_draft_admin_inc;

}
