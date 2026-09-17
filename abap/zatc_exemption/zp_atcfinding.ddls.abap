@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC Findings'
@Metadata.allowExtensions: true
@Search.searchable: true
// 읽기 전용이므로 behavior definition 없이 서비스에 노출한다.
// 여기서 위반 건을 선택해 예외 신청(createFromFinding)으로 넘어간다.
define view entity ZP_AtcFinding
  as projection on ZI_AtcFinding
{
  key CheckVariant,
  key Devclass,
  key ObjectType,
  key ObjectName,
  key LineNo,
  key CheckId,
  key MessageId,

      Checksum,
      CheckGroup,
      Priority,
      MessageText,

      ContactPerson,
      Responsible,

      ExemptId,
      ExemptScopeType,
      ExemptionStatus,
      ExemptValidTo
}
