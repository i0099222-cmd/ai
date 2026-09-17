@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC 예외 신청 상태 이력'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
// 감사 대응의 유일한 서술 근거다. 승인/반려된 건은 삭제하지 않는다.
define view entity ZI_AtcExemptionLog
  as select from ztatcexemptlog
  association to parent ZI_AtcExemption as _Exemption
    on $projection.ExemptUuid = _Exemption.ExemptUuid
{
  key loguuid      as LogUuid,

      exemptuuid   as ExemptUuid,
      seqnr        as SeqNr,

      actioncode   as ActionCode,
      fromstat     as FromStatus,
      tostat       as ToStatus,
      commenttxt   as CommentText,

      actionby     as ActionBy,
      actionat     as ActionAt,

      _Exemption
}
