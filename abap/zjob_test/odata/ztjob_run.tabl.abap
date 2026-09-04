@EndUserText.label : 'Application Job 스케줄 실행 로그 (OData 제어용)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztjob_run {

  key client            : abap.clnt not null;
  key run_uuid          : sysuuid_x16 not null;

  @EndUserText.label : 'Application Job 템플릿'
  job_template          : abap.char(60);
  @EndUserText.label : '백그라운드 잡 이름 (SM37)'
  job_name              : abap.char(32);
  @EndUserText.label : '백그라운드 잡 카운트 (SM37)'
  job_count             : abap.char(8);

  // --- 잡 파라미터 -----------------------------------------------------
  run_tag               : abap.char(20);
  rec_count             : abap.int4;
  sleep_secs            : abap.int4;
  force_fail            : abap_boolean;

  // --- 스케줄 옵션 (SM36 과 비교되는 핵심) ------------------------------
  start_immediately     : abap_boolean;
  start_date            : abap.dats;
  start_time            : abap.tims;
  timezone              : abap.char(6);
  recurrence_minutes    : abap.int4;
  end_date              : abap.dats;

  // --- 상태 ------------------------------------------------------------
  @EndUserText.label : '잡 상태 (S/R/F/E/C)'
  job_status            : abap.char(1);
  scheduled_at          : timestampl;
  last_checked_at       : timestampl;
  @EndUserText.label : '마지막 메시지'
  last_message          : abap.char(255);

  @Semantics.user.createdBy : true
  created_by            : abp_creation_user;
  @Semantics.systemDateTime.createdAt : true
  created_at            : abp_creation_tmstmp;
  @Semantics.user.localInstanceLastChangedBy : true
  last_changed_by       : abp_locinst_lastchange_user;
  @Semantics.systemDateTime.localInstanceLastChangedAt : true
  local_last_changed_at : abp_locinst_lastchange_tmstmp;

}
