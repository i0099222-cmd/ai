@Metadata.layer: #CORE
@UI: {
  headerInfo: {
    typeName:       'Exemption Request',
    typeNamePlural: 'Exemption Requests',
    title:          { type: #STANDARD, value: 'Title' },
    description:    { value: 'CheckClass' }
  },
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
  // 탭 이름 앞의 기호는 아이콘 대용이다. 모두 BMP 범위(U+FFFF 이하) 문자만 쓴다.
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
  // 대상 표가 요청서의 본체다. 승인자는 이 표 하나로 무엇을 면제하는지 판단한다.
  @UI.facet: [
    { id: 'Head',    purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
      label: 'Request', position: 10 },
    { id: 'Reason',  purpose: #STANDARD, type: #FIELDGROUP_REFERENCE,
      label: 'Reason and Validity', position: 20, targetQualifier: 'ReasonGroup' },
    { id: 'Targets', purpose: #STANDARD, type: #LINEITEM_REFERENCE,
      label: 'Targets', position: 30, targetElement: '_Item' },
    { id: 'Log',     purpose: #STANDARD, type: #LINEITEM_REFERENCE,
      label: 'History', position: 40, targetElement: '_Log' }
  ]

  @UI.hidden: true
  ExemptUuid;

  @UI: {
    lineItem:       [{ position: 10, importance: #HIGH }],
    identification: [{ position: 10 }],
    selectionField: [{ position: 10 }]
  }
  @EndUserText.label: 'Title'
  Title;

  @UI: {
    lineItem:       [{ position: 20, importance: #MEDIUM }],
    identification: [{ position: 20 }],
    selectionField: [{ position: 20 }]
  }
  @EndUserText.label: 'Check Variant'
  CheckVariant;

  @UI: {
    lineItem:       [{ position: 30, importance: #HIGH }],
    identification: [{ position: 30 }],
    selectionField: [{ position: 30 }]
  }
  @EndUserText.label: 'Check Class'
  CheckClass;

  @UI: {
    lineItem:       [{ position: 40, importance: #MEDIUM }],
    identification: [{ position: 40 }],
    selectionField: [{ position: 40 }]
  }
  @EndUserText.label: 'Check Group'
  CheckGroup;

  @UI.fieldGroup: [{ qualifier: 'ReasonGroup', position: 10 }]
  @EndUserText.label: 'Reason Code'
  ReasonCode;

  @UI: {
    fieldGroup:    [{ qualifier: 'ReasonGroup', position: 20 }],
    multiLineText: true
  }
  @EndUserText.label: 'Justification'
  ReasonText;

  @UI.fieldGroup: [{ qualifier: 'ReasonGroup', position: 30 }]
  @EndUserText.label: 'Valid From'
  ValidFrom;

  @UI: {
    lineItem:   [{ position: 50, importance: #HIGH }],
    fieldGroup: [{ qualifier: 'ReasonGroup', position: 40 }]
  }
  @EndUserText.label: 'Valid To'
  ValidTo;

  @UI: {
    lineItem:       [{ position: 60, importance: #HIGH,
                       criticality: 'StatusCriticality' }],
    identification: [{ position: 50 }],
    selectionField: [{ position: 50 }]
  }
  @EndUserText.label: 'Status'
  ExemptStatus;

  @UI: {
    lineItem:       [{ position: 70, importance: #MEDIUM }],
    identification: [{ position: 60 }],
    selectionField: [{ position: 60 }]
  }
  @EndUserText.label: 'Requester'
  Requester;

  @UI: {
    lineItem:       [{ position: 80, importance: #MEDIUM }],
    identification: [{ position: 70 }]
  }
  @EndUserText.label: 'Approver'
  Approver;

  @UI.identification: [{ position: 80 }]
  @EndUserText.label: 'Approved At'
  ApprovedAt;

  @UI.hidden: true
  StatusCriticality;

  @UI.hidden: true
  CreatedBy;
  @UI.hidden: true
  LastChangedBy;
  @UI.lineItem: [{ position: 90, importance: #LOW }]
  @EndUserText.label: 'Created At'
  CreatedAt;
  @UI.hidden: true
  LastChangedAt;
  @UI.hidden: true
  LocalLastChangedAt;
}
