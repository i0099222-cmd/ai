@EndUserText.label : 'ATC finding 스냅샷'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztatcfinding {

  key client      : abap.clnt not null;

  key findinguuid : sysuuid_x16 not null;

  "! 적재 기준일. 보관 정책 배치가 이 필드로 정리한다.
  snapshotdate    : abap.dats;

  "! ATC Run 식별자
  runid           : abap.char(32);

  devclass        : devclass;
  objecttype      : trobjtype;
  objectname      : sobj_name;
  subobject       : abap.char(40);
  lineno          : abap.int4;
  findingkey      : abap.char(60);

  checkid         : abap.char(30);
  messageid       : abap.char(30);
  checkgroup      : abap.char(10);
  priority        : abap.int1;
  msgtext         : abap.char(255);

  "! ATC finding 담당자. My Findings 필터에 사용한다.
  contactperson   : abap.char(12);
  responsible     : abap.char(12);

  include zscm00010;

  createdat       : timestampl;

}
