@EndUserText.label: 'Pre-Register Package Exemptions'
// 신청 목록의 [Pre-Register Packages] 입력창. 위반이 아직 없는 패키지 여러 개를
// 한 번에 선등록한다. 패키지마다 신청서가 하나씩 초안으로 생긴다.
//
// 패키지는 자식(ZD_AtcPreRegisterPkg)으로 여러 행을 받는다(deep parameter).
// 동작 정의는 같은 이름의 abstract BDEF 에 있다.
define root abstract entity ZD_AtcPreRegister
{
  // 고르면 체크 클래스가 같이 채워진다.
  @EndUserText.label: 'Check Variant'
  @Consumption.valueHelpDefinition: [{
    entity:            { name: 'ZI_AtcCheckClassVH', element: 'CheckVariant' },
    additionalBinding: [{ localElement: 'CheckClass', element: 'CheckClass', usage: #RESULT }]
  }]
  CheckVariant : abap.char(30);

  @EndUserText.label: 'Check Class'
  @Consumption.valueHelpDefinition: [{
    entity:            { name: 'ZI_AtcCheckClassVH', element: 'CheckClass' },
    additionalBinding: [{ localElement: 'CheckVariant', element: 'CheckVariant' }]
  }]
  CheckClass   : abap.char(30);

  @EndUserText.label: 'Reason Code'
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZI_AtcReasonVH', element: 'ReasonCode' }
  }]
  ReasonCode   : abap.char(4);

  @EndUserText.label: 'Justification'
  ReasonText   : abap.string(0);

  @EndUserText.label: 'Valid To'
  ValidTo      : abap.dats;

  // 선등록할 패키지. 한 행에 하나, * 를 쓰면 그 패턴의 고객 패키지 전부다(예: ZSD*).
  _Packages    : composition [1..*] of ZD_AtcPreRegisterPkg;
}
