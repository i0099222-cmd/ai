@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '요청 변경 이력 (BO 자식)'
define view entity ZR_CMSM_ReqHist
  as select from ZI_CMSM_ReqHist
  association to parent ZR_CMSM_Req as _Req on $projection.ReqUuid = _Req.ReqUuid
{
  key HistUuid,
      ReqUuid,
      @Semantics.systemDateTime.createdAt: true
      ChangedAt,
      @Semantics.user.createdBy: true
      ChangedBy,
      HistKind,
      FieldName,
      OldValue,
      NewValue,
      HistNote,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      LocalLastChangedAt,

      _Req,
      _HistKind,
      _ChangedBy
}
