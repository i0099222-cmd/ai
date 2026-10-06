@Metadata.layer: #CORE
@UI: {
  headerInfo: {
    typeName:       'Target',
    typeNamePlural: 'Targets',
    title:          { type: #STANDARD, value: 'Devclass' },
    description:    { value: 'ObjectName' }
  },
  presentationVariant: [{ sortOrder: [{ by: 'ItemNo', direction: #ASC }] }]
}
// 요청서의 'Targets' 표. 초안에서 줄을 추가하고 칸에 바로 입력한다.
//   Package 만 넣으면 패키지 대상, Object Name 까지 넣으면 오브젝트 대상이다.
//   값 도움에서 고르면 위반이 있는 대상, 직접 입력하면 위반이 없는 대상(선등록)도 된다.
annotate entity ZP_AtcExemptionItem with
{
  @UI.facet: [
    { id: 'Target', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
      label: 'Target', position: 10 }
  ]

  @UI.hidden: true
  ItemUuid;

  @UI.hidden: true
  ExemptUuid;

  @UI: {
    lineItem:       [{ position: 10, importance: #LOW }],
    identification: [{ position: 10 }]
  }
  @EndUserText.label: 'No.'
  ItemNo;

  @UI: {
    lineItem:       [{ position: 20, importance: #HIGH, criticality: 'ScopeCriticality' }],
    identification: [{ position: 20 }]
  }
  @EndUserText.label: 'Object Scope'
  ScopeType;

  @UI: {
    lineItem:       [{ position: 30, importance: #HIGH }],
    identification: [{ position: 30 }]
  }
  @EndUserText.label: 'Package'
  Devclass;

  @UI: {
    lineItem:       [{ position: 40, importance: #MEDIUM }],
    identification: [{ position: 40 }]
  }
  @EndUserText.label: 'Object Type'
  ObjectType;

  @UI: {
    lineItem:       [{ position: 50, importance: #HIGH }],
    identification: [{ position: 50 }]
  }
  @EndUserText.label: 'Object Name (empty = package)'
  ObjectName;

  @UI: {
    lineItem:       [{ position: 60, importance: #MEDIUM }],
    identification: [{ position: 60 }]
  }
  @EndUserText.label: 'Check Message Code'
  CheckCode;

  @UI.identification: [{ position: 70 }]
  @EndUserText.label: 'Check Scope'
  RuleScope;

  @UI: {
    lineItem:       [{ position: 80, importance: #MEDIUM, criticality: 'StdCriticality' }],
    identification: [{ position: 80, criticality: 'StdCriticality' }]
  }
  @EndUserText.label: 'Standard Status'
  StdStatus;

  @UI: {
    lineItem:       [{ position: 90, importance: #LOW }],
    identification: [{ position: 90 }]
  }
  @EndUserText.label: 'Standard Exemption ID'
  ExtExemptId;

  @UI.hidden: true
  CheckClass;
  @UI.hidden: true
  ScopeCriticality;
  @UI.hidden: true
  StdCriticality;
  @UI.hidden: true
  CreatedBy;
  @UI.hidden: true
  CreatedAt;
  @UI.hidden: true
  LastChangedBy;
  @UI.hidden: true
  LocalLastChangedAt;
}
