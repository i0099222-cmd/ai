@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC 예외 신청 이력'
@Metadata.allowExtensions: true
define view entity ZC_AtcExemptionLog
  as projection on ZI_AtcExemptionLog
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

      _Exemption : redirected to parent ZC_AtcExemption
}
