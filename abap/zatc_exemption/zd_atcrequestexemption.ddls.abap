@EndUserText.label: 'Request Exemption from Findings'
// 조회 화면에서 위반을 골라 [예외 신청] 을 누를 때 뜨는 입력창이다.
// 오브젝트·체크 값은 선택한 finding 에서 가져오므로 여기 없다.
// 사용자가 채우는 것만 담는다.
define abstract entity ZD_AtcRequestExemption
{
  // PCKG 를 고르면 같은 패키지의 선택 건들이 신청서 하나로 묶인다.
  @EndUserText.label: 'Object Scope'
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZI_AtcScopeVH', element: 'ScopeType' }
  }]
  ScopeType  : abap.char(4);

  @EndUserText.label: 'Reason Code'
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZI_AtcReasonVH', element: 'ReasonCode' }
  }]
  ReasonCode : abap.char(4);

  @EndUserText.label: 'Justification'
  ReasonText : abap.string(0);

  @EndUserText.label: 'Valid To'
  ValidTo    : abap.dats;
}
