@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC Exemption Status History'
@Metadata.allowExtensions: true
define view entity ZP_AtcExemptionLog
  as projection on ZR_AtcExemptionLog
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

      _Exemption : redirected to parent ZP_AtcExemption
}
