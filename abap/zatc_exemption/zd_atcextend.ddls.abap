@EndUserText.label: '유효기간 연장 파라미터'
define abstract entity ZD_AtcExtend
{
  @EndUserText.label: '변경할 유효종료일'
  NewValidTo : abap.dats;

  @EndUserText.label: '연장 사유'
  ExtendReason : abap.string(0);
}
