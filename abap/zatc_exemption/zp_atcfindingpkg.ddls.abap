@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ATC Findings by Package'
@Metadata.allowExtensions: true
define root view entity ZP_AtcFindingPkg
  provider contract transactional_query
  as projection on ZI_AtcFindingPkg
{
  key CheckVariant,
  key Devclass,
  key CheckClass,
      CheckGroup,
      FindingCount,
      ObjectCount,
      TopPriority,
      ExemptUuid,
      ExemptValidTo,
      ExemptionStatus
}
