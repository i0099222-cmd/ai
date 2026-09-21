@Metadata.layer: #CORE
@UI: {
  headerInfo: {
    typeName:       'Evidence Finding',
    typeNamePlural: 'Evidence Findings',
    title:          { type: #STANDARD, value: 'ObjectName' },
    description:    { value: 'MessageText' }
  }
}
// 헤더의 'Evidence Findings' facet 이 이 엔터티를 LINEITEM_REFERENCE 로 참조한다.
// 승인자가 이 테이블만 보고 "무엇을 면제하는가" 를 판단할 수 있어야 하므로
// 위반 메시지를 가장 중요하게 둔다.
//
// 아이템은 화면에서 만들거나 고치지 않는다(증빙 스냅샷). 그래서 입력 편의를
// 위한 값 도움이나 필드 그룹을 두지 않는다.
annotate entity ZP_AtcExemptionItem with
{
  @UI.hidden: true
  ItemUuid;

  @UI.hidden: true
  ExemptUuid;

  @UI.lineItem: [{ position: 10, importance: #LOW }]
  @EndUserText.label: 'No.'
  ItemNo;

  @UI.lineItem: [{ position: 20, importance: #MEDIUM }]
  @EndUserText.label: 'Object Type'
  ObjectType;

  @UI.lineItem: [{ position: 30, importance: #HIGH }]
  @EndUserText.label: 'Object Name'
  ObjectName;

  @UI.lineItem: [{ position: 40, importance: #MEDIUM }]
  @EndUserText.label: 'Check Class'
  CheckClass;

  @UI.lineItem: [{ position: 50, importance: #MEDIUM }]
  @EndUserText.label: 'Check Message Code'
  CheckCode;

  @UI.lineItem: [{ position: 60, importance: #MEDIUM }]
  @EndUserText.label: 'Priority'
  Priority;

  // 승인 판단의 핵심. 이 한 줄이 무엇을 면제하는지 말해 준다.
  @UI: {
    lineItem:      [{ position: 70, importance: #HIGH }],
    multiLineText: true
  }
  @EndUserText.label: 'Finding'
  MessageText;

  // 코드가 바뀌어도 같은 위반이면 유지되는 식별자. 사람이 읽을 값은 아니다.
  @UI.hidden: true
  Checksum;

  @UI.hidden: true
  CreatedBy;
  @UI.hidden: true
  CreatedAt;
  @UI.hidden: true
  LastChangedBy;
  @UI.hidden: true
  LocalLastChangedAt;
}
