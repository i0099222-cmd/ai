@EndUserText.label : '배치잡 스케줄'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztjob_run {

  key client       : abap.clnt not null;
  key run_uuid     : sysuuid_x16 not null;

  // --- 스케줄 대상 -------------------------------------------------------
  @EndUserText.label : 'APJ 잡 템플릿'
  template         : abap.char(60);
  @EndUserText.label : '잡 텍스트 (논리 잡명)'
  jobtext          : abap.char(64);
  @EndUserText.label : '실행할 프로그램'
  pgmid            : abap.char(40);

  // 런처가 실행 시점에 읽는 값들을 JSON 으로 담는다.
  //   variant / calendar_id / workday_nr / workday_time /
  //   last_start_date / last_start_time
  // 시작일시·반복주기·타임존은 여기 없다. APJ 가 갖고 있으므로 중복 저장하지 않는다.
  @EndUserText.label : '런처 전달 파라미터 (JSON)'
  param            : abap.string(0);

  // --- APJ 가 만들어준 것 ------------------------------------------------
  @EndUserText.label : '백그라운드 잡 이름 (SM37)'
  jobname          : abap.char(32);
  // APJ 잡의 키는 jobname + jobcount 다. 이게 없으면
  // GET_JOB_STATUS / CANCEL_JOB 을 호출할 수 없다.
  @EndUserText.label : '백그라운드 잡 카운트 (SM37)'
  jobcount         : abap.char(8);

  // --- 상태 캐시 ---------------------------------------------------------
  // 진실의 원천은 APJ 다. 목록 조회 때마다 API 를 부르지 않으려고 캐시한다.
  // refreshStatus 액션이 갱신한다.
  @EndUserText.label : '상태 (S/R/F/E/C/K)'
  status           : abap.char(1);
  @EndUserText.label : '마지막 메시지'
  message          : abap.char(255);

  // --- RAP 관리 필드 -----------------------------------------------------
  // 요청자/요청시각은 이 4개가 대신한다. 별도 컬럼을 두지 않는다.
  @Semantics.user.createdBy : true
  created_by            : abp_creation_user;
  @Semantics.systemDateTime.createdAt : true
  created_at            : abp_creation_tmstmp;
  @Semantics.user.localInstanceLastChangedBy : true
  last_changed_by       : abp_locinst_lastchange_user;
  @Semantics.systemDateTime.localInstanceLastChangedAt : true
  local_last_changed_at : abp_locinst_lastchange_tmstmp;

}
