@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC Exemption Request Item - BO'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
define view entity ZR_AtcExemptionItem
  as select from ZI_AtcExemptionItem
  association to parent ZR_AtcExemption as _Exemption
    on $projection.ExemptUuid = _Exemption.ExemptUuid
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

      _Exemption
}
