@EndUserText.label: '사용자 설정 저장 요청'
// ③ 저장 액션 saveSettings 의 파라미터 (deep parameter)
// 바꿀 항목만 _Items 에 담아서 보낸다. 목록에 없는 항목은 손대지 않는다.
define root abstract entity ZD_CMUP_SaveRequest
{
      @EndUserText.label: '사용자 ID (비우면 로그온 사용자)'
      UserId : abap.char(12);
      _Items : composition [1..*] of ZD_CMUP_SaveItem;
}
