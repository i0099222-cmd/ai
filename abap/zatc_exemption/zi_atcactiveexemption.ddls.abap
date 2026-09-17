@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '현재 유효한 ATC 예외'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
// 승인 상태이고 오늘이 유효기간 안인 예외만 남긴다.
// finding 의 면제 여부는 저장하지 않고 이 뷰와 조인해 매번 계산한다.
// 상태를 finding 에 직접 기록하면 유효기간 만료를 반영할 방법이 없어진다.
define view entity ZI_AtcActiveExemption
  as select from ztatcexempt
{
  key exemptuuid  as ExemptUuid,
      exemptid    as ExemptId,
      checkgroup  as CheckGroup,
      scopetype   as ScopeType,
      devclass    as Devclass,
      objecttype  as ObjectType,
      objectname  as ObjectName,
      checkid     as CheckId,
      messageid   as MessageId,
      validfrom   as ValidFrom,
      validto     as ValidTo,
      approver    as Approver
}
where exemptstat = '30'
  and validfrom <= $session.system_date
  and validto   >= $session.system_date
