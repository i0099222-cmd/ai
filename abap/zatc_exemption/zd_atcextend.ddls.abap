@EndUserText.label: 'Extend Validity'
define abstract entity ZD_AtcExtend
{
  @EndUserText.label: 'New Valid To'
  NewValidTo : abap.dats;

  @EndUserText.label: 'Extension Reason'
  ExtendReason : abap.string(0);
}
