@EndUserText.label : 'ATC 예외 신청 아이템 (finding)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztatcexempti {

  key client     : abap.clnt not null;

  key itemuuid   : sysuuid_x16 not null;

  "! 상위 신청서
  exemptuuid     : sysuuid_x16 not null;

  itemno         : abap.int4;

  "! --- 이하 ATC finding 스냅샷 ---
  "! 주의: 아이템의 역할은 헤더의 scopetype 에 따라 다르다.
  "!   FND      : 면제 대상 그 자체 (1:1). findingkey / lineno 가 판정에 쓰인다.
  "!   OBJ, PKG : 신청 근거(증빙) 스냅샷. 효력은 오브젝트/패키지 전체이며
  "!              여기 담긴 건에 한정되지 않는다.
  devclass       : devclass;
  objecttype     : trobjtype;
  objectname     : sobj_name;
  subobject      : abap.char(40);
  lineno         : abap.int4;
  findingkey     : abap.char(60);
  checkid        : abap.char(30);
  messageid      : abap.char(30);
  priority       : abap.int1;
  msgtext        : abap.char(255);

  include zscm00010;

  createdat      : timestampl;
  lastchangedat  : timestampl;

}
