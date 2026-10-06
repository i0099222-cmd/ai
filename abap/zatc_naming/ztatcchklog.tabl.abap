@EndUserText.label : 'ATC Naming Check - Last Check per Object'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #L
@AbapCatalog.dataMaintenance : #RESTRICTED
// 네이밍 체크가 오브젝트를 검사할 때마다 남기는 마지막 검사 기록.
//
// ATC 결과에는 위반 행만 있다. 오브젝트를 고쳐 다시 돌리면 그 실행에는 행이
// 없어서, 조회 화면은 예전 실행의 위반을 계속 최신으로 보여준다. 실행 헤더
// (SATC_AC_RESULTH)에는 검사한 오브젝트 목록이 없고, title 은 여러 오브젝트를
// 돌리면 쓸 수 없었다(확인함). 그래서 체크가 직접 남긴다.
//
// ZI_AtcFinding 이 이 기록을 본다. 마지막 검사에서 위반이 0건이었고 그 검사가
// 위반이 나온 실행보다 뒤면, 그 위반은 이미 고쳐진 것으로 보고 숨긴다.
define table ztatcchklog {

  key client     : abap.clnt not null;
  key objtype    : trobjtype not null;
  key objname    : sobj_name not null;

  "! 마지막으로 검사한 시각(UTC).
  lastcheck      : timestamp;

  "! 마지막 검사에서 나온 위반 건수. 0 이면 그때 깨끗했다는 뜻이다.
  findingcnt     : abap.int4;

}
