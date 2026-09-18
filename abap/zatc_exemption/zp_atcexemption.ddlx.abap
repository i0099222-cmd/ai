@Metadata.layer: #CORE
@UI: {
  headerInfo: {
    typeName:       'Exemption Request',
    typeNamePlural: 'Exemption Requests',
    title:          { type: #STANDARD, value: 'ScopeText' },
    description:    { value: 'CheckClass' }
  },
  // 신청번호가 없으므로 생성 시각 역순이 곧 최신순이다.
  presentationVariant: [{ sortOrder: [{ by: 'CreatedAt', direction: #DESC }] }]
}
annotate entity ZP_AtcExemption with
{
  @UI.facet: [
    { id: 'Head',   purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
      label: 'Request', position: 10 },
    { id: 'Scope',  purpose: #STANDARD, type: #FIELDGROUP_REFERENCE,
      label: 'Scope', position: 20, targetQualifier: 'ScopeGroup' },
    { id: 'Reason', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE,
      label: 'Reason and Validity', position: 30, targetQualifier: 'ReasonGroup' },
    { id: 'Item',   purpose: #STANDARD, type: #LINEITEM_REFERENCE,
      label: 'Evidence Findings', position: 40, targetElement: '_Item' },
    { id: 'Log',    purpose: #STANDARD, type: #LINEITEM_REFERENCE,
      label: 'History', position: 50, targetElement: '_Log' }
  ]

  @UI.hidden: true
  ExemptUuid;

  @UI: {
    lineItem:       [{ position: 10, importance: #HIGH }],
    identification: [{ position: 10 }],
    selectionField: [{ position: 10 }]
  }
  @EndUserText.label: 'Scope'
  ScopeText;

  @UI: {
    identification: [{ position: 15 }],
    selectionField: [{ position: 15 }]
  }
  @EndUserText.label: 'Check Variant'
  CheckVariant;

  @UI: {
    lineItem:       [{ position: 20, importance: #HIGH }],
    identification: [{ position: 20 }],
    selectionField: [{ position: 20 }]
  }
  @EndUserText.label: 'Check Group'
  CheckGroup;

  @UI: {
    lineItem:       [{ position: 30, importance: #HIGH,
                       criticality: 'ScopeCriticality' }],
    fieldGroup:     [{ qualifier: 'ScopeGroup', position: 10 }],
    selectionField: [{ position: 30 }]
  }
  @EndUserText.label: 'Object Scope'
  ScopeType;

  @UI: {
    lineItem:       [{ position: 40, importance: #HIGH }],
    fieldGroup:     [{ qualifier: 'ScopeGroup', position: 20 }],
    selectionField: [{ position: 40 }]
  }
  @EndUserText.label: 'Package'
  Devclass;

  // Phase 1 은 읽기 전용. 면제 판정이 하위 패키지를 전개하지 못한다.
  @UI.fieldGroup: [{ qualifier: 'ScopeGroup', position: 30 }]
  @EndUserText.label: 'Include Subpackages (Phase 2)'
  InclSubPkg;

  @UI: {
    lineItem:   [{ position: 50, importance: #MEDIUM }],
    fieldGroup: [{ qualifier: 'ScopeGroup', position: 40 }]
  }
  @EndUserText.label: 'Object Type'
  ObjectType;

  @UI: {
    lineItem:   [{ position: 60, importance: #HIGH }],
    fieldGroup: [{ qualifier: 'ScopeGroup', position: 50 }]
  }
  @EndUserText.label: 'Object Name'
  ObjectName;

  @UI.fieldGroup: [{ qualifier: 'ScopeGroup', position: 60 }]
  @EndUserText.label: 'Check Class'
  CheckClass;

  @UI.fieldGroup: [{ qualifier: 'ScopeGroup', position: 70 }]
  @EndUserText.label: 'Check Message Code'
  CheckCode;

  @UI.fieldGroup: [{ qualifier: 'ScopeGroup', position: 80 }]
  @EndUserText.label: 'Check Scope'
  RuleScope;

  @UI.fieldGroup: [{ qualifier: 'ReasonGroup', position: 10 }]
  @EndUserText.label: 'Reason Code'
  ReasonCode;

  @UI: {
    fieldGroup:  [{ qualifier: 'ReasonGroup', position: 20 }],
    multiLineText: true
  }
  @EndUserText.label: 'Justification'
  ReasonText;

  @UI.fieldGroup: [{ qualifier: 'ReasonGroup', position: 30 }]
  @EndUserText.label: 'Valid From'
  ValidFrom;

  @UI: {
    lineItem:   [{ position: 70, importance: #HIGH }],
    fieldGroup: [{ qualifier: 'ReasonGroup', position: 40 }]
  }
  @EndUserText.label: 'Valid To'
  ValidTo;

  @UI: {
    lineItem:       [{ position: 80, importance: #HIGH,
                       criticality: 'StatusCriticality' }],
    identification: [{ position: 30 }],
    selectionField: [{ position: 50 }]
  }
  @EndUserText.label: 'Status'
  ExemptStatus;

  @UI: {
    lineItem:       [{ position: 90, importance: #MEDIUM }],
    identification: [{ position: 40 }],
    selectionField: [{ position: 60 }]
  }
  @EndUserText.label: 'Requester'
  Requester;

  @UI: {
    lineItem:       [{ position: 100, importance: #MEDIUM }],
    identification: [{ position: 50 }]
  }
  @EndUserText.label: 'Approver'
  Approver;

  @UI.identification: [{ position: 60 }]
  @EndUserText.label: 'Approved At'
  ApprovedAt;

  @UI.identification: [{ position: 70 }]
  @EndUserText.label: 'Standard Exemption ID'
  ExtExemptId;

  @UI.identification: [{ position: 80 }]
  @EndUserText.label: 'Pre-Registered'
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
