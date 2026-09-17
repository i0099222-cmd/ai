@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC Exemption Request - BO Root'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
// BO 루트. composition 과 behavior definition 이 여기 붙는다.
// 필드는 ZI_AtcExemption 에서 그대로 받고, 여기서는 BO 구조와 계산 필드만 더한다.
define root view entity ZR_AtcExemption
  as select from ZI_AtcExemption
  composition [0..*] of ZR_AtcExemptionItem as _Item
  composition [0..*] of ZR_AtcExemptionLog  as _Log
{
  key ExemptUuid,

      ExemptId,
      CheckVariant,
      CheckGroup,

      // 적용 범위. 허용 여부는 ztatccfg 컨트롤 테이블이 판정한다.
      ScopeType,

      Devclass,
      InclSubPkg,

      // PCKG 스코프에서는 출발점 오브젝트다 (표준 create_exemption 에 필수).
      // 효력은 패키지 전체다.
      ObjectType,
      ObjectName,

      CheckId,
      MessageId,
      RuleScope,

      ReasonCode,
      ReasonText,

      ValidFrom,
      ValidTo,

      ExemptStatus,

      Requester,
      Approver,
      ApprovedAt,

      ExtExemptId,
      PreRegFlag,

      // 상태 색. 3 승인(녹) / 2 승인대기(황) / 1 반려·철회·만료(적)
      @EndUserText.label: 'Status Criticality'
      case ExemptStatus
        when '30' then 3
        when '20' then 2
        when '40' then 1
        when '50' then 1
        when '60' then 1
        else 0
      end               as StatusCriticality,

      // 적용범위 색. 패키지 스코프는 목록에서 눈에 띄게 둔다.
      // 가장 넓고 향후 생성 오브젝트까지 덮는 범위라 무심코 승인되면 안 된다.
      @EndUserText.label: 'Scope Criticality'
      case ScopeType
        when 'PCKG' then 2
        else 0
      end               as ScopeCriticality,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Item,
      _Log
}
