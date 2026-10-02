@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ATC Findings by Package'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #C,
  sizeCategory: #M,
  dataClass: #MIXED
}
// 위반 조회의 패키지 탭. 패키지 단위로 신청하려는 사람이 오브젝트 줄을
// 훑지 않고 패키지당 한 줄을 보게 한다. ZI_AtcFinding 을 집계만 한다.
//
// 한 줄 = 체크 변형 + 패키지 + 체크 클래스. 패키지 예외는 체크 전체(CHK)를
// 덮으므로 체크 코드는 키에 넣지 않는다.
define root view entity ZI_AtcFindingPkg
  as select from ZI_AtcFinding as Finding

  // 이 패키지를 덮는 승인된 패키지 예외. 중복 신청 검사가 같은 범위의
  // 예외를 하나로 막으므로 한 줄에 둘 이상 붙지 않는다.
  left outer join ZI_AtcActiveExemption as PkgExempt
    on  PkgExempt.ScopeType  = 'PCKG'
    and PkgExempt.Devclass   = Finding.Devclass
    and PkgExempt.CheckClass = Finding.CheckClass
{
  key Finding.CheckVariant,
  key Finding.Devclass,
  key Finding.CheckClass,

      Finding.CheckGroup,

      count( * )                           as FindingCount,
      count( distinct Finding.ObjectName ) as ObjectCount,
      // 1 이 가장 높다.
      min( Finding.Priority )              as TopPriority,

      PkgExempt.ExemptUuid                 as ExemptUuid,
      PkgExempt.ValidTo                    as ExemptValidTo,

      // 위반 탭과 같은 이름과 값을 쓴다. 필터바가 두 탭에 같이 걸린다.
      case
        when PkgExempt.ExemptUuid is not initial then cast( 'E' as abap.char( 1 ) )
        else cast( 'O' as abap.char( 1 ) )
      end                                  as ExemptionStatus
}
group by Finding.CheckVariant,
         Finding.Devclass,
         Finding.CheckClass,
         Finding.CheckGroup,
         PkgExempt.ExemptUuid,
         PkgExempt.ValidTo
