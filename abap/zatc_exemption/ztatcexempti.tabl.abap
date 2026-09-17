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
  "!   FND      : 면제 대상 그 자체 (1:1). resultid / itemid / lineno 가 판정에 쓰인다.
  "!   OBJ, PKG : 신청 근거(증빙) 스냅샷. 효력은 오브젝트/패키지 전체이며
  "!              여기 담긴 건에 한정되지 않는다.
  devclass       : devclass;
  objecttype     : trobjtype;
  objectname     : sobj_name;
  lineno         : abap.int4;

  "! ATC finding 식별 3종. SATC_API_FINDINGS 의 키와 같다.
  "! 주의: resultid 는 ATC 실행(결과) 단위이므로 이 3종은 런마다 달라진다.
  "! 증빙 추적에는 쓸 수 있지만, FND 스코프 예외의 영구 키로는 쓸 수 없다.
  resultid       : abap.char(32);
  itemid         : abap.char(32);
  checkrunindex  : abap.int4;

  checkvariant   : abap.char(30);
  checkid        : abap.char(30);
  messageid      : abap.char(30);
  priority       : abap.int1;
  msgtext        : abap.char(255);

  include zscm00010;

  "! RAP OCC 용 로컬 변경 타임스탬프
  loclastchgat   : timestampl;

}
