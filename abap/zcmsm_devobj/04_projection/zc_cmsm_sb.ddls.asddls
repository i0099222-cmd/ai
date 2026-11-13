@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'OData 서비스'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'SbId' ]
@Search.searchable: true
define root view entity ZC_CMSM_Sb
  provider contract transactional_query
  as projection on ZR_CMSM_Sb
{
  key SbUuid,
      @Search.defaultSearchElement: true
      SbId,
      @Search.defaultSearchElement: true
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_SysSrvbVH', element: 'SrvbName' } }]
      SrvbName,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_SysId', element: 'SysId' } }]
      @ObjectModel.text.element: [ 'SysText' ]
      SysId,
      @EndUserText.label: '시스템 설명'
      _Sys.Description as SysText,
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
      @Semantics.largeObject: { mimeType: 'TestMimeType',
                                fileName: 'TestFileName',
                                contentDispositionPreference: #ATTACHMENT }
      TestFile,
      @Semantics.mimeType: true
      TestMimeType,
      TestFileName,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_UserVH', element: 'UserId' } }]
      @ObjectModel.text.element: [ 'TestByName' ]
      TestBy,
      @EndUserText.label: '올린 사람 이름'
      _TestBy.PersonFullName as TestByName,
      TestAt,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt
}
