@EndUserText.label: 'Pre-Register Exemptions'
// 신청 목록의 [Pre-Register] 입력창. 위반이 아직 없는 패키지나 오브젝트 여러 개를
// 한 번에 선등록한다. 대상마다 신청서가 하나씩 초안으로 생긴다.
//
// 대상은 자식(ZD_AtcPreRegisterTgt)으로 여러 행을 받는다(deep parameter).
// 동작 정의는 같은 이름의 abstract BDEF 에 있다.
// FE 기본 입력창은 deep parameter 를 그리지 못해 앱의 컨트롤러 확장이 입력창을 띄운다.
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

  // 선등록 대상. 한 행에 하나. Object Name 이 비면 패키지 신청, 있으면 오브젝트 신청.
  _Targets     : composition [1..*] of ZD_AtcPreRegisterTgt;
}
