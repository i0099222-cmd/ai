@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Packages with ATC Findings'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #C,
  sizeCategory: #M,
  dataClass: #MIXED
}
@Search.searchable: true
// 요청서 대상의 Package 값 도움. 아직 면제되지 않은 위반이 있는 패키지를
// 체크별로 한 줄씩 보여 준다. 패키지 대상은 체크 전체(CHK)를 덮으므로 코드는 키가 아니다.
//
// 위반이 없는 패키지(선등록)는 여기 없다. 그런 패키지는 직접 입력한다.
define view entity ZI_AtcFindingPkgVH
  as select from ZI_AtcFinding
{
      @EndUserText.label: 'Check Class'
  key CheckClass,

      @Search.defaultSearchElement: true
      @EndUserText.label: 'Package'
  key Devclass,

      @EndUserText.label: 'Findings'
      count( * )                   as FindingCount,

      @EndUserText.label: 'Objects'
      count( distinct ObjectName ) as ObjectCount,

      // 1 이 가장 높다.
      @EndUserText.label: 'Top Priority'
      min( Priority )              as TopPriority
}
where ExemptionStatus = 'O'
group by CheckClass,
         Devclass
