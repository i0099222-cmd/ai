@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Latest ATC Run per Object'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
// 오브젝트마다 가장 최근 ATC 실행이 언제였는지.
//
// ATC 는 실행할 때마다 결과를 새 result 로 쌓고 이전 회차도 남긴다. 필터가 없으면
// 같은 위반이 회차만큼 보이고, 예외 승인 전 회차와 후 회차가 나란히 떠서 예외가
// 안 먹는 것처럼 보인다.
//
// SATC_API_RESULT_HEADERS 의 isactiveresult 를 쓰려 했으나 값이 서지 않는다
// (확인함 - isinbaseline / isactiveresult 는 비어 있고 iscentralrun 만 채워진다).
// 그래서 실행 시각으로 직접 고른다.
//
// 변형 단위가 아니라 **오브젝트 단위**로 최신을 잡는다. 같은 변형으로 패키지를
// 나눠 돌리는 운영이 흔하고, 변형 단위로 잡으면 먼저 돌린 패키지의 위반이
// 통째로 사라진다.
define view entity ZI_AtcLatestRun
  as select from satc_api_findings as Finding

  inner join satc_api_result_headers as Hdr
    on Hdr.resultid = Finding.resultid

{
  key Finding.objecttype   as ObjectType,
  key Finding.objectname   as ObjectName,
  key Finding.checkvariant as CheckVariant,

      // 🔴 scheduledontimestamp 가 실행 순서를 나타낸다고 본다.
      //   changedontimestamp 가 더 늦게 갱신되는 경우가 있으면 그것으로 바꾼다.
      max( Hdr.scheduledontimestamp ) as LatestRunTs
}
group by
  Finding.objecttype,
  Finding.objectname,
  Finding.checkvariant
