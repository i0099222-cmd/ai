@EndUserText.label: '사용자 설정 저장 결과'
// ③ 저장 액션 saveSettings 의 결과 한 줄 (보낸 항목마다 한 줄)
// Status: CHANGED = 바꿈 / UNCHANGED = 현재값과 같아서 그대로 둠
// 에러는 결과가 아니라 HTTP 400 + 에러 메시지로 나간다 (그때는 아무것도 저장되지 않음)
define abstract entity ZD_CMUP_SaveResult
{
      @EndUserText.label: '항목 ID'
      ItemId     : abap.char(20);
      @EndUserText.label: '값'
      ParamValue : abap.char(40);
      @EndUserText.label: '값 텍스트'
      ValueText  : abap.char(80);
      @EndUserText.label: '상태 (CHANGED / UNCHANGED)'
      Status     : abap.char(10);
      @EndUserText.label: '메시지'
      Message    : abap.char(220);
}
