@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC 예외 신청 아이템'
@Metadata.allowExtensions: true
define view entity ZC_AtcExemptionItem
  as projection on ZI_AtcExemptionItem
{
  key ItemUuid,

      ExemptUuid,
      ItemNo,

      ObjectType,
      ObjectName,
      LineNo,
      Checksum,
      CheckId,
      MessageId,
      Priority,
      MessageText,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,

      _Exemption : redirected to parent ZC_AtcExemption
}
