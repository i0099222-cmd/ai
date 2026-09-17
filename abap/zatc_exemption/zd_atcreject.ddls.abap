@EndUserText.label: 'Reject Exemption Request'
define abstract entity ZD_AtcReject
{
  // 반려 사유는 필수다. 사유 없이 반려하면 신청자가 무엇을 고쳐야 할지 모른다.
  @EndUserText.label: 'Rejection Reason'
  RejectReason : abap.string(0);
}
