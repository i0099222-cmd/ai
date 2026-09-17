@Metadata.layer: #CORE
@UI: {
  headerInfo: {
    typeName:       'ATC 예외',
    typeNamePlural: 'ATC 예외',
    title:          { type: #STANDARD, value: 'ExemptId' },
    description:    { value: 'Devclass' }
  },
  presentationVariant: [{ sortOrder: [{ by: 'ExemptId', direction: #DESC }] }]
}
annotate entity ZC_AtcExemption with
{
  @UI.facet: [
    { id: 'Head',   purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
      label: '신청 정보', position: 10 },
    { id: 'Scope',  purpose: #STANDARD, type: #FIELDGROUP_REFERENCE,
      label: '적용 범위', position: 20, targetQualifier: 'ScopeGroup' },
    { id: 'Reason', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE,
      label: '사유 및 유효기간', position: 30, targetQualifier: 'ReasonGroup' },
    { id: 'Item',   purpose: #STANDARD, type: #LINEITEM_REFERENCE,
      label: '근거 finding', position: 40, targetElement: '_Item' },
    { id: 'Log',    purpose: #STANDARD, type: #LINEITEM_REFERENCE,
      label: '처리 이력', position: 50, targetElement: '_Log' }
  ]

  @UI.hidden: true
  ExemptUuid;

  @UI: {
    lineItem:       [{ position: 10, importance: #HIGH }],
    identification: [{ position: 10 }],
    selectionField: [{ position: 10 }]
  }
  @EndUserText.label: '신청번호'
  ExemptId;

  @UI: {
    identification: [{ position: 15 }],
    selectionField: [{ position: 15 }]
  }
  @EndUserText.label: '체크 변형'
  CheckVariant;

  @UI: {
    lineItem:       [{ position: 20, importance: #HIGH }],
    identification: [{ position: 20 }],
    selectionField: [{ position: 20 }]
  }
  @EndUserText.label: '체크그룹'
  CheckGroup;

  @UI: {
    lineItem:       [{ position: 30, importance: #HIGH,
                       criticality: 'ScopeCriticality' }],
    fieldGroup:     [{ qualifier: 'ScopeGroup', position: 10 }],
    selectionField: [{ position: 30 }]
  }
  @EndUserText.label: '적용범위'
  ScopeType;

  @UI: {
    lineItem:       [{ position: 40, importance: #HIGH }],
    fieldGroup:     [{ qualifier: 'ScopeGroup', position: 20 }],
    selectionField: [{ position: 40 }]
  }
  @EndUserText.label: '패키지'
  Devclass;

  // Phase 1 은 읽기 전용. 면제 판정이 하위 패키지를 전개하지 못한다.
  @UI.fieldGroup: [{ qualifier: 'ScopeGroup', position: 30 }]
  @EndUserText.label: '하위 패키지 포함 (Phase 2)'
  InclSubPkg;

  @UI: {
    lineItem:   [{ position: 50, importance: #MEDIUM }],
    fieldGroup: [{ qualifier: 'ScopeGroup', position: 40 }]
  }
  @EndUserText.label: '오브젝트 타입'
  ObjectType;

  @UI: {
    lineItem:   [{ position: 60, importance: #HIGH }],
    fieldGroup: [{ qualifier: 'ScopeGroup', position: 50 }]
  }
  @EndUserText.label: '오브젝트명'
  ObjectName;

  // FND 스코프 전용. Phase 1 에서는 화면에 내보내지 않는다.
  @UI.hidden: true
  SubObject;
  @UI.hidden: true
  LineNo;
  @UI.hidden: true
  FindingKey;

  @UI.fieldGroup: [{ qualifier: 'ScopeGroup', position: 60 }]
  @EndUserText.label: '체크 ID'
  CheckId;

  @UI.fieldGroup: [{ qualifier: 'ScopeGroup', position: 70 }]
  @EndUserText.label: '메시지 ID'
  MessageId;

  @UI.fieldGroup: [{ qualifier: 'ScopeGroup', position: 80 }]
  @EndUserText.label: '규칙 적용 축'
  RuleScope;

  @UI.fieldGroup: [{ qualifier: 'ReasonGroup', position: 10 }]
  @EndUserText.label: '사유 코드'
  ReasonCode;

  @UI: {
    fieldGroup:  [{ qualifier: 'ReasonGroup', position: 20 }],
    multiLineText: true
  }
  @EndUserText.label: '근거'
  ReasonText;

  @UI.fieldGroup: [{ qualifier: 'ReasonGroup', position: 30 }]
  @EndUserText.label: '유효시작일'
  ValidFrom;

  @UI: {
    lineItem:   [{ position: 70, importance: #HIGH }],
    fieldGroup: [{ qualifier: 'ReasonGroup', position: 40 }]
  }
  @EndUserText.label: '유효종료일'
  ValidTo;

  @UI: {
    lineItem:       [{ position: 80, importance: #HIGH,
                       criticality: 'StatusCriticality' }],
    identification: [{ position: 30 }],
    selectionField: [{ position: 50 }]
  }
  @EndUserText.label: '상태'
  ExemptStatus;

  @UI: {
    lineItem:       [{ position: 90, importance: #MEDIUM }],
    identification: [{ position: 40 }],
    selectionField: [{ position: 60 }]
  }
  @EndUserText.label: '신청자'
  Requester;

  @UI: {
    lineItem:       [{ position: 100, importance: #MEDIUM }],
    identification: [{ position: 50 }]
  }
  @EndUserText.label: '승인자'
  Approver;

  @UI.identification: [{ position: 60 }]
  @EndUserText.label: '승인일시'
  ApprovedAt;

  @UI.identification: [{ position: 70 }]
  @EndUserText.label: '표준 예외 ID'
  ExtExemptId;

  @UI.identification: [{ position: 80 }]
  @EndUserText.label: '사전등록'
  PreRegFlag;

  @UI.hidden: true
  StatusCriticality;
  @UI.hidden: true
  ScopeCriticality;

  @UI.hidden: true
  CreatedBy;
  @UI.hidden: true
  LastChangedBy;
  @UI.hidden: true
  CreatedAt;
  @UI.hidden: true
  LastChangedAt;
  @UI.hidden: true
  LocalLastChangedAt;
}
