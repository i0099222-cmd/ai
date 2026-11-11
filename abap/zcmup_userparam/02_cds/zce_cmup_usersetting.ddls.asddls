@EndUserText.label: '사용자 설정 (SU3)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CMUP_Q_USERSETTING'
// ① 현재 설정 조회 (GET) + ③ 수정 (PATCH, BDEF zce_cmup_usersetting)
// 한 줄 = 사용자 한 명의 항목 하나. 항목 목록은 zcl_cmup_config=>get_items.
define root custom entity ZCE_CMUP_UserSetting
{
      @EndUserText.label: '사용자 ID'
  key UserId     : abap.char(12);
      @EndUserText.label: '항목 ID'
  key ItemId     : abap.char(20);
      @EndUserText.label: '구분'
      Category   : abap.char(10);
      @EndUserText.label: '항목명'
      ItemName   : abap.char(60);
      @EndUserText.label: '값'
      ParamValue : abap.char(40);
      @EndUserText.label: '값 텍스트'
      ValueText  : abap.char(80);
      @EndUserText.label: '정렬 순서'
      SortOrder  : abap.int4;
}
