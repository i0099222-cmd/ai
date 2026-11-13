@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '통합 오브젝트 조회'
@Metadata.allowExtensions: true
@Search.searchable: true
// 통합 조회 탭 (읽기 전용). 저장된 건만 나온다 (편집 중인 드래프트는 안 나옴).
define view entity ZC_CMSM_DevObject
  as select from ZI_CMSM_DevObject

  association [0..1] to ZI_CMSM_SourceTabVH as _SourceTab on $projection.SourceTab = _SourceTab.SourceTab
  association [0..1] to ZI_CMSM_ObjTypeVH   as _ObjType   on $projection.ObjType   = _ObjType.Value
  association [0..1] to ZI_CMSM_ModuleVH    as _SapModule on $projection.SapModule = _SapModule.Value
  association [0..1] to ZI_CMSM_SysId       as _Sys       on $projection.SysId     = _Sys.SysId
{
  key SourceUuid,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_SourceTabVH', element: 'SourceTab' } }]
      @ObjectModel.text.element: [ 'SourceTabText' ]
  key SourceTab,
      @EndUserText.label: '등록 구분 내역'
      _SourceTab.Text      as SourceTabText,
      @Search.defaultSearchElement: true
      SourceId,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_SysId', element: 'SysId' } }]
      @ObjectModel.text.element: [ 'SysText' ]
      SysId,
      @EndUserText.label: '시스템 설명'
      _Sys.Description     as SysText,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_ObjTypeVH', element: 'Value' } }]
      @ObjectModel.text.element: [ 'ObjTypeText' ]
      ObjType,
      @EndUserText.label: '오브젝트 유형 내역'
      _ObjType.Text        as ObjTypeText,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      DevObj,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_ModuleVH', element: 'Value' } }]
      @ObjectModel.text.element: [ 'SapModuleText' ]
      SapModule,
      @EndUserText.label: '모듈 내역'
      _SapModule.Text      as SapModuleText,
      @Search.defaultSearchElement: true
      Description
}
