@EndUserText.label: '사용자 설정 저장 항목'
// ③ 저장 액션의 항목 한 줄. 빈 값 = 파라미터 삭제 (기본값 항목은 BAPI 가 판단)
define abstract entity ZD_CMUP_SaveItem
{
      @EndUserText.label: '항목 ID'
      ItemId     : abap.char(20);
      @EndUserText.label: '값'
      ParamValue : abap.char(40);
      _Request   : association to parent ZD_CMUP_SaveRequest;
}
