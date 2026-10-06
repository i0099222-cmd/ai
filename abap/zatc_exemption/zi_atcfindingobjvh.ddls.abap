@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Objects with ATC Findings'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #C,
  sizeCategory: #M,
  dataClass: #MIXED
}
@Search.searchable: true
// 요청서 대상의 Object Name 값 도움. 아직 면제되지 않은 위반이 있는 오브젝트를
// 오브젝트 + 메시지 코드 단위로 한 줄씩 보여 준다. 고르면 유형·패키지·코드가 같이 채워진다.
//
// 변형은 키에 넣지 않는다. 같은 오브젝트를 변형 둘로 돌렸으면 같은 줄이 두 번 나온다.
define view entity ZI_AtcFindingObjVH
  as select from ZI_AtcFinding
{
      @EndUserText.label: 'Check Class'
  key CheckClass,

      @EndUserText.label: 'Object Type'
  key ObjectType,

      @Search.defaultSearchElement: true
      @EndUserText.label: 'Object Name'
  key ObjectName,

      @EndUserText.label: 'Check Message Code'
  key CheckCode,

      @Search.defaultSearchElement: true
      @EndUserText.label: 'Package'
      Devclass,

      // 1 이 가장 높다.
      @EndUserText.label: 'Top Priority'
      min( Priority ) as TopPriority,

      @EndUserText.label: 'Findings'
      count( * )      as FindingCount
}
where ExemptionStatus = 'O'
group by CheckClass,
         ObjectType,
         ObjectName,
         CheckCode,
         Devclass
