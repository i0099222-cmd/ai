@EndUserText.label : '배치잡 스케줄 (AS-IS ZBCS0011 대응)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztjob_run {

  key client            : abap.clnt not null;
  key run_uuid          : sysuuid_x16 not null;

  // ===== AS-IS ZBCS0011 =================================================

  // --- SAP 잡 개념이 아닌, 인터페이스가 얹은 필드 ------------------------
  @EndUserText.label : '시스템'
  sys_id                : abap.char(8);
  @EndUserText.label : '대상 클라이언트'
  target_client         : abap.char(3);
  @EndUserText.label : '업무구분'
  biz_area              : abap.char(20);

  @EndUserText.label : '요청자 사번'
  req_id                : abap.char(12);
  @EndUserText.label : '요청자 이름'
  req_name              : abap.char(40);
  @EndUserText.label : '요청 시각'
  req_datetime          : timestampl;
  @EndUserText.label : '요청사유'
  req_reason            : abap.char(255);

  // --- 잡 이름/클래스/유저 -----------------------------------------------
  // APJ 는 잡 이름을 자동 생성하므로 사용자가 지정한 이름은 논리명으로 보관하고
  // SM37 의 실제 이름(job_name)과 나란히 둔다. (COMPARISON #16)
  @EndUserText.label : '배치잡 명 (논리)'
  job_label             : abap.char(32);
  @EndUserText.label : '배치잡 클래스 (APJ 미지원 - 보관만)'
  job_class             : abap.char(1);
  @EndUserText.label : '배치 유저명 (APJ 미지원 - 보관만)'
  job_user              : abap.char(12);

  // --- 시작 조건 (APJ 스케줄 옵션으로 전달) ------------------------------
  @EndUserText.label : '즉시 시작'
  start_immediately     : abap_boolean;
  @EndUserText.label : '배치잡 시작일'
  start_date            : abap.dats;
  @EndUserText.label : '배치잡 시작시각'
  start_time            : abap.tims;
  @EndUserText.label : '시스템 zone시간'
  timezone              : abap.char(6);

  // --- 반복 주기 (하나만 채운다) -----------------------------------------
  prd_mins              : abap.int4;
  prd_hours             : abap.int4;
  @EndUserText.label : '일반복주기'
  prd_days              : abap.int4;
  prd_weeks             : abap.int4;
  prd_months            : abap.int4;

  // --- APJ 스케줄 옵션에 없어서 런처가 판정하는 조건 ----------------------
  @EndUserText.label : 'close 일 (넘으면 실행 안 함)'
  last_start_date       : abap.dats;
  @EndUserText.label : 'close 시각'
  last_start_time       : abap.tims;
  @EndUserText.label : '공장시간 (팩토리 캘린더 ID)'
  calendar_id           : abap.char(2);
  @EndUserText.label : '공장근무일수'
  workday_nr            : abap.int4;
  @EndUserText.label : '공장근무시간'
  workday_time          : abap.tims;

  // ===== APJ 가 만들어준 것 ==============================================
  @EndUserText.label : 'APJ 잡 템플릿'
  job_template          : abap.char(60);
  @EndUserText.label : '백그라운드 잡 이름 (SM37)'
  job_name              : abap.char(32);
  @EndUserText.label : '백그라운드 잡 카운트 (SM37)'
  job_count             : abap.char(8);

  // ===== 상태 ===========================================================
  @EndUserText.label : '상태 (S/R/F/E/C/K)'
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
  @Semantics.systemDateTime.lastChangedAt : true
  last_changed_at       : abp_lastchange_tmstmp;

}
