@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'As-Is/To-Be 매핑'
define view entity ZI_CMSM_Map
  as select from ztcmsm00190

  association [0..1] to ZI_CMSM_MapKindVH as _MapKind   on $projection.MapKind   = _MapKind.Value
  association [0..1] to ZI_CMSM_SysId     as _SrcSys    on $projection.SrcSysId  = _SrcSys.SysId
  association [0..1] to ZI_CMSM_ObjTypeVH as _AsisType  on $projection.AsisType  = _AsisType.Value
  association [0..1] to ZI_CMSM_SysId     as _TgtSys    on $projection.TgtSysId  = _TgtSys.SysId
  association [0..1] to ZI_CMSM_ObjTypeVH as _TobeType  on $projection.TobeType  = _TobeType.Value
  association [0..1] to ZI_CMSM_UiKindVH  as _UiKind    on $projection.UiKind    = _UiKind.Value
  association [0..1] to ZI_CMSM_ModuleVH  as _SapModule on $projection.SapModule = _SapModule.Value
  association [0..1] to ZI_CMSM_UserVH    as _Owner     on $projection.OwnerId   = _Owner.UserId
  association [0..1] to ZI_CMSM_ReqVH     as _Request   on $projection.ReqId     = _Request.ReqId
{
      @EndUserText.label: '매핑 UUID'
  key mapuuid            as MapUuid,
      @EndUserText.label: '등록번호'
      mapid              as MapId,
      @EndUserText.label: '구분'
      mapkind            as MapKind,
      @EndUserText.label: '소스 시스템'
      srcsysid           as SrcSysId,
      @EndUserText.label: 'As-Is 유형'
      asistype           as AsisType,
      @EndUserText.label: 'As-Is 오브젝트'
      asisname           as AsisName,
      @EndUserText.label: '타겟 시스템'
      tgtsysid           as TgtSysId,
      @EndUserText.label: 'To-Be 유형'
      tobetype           as TobeType,
      @EndUserText.label: 'To-Be 오브젝트'
      tobename           as TobeName,
      @EndUserText.label: 'UI 종류'
      uikind             as UiKind,
      @EndUserText.label: 'URI'
      uiuri              as UiUri,
      @EndUserText.label: 'Fiori 앱 ID'
      fioriappid         as FioriAppId,
      @EndUserText.label: 'Semantic Object-Action'
      semobjaction       as SemObjAction,
      @EndUserText.label: 'React 앱 이름'
      reactapp           as ReactApp,
      @EndUserText.label: '모듈'
      sapmodule          as SapModule,
      @EndUserText.label: '설명'
      description        as Description,
      @EndUserText.label: '담당자'
      ownerid            as OwnerId,
      @EndUserText.label: '오브젝트 생성자'
      objcreator         as ObjCreator,
      @EndUserText.label: '요청번호'
      reqid              as ReqId,
      @EndUserText.label: '등록자'
      createdby          as CreatedBy,
      @EndUserText.label: '등록 일시'
      createdat          as CreatedAt,
      @EndUserText.label: '최종 변경자'
      lastchangedby      as LastChangedBy,
      @EndUserText.label: '최종 변경 일시'
      lastchangedat      as LastChangedAt,
      locallastchangedat as LocalLastChangedAt,

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
