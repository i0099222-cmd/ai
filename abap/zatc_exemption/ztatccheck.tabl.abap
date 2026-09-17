@EndUserText.label : 'ATC 대상 체크 마스터 (설정)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table ztatccheck {

  key client    : abap.clnt not null;

  "! 체크 ID (Code Inspector 체크 클래스 / 체크 식별자)
  key checkid   : abap.char(30) not null;

  "! 메시지 ID. 공란 행은 해당 체크의 모든 메시지를 의미한다.
  key messageid : abap.char(30) not null;

  "! NAMING / PERF / SECURITY / CLOUD ...
  "! Phase 1 은 NAMING 만 activeflg = X 로 운영한다.
  checkgroup    : abap.char(10);

  "! 앱 취급 대상 여부. 체크 ID 를 코드에 하드코딩하지 않기 위한 스위치.
  activeflg     : abap_boolean;

  "! 예외 신청을 허용하는 최대 Priority. 예: 2 이면 Prio 1 은 신청 자체를 차단.
  maxpriority   : abap.int1;

  descr         : abap.char(60);

  include zscm00010;

}
