@Metadata.layer: #CORE
@UI: {
  headerInfo: {
    typeName:       'Exemption Request',
    typeNamePlural: 'Exemption Requests',
    // 신청자는 머리글 data point 로 보이므로 description 으로 또 두지 않는다.
    title:          { type: #STANDARD, value: 'ReqNumber' }
  },
  // 요청 번호는 번호 범위 버퍼링 때문에 생성 순서와 어긋날 수 있다. 최신순은 생성 시각으로 정렬한다.
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
  // 머리글은 상태(색)·신청자·승인자·승인 시각의 data point 다. 요청 번호는 제목이다.
  // 대상 표가 요청서의 본체다. 승인자는 이 표 하나로 무엇을 면제하는지 판단한다.
  @UI.facet: [
    { id: 'HdrStatus',     purpose: #HEADER, type: #DATAPOINT_REFERENCE,
      targetQualifier: 'Status',     position: 10 },
    { id: 'HdrRequester',  purpose: #HEADER, type: #DATAPOINT_REFERENCE,
      targetQualifier: 'Requester',  position: 20 },
    { id: 'HdrApprover',   purpose: #HEADER, type: #DATAPOINT_REFERENCE,
      targetQualifier: 'Approver',   position: 30 },
    { id: 'HdrApprovedAt', purpose: #HEADER, type: #DATAPOINT_REFERENCE,
      targetQualifier: 'ApprovedAt', position: 40 },
    { id: 'Reason',  purpose: #STANDARD, type: #FIELDGROUP_REFERENCE,
      label: 'Request Details', position: 20, targetQualifier: 'ReasonGroup' },
    { id: 'Targets', purpose: #STANDARD, type: #LINEITEM_REFERENCE,
      label: 'Targets', position: 30, targetElement: '_Item' },
    { id: 'Log',     purpose: #STANDARD, type: #LINEITEM_REFERENCE,
      label: 'History', position: 40, targetElement: '_Log' }
  ]

  @UI.hidden: true
  ExemptUuid;

  // 버튼은 요청서(헤더)의 액션이다. 대상 표(아이템)에는 액션이 없다.
  //   목록 툴바    : 여러 건을 골라 한 번에 - Submit / Withdraw / Approve / Reject
  //   Object Page : 한 건을 열어 보고 - 위 넷 + Extend Validity(입력창) + Simulate Impact
  // 활성화 여부는 instance features 가 상태·신청자·승인자로 정한다.
  @UI: {
    lineItem:       [{ position: 10, importance: #HIGH },
                     { type: #FOR_ACTION, dataAction: 'submit',   label: 'Submit' },
                     { type: #FOR_ACTION, dataAction: 'withdraw', label: 'Withdraw' },
                     { type: #FOR_ACTION, dataAction: 'approve',  label: 'Approve' },
                     { type: #FOR_ACTION, dataAction: 'reject',   label: 'Reject' }],
    identification: [{ type: #FOR_ACTION, dataAction: 'submit',         label: 'Submit' },
                     { type: #FOR_ACTION, dataAction: 'withdraw',       label: 'Withdraw' },
                     { type: #FOR_ACTION, dataAction: 'approve',        label: 'Approve' },
                     { type: #FOR_ACTION, dataAction: 'reject',         label: 'Reject' },
                     { type: #FOR_ACTION, dataAction: 'extendValidity', label: 'Extend Validity' },
                     { type: #FOR_ACTION, dataAction: 'simulateImpact', label: 'Simulate Impact' }],
    selectionField: [{ position: 10 }]
  }
  // 요청 번호. 처음 저장할 때 채번되는 읽기 전용 값이고 Object Page 에서는 제목이다.
  // 액션 버튼도 이 필드에 달려 있다(identification 의 액션은 Object Page 머리글 버튼이 된다).
  @EndUserText.label: 'Request No.'
  ReqNumber;

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
    selectionField: [{ position: 50 }],
    dataPoint:      { qualifier: 'Status', title: 'Status', criticality: 'StatusCriticality' }
  }
  @EndUserText.label: 'Status'
  ExemptStatus;

  @UI: {
    lineItem:       [{ position: 70, importance: #MEDIUM }],
    selectionField: [{ position: 60 }],
    dataPoint:      { qualifier: 'Requester', title: 'Requester' }
  }
  @EndUserText.label: 'Requester'
  Requester;

  // 신청자가 초안에서 고르는 승인자. 그 사람만 결재할 수 있고, 결재하면 결재한 사람으로 남는다.
  @UI: {
    lineItem:   [{ position: 80, importance: #MEDIUM }],
    fieldGroup: [{ qualifier: 'ReasonGroup', position: 50 }],
    dataPoint:  { qualifier: 'Approver', title: 'Approver' }
  }
  @EndUserText.label: 'Approver'
  Approver;

  @UI.dataPoint: { qualifier: 'ApprovedAt', title: 'Approved At' }
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
