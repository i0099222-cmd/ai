@EndUserText.label : '구매주문 헤더 (RAP 템플릿 공통 CBO)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #ALLOWED
define table zdq_tordhdr {

  key client       : abap.clnt not null;

  @EndUserText.label : '주문번호'
  key order_id     : abap.char(10) not null;

  @EndUserText.label : '주문일'
  order_date       : abap.dats;

  @EndUserText.label : '공급업체'
  supplier         : lifnr;

  @EndUserText.label : '플랜트'
  plant            : werks_d;

  @EndUserText.label : '통화'
  currency         : waers;

  @EndUserText.label : '주문총액'
  @Semantics.amount.currencyCode : 'zdq_tordhdr.currency'
  total_amount     : abap.curr(15,2);

  -- 01:작성중 / 02:릴리즈 / 03:종결
  @EndUserText.label : '주문상태'
  order_status     : abap.char(2);

  include zscm00010;

}
