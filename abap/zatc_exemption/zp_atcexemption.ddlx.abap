@Metadata.layer: #CORE
@UI: {
  headerInfo: {
    typeName:       'Exemption Request',
    typeNamePlural: 'Exemption Requests',
    title:          { type: #STANDARD, value: 'ScopeText' },
    description:    { value: 'CheckClass' }
  },
  // [Pre-Register Packages] 버튼은 여기 두지 않는다. FE 기본 입력창이 deep parameter
  // (패키지 여러 행)를 그리지 못해서, 앱의 컨트롤러 확장이 입력창을 직접 띄운다
  // (manifest custom action → ListReportExt.onPreRegister).
  // 신청번호가 없으므로 생성 시각 역순이 곧 최신순이다.
  // 한정자 없는 것은 기본 목록용, pvList 는 탭(다중 뷰)이 공유한다.
  presentationVariant: [
    { sortOrder: [{ by: 'CreatedAt', direction: #DESC }] },
    { qualifier: 'pvList',
      sortOrder: [{ by: 'CreatedAt', direction: #DESC }],
      visualizations: [{ type: #AS_LINEITEM }] }
  ],

  // 상태별 탭. 앱 manifest 의 views.paths 가 SelectionPresentationVariant 를
  // 한정자로 참조해야 탭이 생긴다. 참조하지 않으면 아무 영향이 없다.
  // 상태 값은 zif_atc_exemption=>status 와 같아야 한다.
  selectionVariant: [
    { qualifier: 'svDraft',    text: 'Draft',            filter: 'ExemptStatus EQ 10' },
    { qualifier: 'svPending',  text: 'Pending Approval', filter: 'ExemptStatus EQ 20' },
    { qualifier: 'svApproved', text: 'Approved',         filter: 'ExemptStatus EQ 30' },
    { qualifier: 'svRejected', text: 'Rejected',         filter: 'ExemptStatus EQ 40' }
  ],
  // 탭 이름 앞의 기호는 아이콘 대용이다. Fiori Elements 의 탭은 아이콘 속성을
  // 받지 않아서 이름에 붙인다. 모두 BMP 범위(U+FFFF 이하) 문자만 쓴다 - ABAP 은
  // 내부적으로 UCS-2 라 그 밖의 이모지(📝 등)는 깨질 수 있다.
  selectionPresentationVariant: [
    { qualifier: 'Draft',    text: '✎ Draft',
      selectionVariantQualifier: 'svDraft',    presentationVariantQualifier: 'pvList' },
    { qualifier: 'Pending',  text: '⏳ Pending Approval',
      selectionVariantQualifier: 'svPending',  presentationVariantQualifier: 'pvList' },
    { qualifier: 'Approved', text: '✅ Approved',
      selectionVariantQualifier: 'svApproved', presentationVariantQualifier: 'pvList' },
    { qualifier: 'Rejected', text: '❌ Rejected',
      selectionVariantQualifier: 'svRejected', presentationVariantQualifier: 'pvList' }
  ]
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

  // 오브젝트 신청에서만 필수다(validateScope, 메시지 022). 패키지 신청은 비워도 된다.
  @UI.fieldGroup: [{ qualifier: 'ScopeGroup', position: 70 }]
  @EndUserText.label: 'Check Message Code'
  CheckCode;

  // 적용범위로 자동 결정된다(패키지 → CHK, 오브젝트 → MSG). 읽기 전용.
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
  // 표준 반영 결과. saver 가 메시지를 띄울 수 없으므로 색으로 알린다.
  // 상신/승인인데 비어 있으면 적색 - 대장은 진행됐는데 ATC 는 계속 막는다.
  @UI: {
    lineItem:       [{ position: 90, importance: #HIGH,
                       criticality: 'SyncCriticality' }],
    identification: [{ position: 70, criticality: 'SyncCriticality' }]
  }
  @EndUserText.label: 'Standard Exemption ID'
  ExtExemptId;

  @UI.identification: [{ position: 80 }]
  @EndUserText.label: 'Pre-Registered'
  PreRegFlag;

  @UI.hidden: true
  SyncCriticality;
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
