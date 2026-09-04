@EndUserText.label : '배치잡 실행 프로브 (Application Job / SM36 비교용)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztjob_probe {

  key client        : abap.clnt not null;
  key probe_uuid    : sysuuid_x16 not null;

  @EndUserText.label : '테스트 케이스 태그'
  run_tag           : abap.char(20);
  @EndUserText.label : '실행 내 순번'
  seq_no            : abap.int4;

  @EndUserText.label : '스케줄 방식 (A=Application Job, C=Classic SM36)'
  schedule_mode     : abap.char(1);
  @EndUserText.label : '백그라운드 잡 이름 (SM37)'
  job_name          : abap.char(32);
  @EndUserText.label : '백그라운드 잡 카운트 (SM37)'
  job_count         : abap.char(8);

  // --- 여기가 실제 비교 대상 -------------------------------------------
  @EndUserText.label : '실행 사용자'
  exec_user         : abap.char(12);
  @EndUserText.label : '실행 시각 (UTC)'
  exec_stamp        : utclong;
  @EndUserText.label : '실행일 (시스템)'
  exec_date         : abap.dats;
  @EndUserText.label : '실행시각 (시스템)'
  exec_time         : abap.tims;
  @EndUserText.label : '사용자 타임존'
  user_timezone     : abap.char(6);
  @EndUserText.label : '애플리케이션 서버 (Standard ABAP 에서만 채워짐)'
  host              : abap.char(32);
  @EndUserText.label : '백그라운드 실행 여부 (Standard ABAP 에서만 채워짐)'
  is_batch          : abap_boolean;

  @EndUserText.label : '메모'
  message           : abap.char(255);

}
