@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC Exemption Request'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZP_AtcExemption
  provider contract transactional_query
  as projection on ZR_AtcExemption
{
  key ExemptUuid,

      // 요청 번호. 처음 저장할 때 채번된다. 목록 검색은 번호 · 체크 클래스 · 신청자로 한다.
      @Search.defaultSearchElement: true
      ReqNumber,

      // 변형-체크 클래스 짝 목록에서 고른다. 고르면 체크 클래스도 같이 채워진다.
      @Consumption.valueHelpDefinition: [{
        entity:            { name: 'ZI_AtcCheckClassVH', element: 'CheckVariant' },
        additionalBinding: [{ localElement: 'CheckClass', element: 'CheckClass', usage: #RESULT }]
      }]
      CheckVariant,

      // 변형이 들어 있으면 그 변형의 체크만 보이고, 고르면 변형도 같이 채워진다.
      @Consumption.valueHelpDefinition: [{
        entity:            { name: 'ZI_AtcCheckClassVH', element: 'CheckClass' },
        additionalBinding: [{ localElement: 'CheckVariant', element: 'CheckVariant' }]
      }]
      @Search.defaultSearchElement: true
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

      @Search.defaultSearchElement: true
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
