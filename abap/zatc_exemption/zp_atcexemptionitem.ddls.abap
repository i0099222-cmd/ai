@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC Exemption Request Target'
@Metadata.allowExtensions: true
define view entity ZP_AtcExemptionItem
  as projection on ZR_AtcExemptionItem
{
  key ItemUuid,

      ExemptUuid,
      ItemNo,

      // Object Name 입력 여부로 정해진다(비면 PCKG, 있으면 OBJ). 읽기 전용.
      ScopeType,

      // 기본은 위반이 있는 패키지 목록(요청서의 체크로 거름).
      // 위반이 없는 패키지(선등록)는 두 번째 목록(고객 패키지 전체)에서 고르거나 직접 입력한다.
      @Consumption.valueHelpDefinition: [
        { entity:            { name: 'ZI_AtcFindingPkgVH', element: 'Devclass' },
          additionalBinding: [{ localElement: 'CheckClass', element: 'CheckClass', usage: #FILTER }] },
        { qualifier: 'AllPackages',
          label:     'All Customer Packages',
          entity:    { name: 'ZI_AtcPackageVH', element: 'Devclass' } }
      ]
      Devclass,

      ObjectType,

      // 위반이 있는 오브젝트 목록(요청서의 체크로 거름). 고르면 유형·패키지·코드가 같이 채워진다.
      @Consumption.valueHelpDefinition: [{
        entity:            { name: 'ZI_AtcFindingObjVH', element: 'ObjectName' },
        additionalBinding: [{ localElement: 'CheckClass', element: 'CheckClass', usage: #FILTER },
                            { localElement: 'ObjectType', element: 'ObjectType', usage: #RESULT },
                            { localElement: 'Devclass',   element: 'Devclass',   usage: #RESULT },
                            { localElement: 'CheckCode',  element: 'CheckCode',  usage: #RESULT }]
      }]
      ObjectName,

      // 요청서의 체크 클래스 사본. 값 도움 필터용이라 읽기 전용이다.
      CheckClass,

      // 오브젝트 대상에서 어긴 규칙 하나를 고른다. 패키지 대상은 비워 둔다.
      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZI_AtcCheckCodeVH', element: 'CheckCode' }
      }]
      CheckCode,

      RuleScope,
      ExtExemptId,
      StdStatus,

      ScopeCriticality,
      StdCriticality,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt,

      _Exemption : redirected to parent ZP_AtcExemption
}
