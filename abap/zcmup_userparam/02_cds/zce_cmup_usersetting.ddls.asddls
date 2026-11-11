@EndUserText.label: '사용자 설정 (SU3)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CMUP_Q_USERSETTING'
// ① 현재 설정 조회 (GET) + ③ 저장 (정적 액션 saveSettings, BDEF zce_cmup_usersetting)
// 한 줄 = 로그온 사용자의 항목 하나. 항목 목록은 zcl_cmup_value_help=>get_item_ids.
// 화면용 정보(항목명, 순서, 구분)는 웹이 정한다.
define root custom entity ZCE_CMUP_UserSetting
{
      @EndUserText.label: '사용자 ID'
  key UserId     : abap.char(12);
      @EndUserText.label: '항목 ID'
  key ItemId     : abap.char(20);
      @EndUserText.label: '값'
      ParamValue : abap.char(40);
      @EndUserText.label: '값 텍스트'
      ValueText  : abap.char(80);
}
