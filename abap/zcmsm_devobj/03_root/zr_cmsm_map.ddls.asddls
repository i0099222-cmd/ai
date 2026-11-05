@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'As-Is/To-Be 매핑 (BO 루트)'
define root view entity ZR_CMSM_Map
  as select from ZI_CMSM_Map
{
  key MapUuid,
      MapId,
      MapKind,
      SrcSysId,
      AsisType,
      AsisName,
      TgtSysId,
      TobeType,
      TobeName,
      UiKind,
      UiUri,
      FioriAppId,
      SemObjAction,
      ReactApp,
      SapModule,
      Description,
      OwnerId,
      ObjCreator,
      ReqId,
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

      _MapKind,
      _SrcSys,
      _AsisType,
      _TgtSys,
      _TobeType,
      _UiKind,
      _SapModule,
      _Owner,
      _Request
}
