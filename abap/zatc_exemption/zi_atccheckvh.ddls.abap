@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '대상 체크 값 도움 (컨트롤 테이블 기반)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #D,
  sizeCategory: #XS,
  dataClass: #CUSTOMIZING
}
@ObjectModel.resultSet.sizeCategory: #XS
// 대상 체크를 코드에 하드코딩하지 않기 위한 값 도움.
// Phase 1 은 NAMING 행만 activeflg = X 로 둔다.
define view entity ZI_AtcCheckVH
  as select from ztatccfg
{
  key checkid     as CheckId,
  key messageid   as MessageId,
      checkgroup  as CheckGroup,
      maxpriority as MaxPriority,
      maxvalidmon as MaxValidMonths,
      reasonreq   as ReasonRequired,
      descr       as Description
}
where activeflg = 'X'
