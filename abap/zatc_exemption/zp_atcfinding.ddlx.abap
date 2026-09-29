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

  @UI.lineItem: [{ position: 70, importance: #MEDIUM }]
  @EndUserText.label: 'Exemption Valid To'
  ExemptValidTo;

  // 표준이 들고 있는 예외 상태. 대장과 나란히 보면 반영 누락이 드러난다.
  @UI.lineItem: [{ position: 75, importance: #MEDIUM }]
  @EndUserText.label: 'Standard Exemption'
  StdExemptionKind;

  @UI.hidden: true
  StdExemptionValidity;
  @UI.hidden: true
  StdExemptionApproval;

  @UI: {
    lineItem:       [{ position: 78, importance: #HIGH }],
    selectionField: [{ position: 35 }]
  }
  @EndUserText.label: 'Not Applied to Standard'
  ExemptionMismatch;
}
