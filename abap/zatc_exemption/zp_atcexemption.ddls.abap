@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC Exemption Request'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZP_AtcExemption
  provider contract transactional_query
  as projection on ZR_AtcExemption
{
  key ExemptUuid,

      // 요청 번호. 처음 저장할 때 채번된다. 목록 검색은 번호 · 신청자로 한다.
      // 체크(변형/클래스)는 대상 줄마다 고른다.
      @Search.defaultSearchElement: true
      ReqNumber,

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
