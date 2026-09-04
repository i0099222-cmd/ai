@EndUserText.label : '배치잡 정의 스텝 (AS-IS ZBCS0012 / lt_pg 대응)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztjob_step {

  key client            : abap.clnt not null;
  key step_uuid         : sysuuid_x16 not null;

  @EndUserText.label : '잡 정의 ID'
  def_id                : sysuuid_x16;
  @EndUserText.label : '스텝 순번'
  step_no               : abap.int4;

  @EndUserText.label : '스텝 종류 (PROG/CMD/EXT)'
  pg_type               : abap.char(4);
  @EndUserText.label : '실행할 리포트'
  pg_id                 : abap.char(40);
  @EndUserText.label : '배리언트'
  pg_variant            : abap.char(14);
  @EndUserText.label : '실행 언어'
  pg_lang               : abap.lang;
  @EndUserText.label : '스텝 실행 사용자 (APJ 미지원 - 보관만)'
  step_user             : abap.char(12);

  @Semantics.user.localInstanceLastChangedBy : true
  last_changed_by       : abp_locinst_lastchange_user;
  @Semantics.systemDateTime.localInstanceLastChangedAt : true
  local_last_changed_at : abp_locinst_lastchange_tmstmp;

}
