@Metadata.layer: #CORE
@UI: {
  headerInfo: {
    typeName:       'ATC Finding',
    typeNamePlural: 'ATC Findings',
    title:          { type: #STANDARD, value: 'ObjectName' },
    description:    { value: 'MessageText' }
  },
  // 목록에서 위반을 여러 건 골라 한 번에 신청한다. 적용범위를 PCKG 로
  // 고르면 같은 패키지끼리 신청서 하나로 묶인다.
  lineItem: [{ type: #FOR_ACTION, dataAction: 'requestExemption',
               label: 'Request Exemption', position: 10 }]
}
annotate entity ZP_AtcFinding with
{
  // ATC 결과를 라이브로 읽는다. Phase 2 에서 대상 체크가 늘면 건수가 커지므로
  // 필수 필터를 걸어 전체 조회를 막는다.
  @UI.selectionField: [{ position: 10 }]
  @EndUserText.label: 'Package'
  Devclass;

  @UI.selectionField: [{ position: 15 }]
  @EndUserText.label: 'Check Variant'
  CheckVariant;

  @UI.selectionField: [{ position: 20 }]
  @EndUserText.label: 'Check Group'
  CheckGroup;

  @UI.selectionField: [{ position: 30 }]
  @EndUserText.label: 'Exemption Status'
  ExemptionStatus;

  @UI.selectionField: [{ position: 40 }]
  @EndUserText.label: 'Priority'
  Priority;

  @UI.selectionField: [{ position: 50 }]
  @EndUserText.label: 'Contact Person'
  ContactPerson;

  @UI.lineItem: [{ position: 10, importance: #HIGH }]
  @EndUserText.label: 'Object Type'
  ObjectType;

  @UI.lineItem: [{ position: 20, importance: #HIGH }]
  @EndUserText.label: 'Object Name'
  ObjectName;

  @UI.lineItem: [{ position: 30, importance: #MEDIUM }]
  @EndUserText.label: 'Message Text'
  MessageText;

  @UI.lineItem: [{ position: 40, importance: #MEDIUM }]
  @EndUserText.label: 'Priority'
  Priority;

  // 어느 범위의 예외로 풀렸는지. 패키지 예외로 함께 풀린 건은 PCKG 로 뜬다.
  @UI.lineItem: [{ position: 50, importance: #HIGH }]
  @EndUserText.label: 'Exempted Scope'
  ExemptScopeType;

  // 이 위반을 덮고 있는 신청서로 이동한다. 값이 있는 행만 링크가 된다.
  //
  // 앱이 둘이라(Finding / Exemption) 앱 내부 navigation 이 아니고, 런치패드의
  // 시맨틱 오브젝트 이동이다. 대상 매핑을 만들어야 링크가 살아난다 - README
  // 의 "런치패드 타일" 참고. 매핑이 없으면 값만 보이고 클릭이 안 된다.
  @Consumption.semanticObject: 'ZAtcExemption'
  @UI.lineItem: [{ position: 60, importance: #HIGH }]
  @EndUserText.label: 'Exemption Request'
  ExemptUuid;

  @UI.lineItem: [{ position: 70, importance: #MEDIUM }]
  @EndUserText.label: 'Exemption Valid To'
  ExemptValidTo;

  // 표준 예외 API 로 그대로 넘어가는 값. 비어 있으면 신청해도 표준 반영이
  // 실패한다. 진단에 필요하므로 목록에 두되 우선순위는 낮춘다.
  @UI.lineItem: [{ position: 80, importance: #LOW }]
  @EndUserText.label: 'Check Class'
  CheckClass;

  @UI.lineItem: [{ position: 85, importance: #LOW }]
  @EndUserText.label: 'Check Code'
  CheckCode;

  // 표준이 들고 있는 예외 상태. 대장과 나란히 보면 반영 누락이 드러난다.
  // 실제로 ATC 를 통과시키는지는 validity 가 정하므로 그것을 보여준다.
  //   '' 미상 / N 예외없음 / I 비활성 / A 승인대기 / E 적용중
  @UI.lineItem: [{ position: 75, importance: #MEDIUM }]
  @EndUserText.label: 'Standard Exemption'
  StdExemptionValidity;

  @UI.hidden: true
  StdExemptionKind;
  @UI.hidden: true
  StdExemptionApproval;

  @UI: {
    lineItem:       [{ position: 78, importance: #HIGH }],
    selectionField: [{ position: 35 }]
  }
  @EndUserText.label: 'Not Applied to Standard'
  ExemptionMismatch;
}
