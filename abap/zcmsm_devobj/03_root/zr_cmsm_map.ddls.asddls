@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'As-Is/To-Be 매핑 (BO 루트)'
define root view entity ZR_CMSM_Map
  as select from ZI_CMSM_Map
  // 구성요소 매핑 (메서드·필드 등 하위 단위) — 매핑 한 건 아래 여러 줄
  composition [0..*] of ZR_CMSM_MapComp as _Comp
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
      _Request,
      _Comp
}
