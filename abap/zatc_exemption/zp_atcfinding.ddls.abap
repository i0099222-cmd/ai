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

      // 표준 예외 API 로 그대로 넘어가는 값. 비어 있으면 신청해도 표준 반영이
      // 실패하므로, 목록에서 눈으로 확인할 수 있어야 한다.
      CheckClass,
      CheckCode,

      ExemptScopeType,
      ExemptionStatus,
      ExemptValidTo,

      // 이 위반을 덮고 있는 신청서. 신청 화면으로 이동할 키다.
      ExemptUuid
}
