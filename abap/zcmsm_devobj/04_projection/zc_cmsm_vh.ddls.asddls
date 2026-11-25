@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'VhId' ]
@Search.searchable: true
define root view entity ZC_CMSM_Vh
  provider contract transactional_query
  as projection on ZR_CMSM_Vh
  // 데이터 소스 (자동): VH 정의를 XCO 로 읽어 오는 custom entity (읽기 전용)
  association [0..*] to ZCE_CMSM_VhSource as _SysSource on $projection.VhName = _SysSource.VhName
{
  key VhUuid,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      VhId,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
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
      @Search.fuzzinessThreshold: 0.8
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
      // 파일(스트림) 칸은 정렬·필터 불가 — 목록에서 정렬하면 'stream property … not allowed in $orderby' 에러
      @ObjectModel.sort.enabled: false
      @ObjectModel.filter.enabled: false
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

      _Src : redirected to composition child ZC_CMSM_VhSrc,
      _SysSource
}
