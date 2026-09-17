@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC Exemption Status History - BO'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
define view entity ZR_AtcExemptionLog
  as select from ZI_AtcExemptionLog
  association to parent ZR_AtcExemption as _Exemption
    on $projection.ExemptUuid = _Exemption.ExemptUuid
{
  key LogUuid,

      ExemptUuid,
      SeqNr,
      ActionCode,
      FromStatus,
      ToStatus,
      CommentText,
      ActionBy,
      ActionAt,

      _Exemption
}
