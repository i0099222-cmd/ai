@EndUserText.label: 'Request Exemption from Findings'
// 위반 조회에서 [예외 신청] 을 누를 때 뜨는 입력창이다. 위반 탭과 패키지 탭이 같이 쓴다.
// 오브젝트·체크 값은 선택한 줄에서 가져오고, 적용범위는 탭이 정한다
// (위반 탭 = OBJ, 패키지 탭 = PCKG). 사용자가 채우는 것만 담는다.
define abstract entity ZD_AtcRequestExemption
{
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
