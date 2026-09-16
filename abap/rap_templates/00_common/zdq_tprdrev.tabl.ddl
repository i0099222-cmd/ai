@EndUserText.label : '자재 검토상태 (RAP 템플릿 공통 CBO)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #ALLOWED
define table zdq_tprdrev {

  key client       : abap.clnt not null;

  -- 표준 CDS(I_Product) 와 조인해야 하므로 자재코드가 키다. UUID 를 쓰지 않는다.
  @EndUserText.label : '자재'
  key product      : matnr not null;

  -- 01:미검토 / 02:검토중 / 03:승인
  @EndUserText.label : '검토상태'
  reviewstatus     : abap.char(2);

  @EndUserText.label : '검토메모'
  reviewnote       : abap.char(60);

  include zscm00010;

}
