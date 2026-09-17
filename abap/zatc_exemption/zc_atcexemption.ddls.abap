@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC 예외 신청/승인'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_AtcExemption
  provider contract transactional_query
  as projection on ZI_AtcExemption
{
  key ExemptUuid,

      @Search.defaultSearchElement: true
      ExemptId,

      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZI_AtcCheckVH', element: 'CheckGroup' }
      }]
      CheckGroup,

      // 드롭다운 목록은 ZI_AtcScopeVH 가 채운다. 값이 열려 있는지는 설정이 정한다.
      @Consumption.valueHelpDefinition: [{
        entity:            { name: 'ZI_AtcScopeVH', element: 'ScopeType' },
        additionalBinding: [{ localElement: 'CheckGroup', element: 'CheckGroup' }]
      }]
      ScopeType,

      @Search.defaultSearchElement: true
      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZI_AtcPackageVH', element: 'Devclass' }
      }]
      Devclass,

      // Phase 1 은 읽기 전용으로 잠근다.
      // ZI_AtcFinding 의 면제 판정이 하위 패키지 전개를 못 하므로,
      // 화면에서 켤 수 있게 두면 판정 결과와 어긋난다.
      InclSubPkg,

      ObjectType,

      @Search.defaultSearchElement: true
      ObjectName,

      SubObject,
      LineNo,
      FindingKey,

      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZI_AtcCheckVH', element: 'CheckId' }
      }]
      CheckId,

      @Consumption.valueHelpDefinition: [{
        entity:            { name: 'ZI_AtcCheckVH', element: 'MessageId' },
        additionalBinding: [{ localElement: 'CheckId', element: 'CheckId' }]
      }]
      MessageId,

      RuleScope,

      ReasonCode,
      ReasonText,

      ValidFrom,
      ValidTo,

      ExemptStatus,

      Requester,
      Approver,
      ApprovedAt,

      ExtExemptId,
      PreRegFlag,

      StatusCriticality,
      ScopeCriticality,

      CreatedBy,
      LastChangedBy,
      CreatedAt,
      LastChangedAt,
      LocalLastChangedAt,

      _Item : redirected to composition child ZC_AtcExemptionItem,
      _Log  : redirected to composition child ZC_AtcExemptionLog
}
