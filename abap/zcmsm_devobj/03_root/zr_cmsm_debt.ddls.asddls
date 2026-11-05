@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '기술부채 (BO 루트)'
define root view entity ZR_CMSM_Debt
  as select from ZI_CMSM_Debt
{
  key DebtUuid,
      DebtId,
      SapModule,
      DevId,
      ObjType,
      DevObj,
      WrapType,
      StdType,
      StdName,
      SysId,
      DebtDesc,
      DebtLevel,
      ImproveStatus,
      DebtReason,
      BizOwner,
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

      _SapModule,
      _ObjType,
      _WrapType,
      _StdType,
      _Sys,
      _DebtLevel,
      _ImproveStatus,
      _BizOwner
}
