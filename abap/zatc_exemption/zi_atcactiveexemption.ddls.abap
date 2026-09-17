@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Currently Valid ATC Exemptions'
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
  as select from ZI_AtcExemption
{
      @EndUserText.label: 'Exemption Request UUID'
  key ExemptUuid,

      @EndUserText.label: 'Exemption Request ID'
      ExemptId,

      @EndUserText.label: 'Check Group'
      CheckGroup,

      @EndUserText.label: 'Object Scope'
      ScopeType,

      @EndUserText.label: 'Package'
      Devclass,

      @EndUserText.label: 'Object Type'
      ObjectType,

      @EndUserText.label: 'Object Name'
      ObjectName,

      @EndUserText.label: 'Check Class'
      CheckId,

      @EndUserText.label: 'Check Message Code'
      MessageId,

      @EndUserText.label: 'Valid From'
      ValidFrom,

      @EndUserText.label: 'Valid To'
      ValidTo,

      @EndUserText.label: 'Approver'
      Approver
}
where ExemptStatus = '30'
  and ValidFrom   <= $session.system_date
  and ValidTo     >= $session.system_date
