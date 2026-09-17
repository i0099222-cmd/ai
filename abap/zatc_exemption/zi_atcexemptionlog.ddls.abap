@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ATC Exemption Status History - Interface'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
// 감사 대응의 유일한 서술 근거다. 승인/반려된 건은 삭제하지 않는다.
define view entity ZR_AtcExemptionLog
  as select from ztatcexemptlog
{
      @EndUserText.label: 'History Entry UUID'
  key loguuid      as LogUuid,

      @EndUserText.label: 'Exemption Request UUID'
      exemptuuid   as ExemptUuid,

      @EndUserText.label: 'Sequence Number'
      seqnr        as SeqNr,

      @EndUserText.label: 'Action'
      actioncode   as ActionCode,

      @EndUserText.label: 'Previous Status'
      fromstat     as FromStatus,

      @EndUserText.label: 'New Status'
      tostat       as ToStatus,

      @EndUserText.label: 'Comment'
      commenttxt   as CommentText,

      @EndUserText.label: 'Changed By'
      actionby     as ActionBy,

      @EndUserText.label: 'Changed At'
      actionat     as ActionAt
}
