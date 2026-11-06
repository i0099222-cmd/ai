@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'As-Is/To-Be 매핑'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'MapId' ]
@Search.searchable: true
define root view entity ZC_CMSM_Map
  provider contract transactional_query
  as projection on ZR_CMSM_Map
{
  key MapUuid,
      @Search.defaultSearchElement: true
      MapId,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_MapKindVH', element: 'Value' } }]
      @ObjectModel.text.element: [ 'MapKindText' ]
      MapKind,
      @EndUserText.label: '구분 내역'
      _MapKind.Text as MapKindText,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_SysId', element: 'SysId' } }]
      @ObjectModel.text.element: [ 'SrcSysText' ]
      SrcSysId,
      @EndUserText.label: '소스 시스템 설명'
      _SrcSys.Description as SrcSysText,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_AsisTypeVH', element: 'Value' } }]
      @ObjectModel.text.element: [ 'AsisTypeText' ]
      AsisType,
      @EndUserText.label: 'As-Is 유형 내역'
      _AsisType.Text as AsisTypeText,
      @Search.defaultSearchElement: true
      AsisName,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_SysId', element: 'SysId' } }]
      @ObjectModel.text.element: [ 'TgtSysText' ]
      TgtSysId,
      @EndUserText.label: '타겟 시스템 설명'
      _TgtSys.Description as TgtSysText,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_TobeTypeVH', element: 'Value' } }]
      @ObjectModel.text.element: [ 'TobeTypeText' ]
      TobeType,
      @EndUserText.label: 'To-Be 유형 내역'
      _TobeType.Text as TobeTypeText,
      @Search.defaultSearchElement: true
      TobeName,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_UiKindVH', element: 'Value' } }]
      @ObjectModel.text.element: [ 'UiKindText' ]
      UiKind,
      @EndUserText.label: 'UI 종류 내역'
      _UiKind.Text as UiKindText,
      UiUri,
      FioriAppId,
      SemObjAction,
      ReactApp,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_ModuleVH', element: 'Value' } }]
      @ObjectModel.text.element: [ 'SapModuleText' ]
      SapModule,
      @EndUserText.label: '모듈 내역'
      _SapModule.Text as SapModuleText,
      @Search.defaultSearchElement: true
      Description,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_UserVH', element: 'UserId' } }]
      @ObjectModel.text.element: [ 'OwnerName' ]
      OwnerId,
      @EndUserText.label: '담당자 이름'
      _Owner.PersonFullName as OwnerName,
      ObjCreator,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_ReqVH', element: 'ReqId' } }]
      @ObjectModel.text.element: [ 'ReqTitle' ]
      ReqId,
      @EndUserText.label: '요청 제목'
      _Request.Title as ReqTitle,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt
}
