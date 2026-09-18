@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC Exemption Request Item'
@Metadata.allowExtensions: true
define view entity ZP_AtcExemptionItem
  as projection on ZR_AtcExemptionItem
{
  key ItemUuid,

      ExemptUuid,
      ItemNo,

      ObjectType,
      ObjectName,
      Checksum,
      CheckClass,
      CheckCode,
      Priority,
      MessageText,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,

      _Exemption : redirected to parent ZP_AtcExemption
}
