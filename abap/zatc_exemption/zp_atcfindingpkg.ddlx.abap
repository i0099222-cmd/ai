@Metadata.layer: #CORE
@UI: {
  headerInfo: {
    typeName:       'Package',
    typeNamePlural: 'Packages',
    title:          { type: #STANDARD, value: 'Devclass' },
    description:    { value: 'CheckClass' }
  },
  lineItem: [{ type: #FOR_ACTION, dataAction: 'requestExemption',
               label: 'Request Package Exemption', position: 10 },
             { type: #FOR_INTENT_BASED_NAVIGATION,
               semanticObject: 'ZAtcExemption', action: 'display',
               label: 'My Exemption Requests', position: 20 }],
  // 앱 manifest 의 views.paths 가 이 한정자를 참조해 탭을 만든다.
  presentationVariant: [{ qualifier: 'pvTab', visualizations: [{ type: #AS_LINEITEM }],
                          sortOrder: [{ by: 'FindingCount', direction: #DESC }] }],
  selectionVariant: [{ qualifier: 'svTab', text: 'By Package' }],
  selectionPresentationVariant: [{ qualifier: 'Tab', text: 'By Package',
                                   selectionVariantQualifier: 'svTab',
                                   presentationVariantQualifier: 'pvTab' }]
}
annotate entity ZP_AtcFindingPkg with
{
  // 필터 필드는 위반 탭과 이름을 맞췄다. 두 탭에 같이 걸린다.
  @UI: {
    lineItem:       [{ position: 10, importance: #HIGH }],
    selectionField: [{ position: 10 }]
  }
  @EndUserText.label: 'Package'
  Devclass;

  @UI.selectionField: [{ position: 15 }]
  @EndUserText.label: 'Check Variant'
  CheckVariant;

  @UI.selectionField: [{ position: 20 }]
  @EndUserText.label: 'Check Group'
  CheckGroup;

  @UI.lineItem: [{ position: 20, importance: #HIGH }]
  @EndUserText.label: 'Check Class'
  CheckClass;

  @UI.lineItem: [{ position: 30, importance: #HIGH }]
  @EndUserText.label: 'Findings'
  FindingCount;

  @UI.lineItem: [{ position: 40, importance: #MEDIUM }]
  @EndUserText.label: 'Objects'
  ObjectCount;

  @UI.lineItem: [{ position: 50, importance: #MEDIUM }]
  @EndUserText.label: 'Top Priority'
  TopPriority;

  @UI: {
    lineItem:       [{ position: 60, importance: #HIGH }],
    selectionField: [{ position: 30 }]
  }
  @EndUserText.label: 'Exemption Status'
  ExemptionStatus;

  @UI.lineItem: [{ position: 70, importance: #MEDIUM }]
  @EndUserText.label: 'Exemption Valid To'
  ExemptValidTo;

  @UI.hidden: true
  ExemptUuid;
}
