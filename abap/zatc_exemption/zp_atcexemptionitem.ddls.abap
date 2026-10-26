@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC Exemption Request Target'
@Metadata.allowExtensions: true
define view entity ZP_AtcExemptionItem
  as projection on ZR_AtcExemptionItem
{
  key ItemUuid,

      ExemptUuid,
      ItemNo,

      // 새 줄은 비어 있다. 오브젝트(유형/이름)를 넣으면 OBJ, 패키지만 넣으면 PCKG. 읽기 전용.
      ScopeType,

      // 기본은 위반이 있는 패키지 목록(패키지당 한 줄, 체크로 거르지 않음).
      // 위반이 없는 패키지(선등록)는 두 번째 목록(고객 패키지 전체)에서 고르거나 직접 입력한다.
      @Consumption.valueHelpDefinition: [
        { entity:            { name: 'ZI_AtcFindingPkgVH', element: 'Devclass' } },
        { qualifier: 'AllPackages',
          label:     'All Customer Packages',
          entity:    { name: 'ZI_AtcPackageVH', element: 'Devclass' } }
      ]
      Devclass,

      ObjectType,

      // 위반이 있는 오브젝트 목록. 줄에 체크 클래스가 있으면 그 체크로 거르고, 비어 있으면
      // 모든 체크의 위반이 나온다. 고르면 유형·패키지·코드·체크 클래스가 같이 채워진다.
      @Consumption.valueHelpDefinition: [{
        entity:            { name: 'ZI_AtcFindingObjVH', element: 'ObjectName' },
        additionalBinding: [{ localElement: 'CheckClass', element: 'CheckClass', usage: #FILTER_AND_RESULT },
                            { localElement: 'ObjectType', element: 'ObjectType', usage: #RESULT },
                            { localElement: 'Devclass',   element: 'Devclass',   usage: #RESULT },
                            { localElement: 'CheckCode',  element: 'CheckCode',  usage: #RESULT }]
      }]
      ObjectName,

      // 이 줄의 체크 클래스(필수). 오브젝트 대상은 Object Name 값 도움이 채운다.
      // 직접 고를 때는 값 도움에서 변형 이름으로도 찾는다.
      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZI_AtcCheckClassVH', element: 'CheckClass' }
      }]
      CheckClass,

      // 오브젝트 대상에서 어긴 규칙 하나를 고른다. 비우면 그 체크의 모든 메시지(CHK). 패키지 대상은 비워 둔다.
      // 줄의 체크 클래스로 거르고, 체크 클래스가 비어 있으면 고른 코드의 체크 클래스가 채워진다.
      @Consumption.valueHelpDefinition: [{
        entity:            { name: 'ZI_AtcCheckCodeVH', element: 'CheckCode' },
        additionalBinding: [{ localElement: 'CheckClass', element: 'CheckClass', usage: #FILTER_AND_RESULT }]
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
