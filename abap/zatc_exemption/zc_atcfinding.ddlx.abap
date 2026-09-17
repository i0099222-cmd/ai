@Metadata.layer: #CORE
@UI: {
  headerInfo: {
    typeName:       'ATC 위반',
    typeNamePlural: 'ATC 위반 현황',
    title:          { type: #STANDARD, value: 'ObjectName' },
    description:    { value: 'MessageText' }
  }
}
annotate entity ZC_AtcFinding with
{
  // ATC 결과를 라이브로 읽는다. Phase 2 에서 대상 체크가 늘면 건수가 커지므로
  // 필수 필터를 걸어 전체 조회를 막는다.
  @UI.selectionField: [{ position: 10 }]
  @EndUserText.label: '패키지'
  Devclass;

  @UI.selectionField: [{ position: 20 }]
  @EndUserText.label: '체크그룹'
  CheckGroup;

  @UI.selectionField: [{ position: 30 }]
  @EndUserText.label: '면제 여부'
  ExemptionStatus;

  @UI.selectionField: [{ position: 40 }]
  @EndUserText.label: 'Priority'
  Priority;

  @UI.selectionField: [{ position: 50 }]
  @EndUserText.label: '담당자'
  ContactPerson;

  @UI.lineItem: [{ position: 10, importance: #HIGH }]
  @EndUserText.label: '오브젝트 타입'
  ObjectType;

  @UI.lineItem: [{ position: 20, importance: #HIGH }]
  @EndUserText.label: '오브젝트명'
  ObjectName;

  @UI.lineItem: [{ position: 30, importance: #MEDIUM }]
  @EndUserText.label: '메시지'
  MessageText;

  @UI.lineItem: [{ position: 40, importance: #MEDIUM }]
  @EndUserText.label: 'Priority'
  Priority;

  // 면제 근거가 된 신청번호. 패키지 예외로 함께 풀린 건도 여기에 번호가 뜬다.
  @UI.lineItem: [{ position: 50, importance: #HIGH }]
  @EndUserText.label: '근거 신청번호'
  ExemptId;

  @UI.lineItem: [{ position: 60, importance: #HIGH }]
  @EndUserText.label: '면제 범위'
  ExemptScopeType;

  @UI.lineItem: [{ position: 70, importance: #MEDIUM }]
  @EndUserText.label: '면제 만료일'
  ExemptValidTo;
}
