@EndUserText.label : 'ATC Exemption Request Item'
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
  "! 아이템의 역할은 헤더의 scopetype 에 따라 다르다.
  "!   FND       : 면제 대상 그 자체 (1:1). checksum 이 판정에 쓰인다.
  "!   OBJ, PCKG : 신청 근거(증빙) 스냅샷. 효력은 오브젝트/패키지 전체이며
  "!               여기 담긴 건에 한정되지 않는다.
  "!
  "! 패키지와 체크 변형은 헤더에만 둔다. 한 신청서의 증빙은 모두 같은 변형에서
  "! 나오고 같은 패키지에 속하므로, 아이템에 또 두면 어긋날 여지만 생긴다.
  objecttype     : trobjtype;
  objectname     : sobj_name;

  "! ATC finding 의 식별자. 코드가 바뀌어도 같은 위반이면 유지되는 값이다.
  "! SATC_API_FINDINGS 의 키(resultid/itemid/checkrunindex)는 ATC 실행 단위라
  "! 런마다 바뀌어 예외의 영구 키로 쓸 수 없다. 그래서 checksum 을 보관한다.
  "! TODO 확인 필요: 이 값에 해당하는 SATC_API_FINDINGS 의 필드명.
  checksum       : abap.int4;

  "! 한 변형 안에서도 체크와 메시지는 아이템마다 다를 수 있어 여기 둔다.
  "! SATC_API_FINDINGS-MODULEID 와 같은 타입 (체크 GUID)
  checkid        : abap.raw(16);
  messageid      : abap.char(30);
  priority       : abap.int1;
  msgtext        : abap.char(255);

  include zscm00010;

  "! RAP OCC 용 로컬 변경 타임스탬프
  loclastchgat   : timestampl;

}
