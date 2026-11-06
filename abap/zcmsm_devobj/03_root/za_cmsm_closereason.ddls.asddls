@EndUserText.label: '반려·취소 사유 입력'
// 요청 반려(rejectRequest)·취소(cancelRequest) 액션의 입력 팝업
define abstract entity ZA_CMSM_CloseReason
{
  @EndUserText.label: '사유'
  @UI.multiLineText: true
  CloseReason : abap.sstring( 1333 );
}
