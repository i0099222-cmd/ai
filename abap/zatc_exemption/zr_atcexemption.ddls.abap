@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC Exemption Request - BO Root'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
// BO 루트 = 요청서. 대상은 _Item(한 줄 = 표준 예외 1건), 이력은 _Log 다.
define root view entity ZR_AtcExemption
  as select from ZI_AtcExemption
  composition [0..*] of ZR_AtcExemptionItem as _Item
  composition [0..*] of ZR_AtcExemptionLog  as _Log
{
  key ExemptUuid,

      ReqNumber,

      ReasonCode,
      ReasonText,

      ValidFrom,
      ValidTo,

      ExemptStatus,

      Requester,
      Approver,
      ApprovedAt,

      // 상태 색. 5 초안(청) / 3 승인(녹) / 2 승인대기(황) / 1 반려·철회·만료(적)
      // draft 는 이 계산을 거치지 않고 draft 테이블 값을 읽는다. 새로 만든 draft 는
      // setInitialValues 가 초안 색을 넣는다.
      @EndUserText.label: 'Status Criticality'
      case ExemptStatus
        when '10' then 5
        when '30' then 3
        when '20' then 2
        when '40' then 1
        when '50' then 1
        when '60' then 1
        else 0
      end               as StatusCriticality,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Item,
      _Log
}
