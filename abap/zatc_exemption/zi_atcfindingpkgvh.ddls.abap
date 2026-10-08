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
// 요청서 대상의 Package 값 도움. 아직 면제되지 않은 위반이 있는 패키지를 한 줄씩 보여 준다.
// 체크 클래스는 넣지 않는다. 넣으면 같은 패키지가 체크 수만큼 나온다. 그래서 요청서의 체크로
// 거르지 않고, 건수도 전체 체크 합계다. 다른 체크의 위반만 있는 패키지를 고르면 선등록과 같다.
//
// 위반이 없는 패키지(선등록)는 여기 없다. 그런 패키지는 직접 입력한다.
define view entity ZI_AtcFindingPkgVH
  as select from ZI_AtcFinding
{
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
group by Devclass
