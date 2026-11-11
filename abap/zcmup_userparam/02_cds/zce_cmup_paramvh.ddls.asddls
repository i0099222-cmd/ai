@EndUserText.label: '사용자 파라미터 Value Help'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CMUP_Q_PARAMVH'
@Search.searchable: true
// ② Value Help (GET) · 검색 버튼 팝업 목록
// p_itemid = 항목 ID (BUK, WRK, DATFM, TZONE ...) → 그 항목에서 고를 수 있는 값 목록
define custom entity ZCE_CMUP_ParamVH
  with parameters
    @EndUserText.label: '항목 ID'
    p_itemid : abap.char(20)
{
      @EndUserText.label: '항목 ID'
  key ItemId     : abap.char(20);
      @EndUserText.label: '값'
      @Search.defaultSearchElement: true
  key ParamValue : abap.char(40);
      @EndUserText.label: '텍스트'
      @Search.defaultSearchElement: true
      ValueText  : abap.char(80);
}
