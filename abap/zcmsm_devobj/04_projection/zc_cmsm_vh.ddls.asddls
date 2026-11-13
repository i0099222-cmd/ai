@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'VhId' ]
@Search.searchable: true
define root view entity ZC_CMSM_Vh
  provider contract transactional_query
  as projection on ZR_CMSM_Vh
{
  key VhUuid,
      @Search.defaultSearchElement: true
      VhId,
      @Search.defaultSearchElement: true
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_SysVhVH', element: 'VhName' } }]
      VhName,
      @ObjectModel.text.element: [ 'VhImplText' ]
      VhImpl,
      @EndUserText.label: '구현 방식 내역'
      _VhImpl.Text as VhImplText,
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
      LocalLastChangedAt,

      _Src : redirected to composition child ZC_CMSM_VhSrc
}
