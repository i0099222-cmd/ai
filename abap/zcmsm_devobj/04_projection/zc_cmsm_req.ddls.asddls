@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '요청'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'ReqId' ]
@Search.searchable: true
define root view entity ZC_CMSM_Req
  provider contract transactional_query
  as projection on ZR_CMSM_Req
{
  key ReqUuid,
      @Search.defaultSearchElement: true
      ReqId,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      Title,
      ReqText,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_ModuleVH', element: 'Value' } }]
      @ObjectModel.text.element: [ 'SapModuleText' ]
      SapModule,
      @EndUserText.label: '모듈 내역'
      _SapModule.Text as SapModuleText,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_UserVH', element: 'UserId' } }]
      @ObjectModel.text.element: [ 'AssigneeName' ]
      Assignee,
      @EndUserText.label: '담당자 이름'
      _Assignee.PersonFullName as AssigneeName,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_ReqStatusVH', element: 'Value' } }]
      @ObjectModel.text.element: [ 'ReqStatusText' ]
      ReqStatus,
      @EndUserText.label: '상태 내역'
      _ReqStatus.Text as ReqStatusText,
      ProcResult,
      RelNo,
      DoneDate,
      CloseReason,
      @ObjectModel.text.element: [ 'CreatedByName' ]
      CreatedBy,
      @EndUserText.label: '요청자 이름'
      _CreatedBy.PersonFullName as CreatedByName,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Hist : redirected to composition child ZC_CMSM_ReqHist
}
