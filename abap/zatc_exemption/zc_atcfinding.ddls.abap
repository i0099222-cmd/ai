@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC 위반 현황 조회'
@Metadata.allowExtensions: true
@Search.searchable: true
// 읽기 전용 조회. 여기서 finding 을 선택해 예외 신청으로 넘어간다.
// 읽기 전용이므로 behavior definition 없이 서비스에 노출한다.
define view entity ZC_AtcFinding
  as projection on ZI_AtcFinding
{
  key FindingUuid,

      SnapshotDate,
      RunId,

      @Search.defaultSearchElement: true
      Devclass,
      ObjectType,

      @Search.defaultSearchElement: true
      ObjectName,
      SubObject,
      LineNo,
      FindingKey,

      CheckId,
      MessageId,
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
