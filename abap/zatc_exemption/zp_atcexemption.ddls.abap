@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC Exemption Request'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZP_AtcExemption
  provider contract transactional_query
  as projection on ZR_AtcExemption
{
  key ExemptUuid,

      @Search.defaultSearchElement: true
      ScopeText,

      // 변형-체크 클래스 짝 목록에서 고른다. 고르면 체크 클래스도 같이 채워진다.
      @Consumption.valueHelpDefinition: [{
        entity:            { name: 'ZI_AtcCheckClassVH', element: 'CheckVariant' },
        additionalBinding: [{ localElement: 'CheckClass', element: 'CheckClass', usage: #RESULT }]
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


      // 조회 화면 신청은 finding 에서 프리필되지만, 선등록은 사용자가 고른다.
      // 변형이 들어 있으면 그 변형의 체크만 보이고, 고르면 변형도 같이 채워진다.
      @Consumption.valueHelpDefinition: [{
        entity:            { name: 'ZI_AtcCheckClassVH', element: 'CheckClass' },
        additionalBinding: [{ localElement: 'CheckVariant', element: 'CheckVariant' }]
      }]
      CheckClass,

      // 오브젝트 신청에서 어긴 규칙 하나를 고른다. 규칙 문장이 같이 보인다.
      // 패키지 신청은 체크 전체(CHK)라 비워 둬도 된다.
      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZI_AtcCheckCodeVH', element: 'CheckCode' }
      }]
      CheckCode,

      RuleScope,

      // 값 목록은 표준(SATC_CI_REASONS)이 가진다. 우리 도메인에 복사하지 않는다.
      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZI_AtcReasonVH', element: 'ReasonCode' }
      }]
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
      SyncCriticality,
      ScopeCriticality,

      CreatedBy,
      LastChangedBy,
      CreatedAt,
      LastChangedAt,
      LocalLastChangedAt,

      _Item : redirected to composition child ZP_AtcExemptionItem,
      _Log  : redirected to composition child ZP_AtcExemptionLog
}
