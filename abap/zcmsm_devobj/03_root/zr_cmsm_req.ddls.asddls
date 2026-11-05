@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '요청 (BO 루트)'
define root view entity ZR_CMSM_Req
  as select from ZI_CMSM_Req
  composition [0..*] of ZR_CMSM_ReqHist as _Hist
{
  key ReqUuid,
      ReqId,
      Title,
      ReqText,
      SapModule,
      Assignee,
      ReqStatus,
      ProcResult,
      RelNo,
      DoneDate,
      CloseReason,
      @Semantics.user.createdBy: true
      CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      CreatedAt,
      @Semantics.user.lastChangedBy: true
      LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      LocalLastChangedAt,

      _Hist,
      _SapModule,
      _ReqStatus,
      _Assignee,
      _CreatedBy
}
