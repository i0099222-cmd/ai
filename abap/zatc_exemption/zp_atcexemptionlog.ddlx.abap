@Metadata.layer: #CORE
@UI: {
  headerInfo: {
    typeName:       'History Entry',
    typeNamePlural: 'History',
    title:          { type: #STANDARD, value: 'ActionCode' },
    description:    { value: 'CommentText' }
  },
  presentationVariant: [{ sortOrder: [{ by: 'SeqNr', direction: #ASC }] }]
}
// 헤더의 'History' facet 이 이 엔터티를 LINEITEM_REFERENCE 로 참조한다.
// 감사 대응 시 "누가 언제 무엇을 왜" 가 한 줄로 읽혀야 하므로 그 넷을 모두
// 목록에 노출하고, 시간순(SeqNr 오름차순)으로 고정한다.
//
// 이력은 시스템이 쓰고 사용자는 읽기만 한다. BDEF 에서 create/update/delete 를
// 열지 않았으므로 여기서도 입력용 어노테이션을 두지 않는다.
annotate entity ZP_AtcExemptionLog with
{
  @UI.hidden: true
  LogUuid;

  @UI.hidden: true
  ExemptUuid;

  @UI.lineItem: [{ position: 10, importance: #LOW }]
  @EndUserText.label: 'Seq.'
  SeqNr;

  @UI.lineItem: [{ position: 20, importance: #HIGH }]
  @EndUserText.label: 'Action'
  ActionCode;

  @UI.lineItem: [{ position: 30, importance: #MEDIUM }]
  @EndUserText.label: 'From'
  FromStatus;

  @UI.lineItem: [{ position: 40, importance: #MEDIUM }]
  @EndUserText.label: 'To'
  ToStatus;

  @UI.lineItem: [{ position: 50, importance: #HIGH }]
  @EndUserText.label: 'By'
  ActionBy;

  @UI.lineItem: [{ position: 60, importance: #HIGH }]
  @EndUserText.label: 'At'
  ActionAt;

  // 반려 사유와 표준 반영 결과 메시지가 여기 들어간다. 길어질 수 있다.
  @UI: {
    lineItem:      [{ position: 70, importance: #HIGH }],
    multiLineText: true
  }
  @EndUserText.label: 'Comment'
  CommentText;
}
