@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '배치잡 스케줄 등록부'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_BATCH_SCHEDULE
  provider contract transactional_query
  as projection on ZI_BATCH_SCHEDULE
{
  key RunUuid,

      JobTemplateName,
      @Search.defaultSearchElement: true
      JobText,
      Parameters,

      @EndUserText.label: 'Job Name (SM37)'
      JobName,
      @EndUserText.label: 'Job Count (SM37)'
      JobCount,

      @EndUserText.label: 'Scheduled'
      IsScheduled,
      Message,

      CreatedBy,
      CreatedAt,
      LocalLastChangedAt
}
