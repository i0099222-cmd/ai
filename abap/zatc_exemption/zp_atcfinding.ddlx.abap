@Metadata.layer: #CORE
@UI: {
  headerInfo: {
    typeName:       'ATC Finding',
    typeNamePlural: 'ATC Findings',
    title:          { type: #STANDARD, value: 'ObjectName' },
    description:    { value: 'MessageText' }
  },
  // 목록에서 위반을 여러 건 골라 한 번에 오브젝트 단위로 신청한다.
  // 패키지 단위 신청은 패키지 탭(ZP_AtcFindingPkg)에서 한다.
  //
  // 두 번째는 신청 목록으로 가는 이동 버튼이다. 액션 자체는 화면을 옮기지
  // 못하므로, 신청한 뒤 결과를 보려면 따로 눌러야 한다. 파라미터를 넘기지
  // 않으므로 그 사람의 신청 목록이 그냥 열린다 - 특정 신청서로 바로 가려면
  // 키가 필요하고, 그건 신청번호를 도입할 때 같이 한다.
  lineItem: [{ type: #FOR_ACTION, dataAction: 'requestExemption',
               label: 'Request Object Exemption', position: 10 },
             { type: #FOR_INTENT_BASED_NAVIGATION,
               semanticObject: 'ZAtcExemption', action: 'display',
               label: 'My Exemption Requests', position: 20 }],
  // 앱 manifest 의 views.paths 가 이 한정자를 참조해 탭을 만든다.
  presentationVariant: [{ qualifier: 'pvTab', visualizations: [{ type: #AS_LINEITEM }] }],
  selectionVariant: [{ qualifier: 'svTab', text: 'By Object' }],
  selectionPresentationVariant: [{ qualifier: 'Tab', text: 'By Object',
                                   selectionVariantQualifier: 'svTab',
                                   presentationVariantQualifier: 'pvTab' }]
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

  // 이 위반을 덮고 있는 신청서의 키. 화면에는 보이지 않는다 - UUID 를 사람에게
  // 보여줄 이유가 없다. 뷰에 남겨 두는 이유는 특정 신청서로 바로 이동하는 기능이
  // 여기 걸릴 자리이기 때문이다. 그때는 이 값이 아니라 신청번호를 쓴다.
  @UI.hidden: true
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
