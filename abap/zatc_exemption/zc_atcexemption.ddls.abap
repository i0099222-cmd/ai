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
        entity: { name: 'ZI_AtcVariantVH', element: 'CheckVariant' }
      }]
      CheckVariant,

      // 컨트롤 테이블에서 파생되는 값이라 사용자가 고르지 않는다.
      CheckGroup,

      // 드롭다운 목록은 ZI_AtcScopeVH 가 채운다. 어떤 값이 열려 있는지는
      // 컨트롤 테이블(ztatccfg)의 fndactive/objactive/pkgactive 가 정한다.
      @Consumption.valueHelpDefinition: [{
        entity:            { name: 'ZI_AtcScopeVH', element: 'ScopeType' },
        additionalBinding: [{ localElement: 'CheckVariant', element: 'CheckVariant' }]
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

      // 체크 ID / 메시지 ID 는 finding 에서 프리필된다. 체크의 마스터는 표준이
      // 갖고 있으므로 우리 쪽 값 도움을 만들지 않는다.
      CheckId,
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
