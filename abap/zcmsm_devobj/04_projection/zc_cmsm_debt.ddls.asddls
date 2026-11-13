@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '기술부채'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'DebtId' ]
@Search.searchable: true
define root view entity ZC_CMSM_Debt
  provider contract transactional_query
  as projection on ZR_CMSM_Debt
{
  key DebtUuid,
      @Search.defaultSearchElement: true
      DebtId,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_ModuleVH', element: 'Value' } }]
      @ObjectModel.text.element: [ 'SapModuleText' ]
      SapModule,
      @EndUserText.label: '모듈 내역'
      _SapModule.Text as SapModuleText,
      @Search.defaultSearchElement: true
      DevId,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_ObjTypeVH', element: 'Value' } }]
      @ObjectModel.text.element: [ 'ObjTypeText' ]
      ObjType,
      @EndUserText.label: '오브젝트 유형 내역'
      _ObjType.Text as ObjTypeText,
      @Search.defaultSearchElement: true
      // 등록된 개발 오브젝트에서 고르면 유형·모듈도 같이 채운다 (직접 입력도 가능)
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_DevObject', element: 'DevObj' },
                                           additionalBinding: [{ localElement: 'ObjType',   element: 'ObjType',   usage: #RESULT },
                                                               { localElement: 'SapModule', element: 'SapModule', usage: #RESULT }] }]
      DevObj,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_WrapTypeVH', element: 'Value' } }]
      @ObjectModel.text.element: [ 'WrapTypeText' ]
      WrapType,
      @EndUserText.label: '래핑 여부 내역'
      _WrapType.Text as WrapTypeText,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_StdTypeVH', element: 'Value' } }]
      @ObjectModel.text.element: [ 'StdTypeText' ]
      StdType,
      @EndUserText.label: '대상 유형 내역'
      _StdType.Text as StdTypeText,
      @Search.defaultSearchElement: true
      StdName,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_SysId', element: 'SysId' } }]
      @ObjectModel.text.element: [ 'SysText' ]
      SysId,
      @EndUserText.label: '시스템 설명'
      _Sys.Description as SysText,
      DebtDesc,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_DebtLevelVH', element: 'Value' } }]
      @ObjectModel.text.element: [ 'DebtLevelText' ]
      DebtLevel,
      @EndUserText.label: 'Debt Level 내역'
      _DebtLevel.Text as DebtLevelText,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_ImproveVH', element: 'Value' } }]
      @ObjectModel.text.element: [ 'ImproveStatusText' ]
      ImproveStatus,
      @EndUserText.label: '개선상태 내역'
      _ImproveStatus.Text as ImproveStatusText,
      DebtReason,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_UserVH', element: 'UserId' } }]
      @ObjectModel.text.element: [ 'BizOwnerName' ]
      BizOwner,
      @EndUserText.label: '업무담당자 이름'
      _BizOwner.PersonFullName as BizOwnerName,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt
}
