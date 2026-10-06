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
      Title,

      // 변형-체크 클래스 짝 목록에서 고른다. 고르면 체크 클래스도 같이 채워진다.
      @Consumption.valueHelpDefinition: [{
        entity:            { name: 'ZI_AtcCheckClassVH', element: 'CheckVariant' },
        additionalBinding: [{ localElement: 'CheckClass', element: 'CheckClass', usage: #RESULT }]
      }]
      CheckVariant,

      // 컨트롤 테이블에서 파생되는 값이라 사용자가 고르지 않는다.
      CheckGroup,

      // 변형이 들어 있으면 그 변형의 체크만 보이고, 고르면 변형도 같이 채워진다.
      @Consumption.valueHelpDefinition: [{
        entity:            { name: 'ZI_AtcCheckClassVH', element: 'CheckClass' },
        additionalBinding: [{ localElement: 'CheckVariant', element: 'CheckVariant' }]
      }]
      CheckClass,

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

      StatusCriticality,

      CreatedBy,
      LastChangedBy,
      CreatedAt,
      LastChangedAt,
      LocalLastChangedAt,

      _Item : redirected to composition child ZP_AtcExemptionItem,
      _Log  : redirected to composition child ZP_AtcExemptionLog
}
