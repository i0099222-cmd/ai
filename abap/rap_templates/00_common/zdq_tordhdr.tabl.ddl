@EndUserText.label : '구매주문 헤더 (RAP 템플릿 공통 CBO)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #ALLOWED
define table zdq_tordhdr {

  key client       : abap.clnt not null;

  -- 기술 키 : RAP 프레임워크가 생성 (numbering : managed)
  @EndUserText.label : '주문 UUID'
  key orderuuid    : sysuuid_x16 not null;

  -- 업무 키 : 사용자 입력. SE11 에서 유일 인덱스 생성 필요
  @EndUserText.label : '주문번호'
  orderid          : abap.char(10);

  @EndUserText.label : '주문일'
  orderdate        : abap.dats;

  @EndUserText.label : '공급업체'
  supplier         : lifnr;

  @EndUserText.label : '플랜트'
  plant            : werks_d;

  @EndUserText.label : '통화'
  currency         : waers;

  @EndUserText.label : '주문총액'
  @Semantics.amount.currencyCode : 'zdq_tordhdr.currency'
  totalamount      : abap.curr(15,2);

  -- 01:작성중 / 02:릴리즈 / 03:종결
  @EndUserText.label : '주문상태'
  orderstatus      : abap.char(2);

  include zscm00010;

}
