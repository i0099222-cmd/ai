@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC Findings'
@Search.searchable: true
// 위반 자체는 읽기 전용이다. behavior 를 두는 것은 [예외 신청] 액션 하나
// 때문이고, 그 액션은 finding 을 바꾸지 않고 신청서를 만든다.
@Metadata.allowExtensions: true
define root view entity ZP_AtcFinding
  provider contract transactional_query
  as projection on ZI_AtcFinding
{
  key ResultId,
  key ItemId,
  key CheckRunIndex,

      CheckVariant,
      Devclass,
      ObjectType,
      ObjectName,
      Checksum,

      StdExemptionKind,
      StdExemptionValidity,
      StdExemptionApproval,
      ExemptionMismatch,
      CheckGroup,
      Priority,
      MessageText,

      ContactPerson,
      Responsible,

      ExemptScopeType,
      ExemptionStatus,
      ExemptValidTo
}
