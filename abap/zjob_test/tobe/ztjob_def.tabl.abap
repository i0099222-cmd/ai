@EndUserText.label : '배치잡 정의 헤더 (AS-IS ZBCS0011 대응)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztjob_def {

  key client            : abap.clnt not null;
  key def_id            : sysuuid_x16 not null;

  // --- AS-IS 가 SAP 잡 개념 위에 얹은 필드 ------------------------------
  @EndUserText.label : '시스템'
  sys_id                : abap.char(8);
  @EndUserText.label : '대상 클라이언트'
  target_client         : abap.char(3);
  @EndUserText.label : '업무구분'
  biz_area              : abap.char(20);
  @EndUserText.label : '요청사유'
  req_reason            : abap.char(255);
  @EndUserText.label : '요청자 사번'
  req_id                : abap.char(12);
  @EndUserText.label : '요청자 이름'
  req_name              : abap.char(40);
  @EndUserText.label : '요청 시각'
  req_datetime          : timestampl;

  // --- 논리 잡 이름 ------------------------------------------------------
  // APJ 는 잡 이름을 자동 생성하므로 사용자가 지정한 이름은 여기 보관하고
  // SM37 의 실제 잡 이름과는 ZTJOB_RUN 에서 매핑한다. (COMPARISON #16)
  @EndUserText.label : '논리 잡 이름'
  job_label             : abap.char(32);
  @EndUserText.label : '배치잡 클래스 (APJ 미지원 - 보관만)'
  job_class             : abap.char(1);
  @EndUserText.label : '기본 실행 사용자 (APJ 미지원 - 보관만)'
  job_user              : abap.char(12);

  // --- 실행 조건. APJ 스케줄로 못 거는 것은 런처가 판정한다. --------------
  @EndUserText.label : 'close 일 (이 시각 넘으면 실행 안 함)'
  last_start_date       : abap.dats;
  @EndUserText.label : 'close 시각'
  last_start_time       : abap.tims;
  @EndUserText.label : '팩토리 캘린더 ID'
  calendar_id           : abap.char(2);
  @EndUserText.label : '작업일 번호 (0 = 작업일이기만 하면 실행)'
  workday_nr            : abap.int4;
  @EndUserText.label : '작업일 최소 시각'
  workday_time          : abap.tims;

  @EndUserText.label : '사용 여부'
  is_active             : abap_boolean;

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
