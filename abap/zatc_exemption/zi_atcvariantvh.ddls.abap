@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Check Variant Value Help'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #D,
  sizeCategory: #XS,
  dataClass: #CUSTOMIZING
}
@ObjectModel.resultSet.sizeCategory: #XS
// 앱이 취급하는 체크 변형 목록. Phase 1 은 네이밍 변형 1행이다.
define view entity ZI_AtcVariantVH
  as select from ztatccfg
{
  key checkvariant as CheckVariant,
      checkgroup   as CheckGroup,
      maxvalidmon  as MaxValidMonths,
      reasonreq    as ReasonRequired,
      notiftype    as NotificationType,
      maxpriority  as MaxPriority
}
where activeflg = 'X'
