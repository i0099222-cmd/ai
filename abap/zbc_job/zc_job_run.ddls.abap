@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '배치잡 스케줄 등록부'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_JOB_RUN
  provider contract transactional_query
  as projection on ZI_JOB_RUN
{
  key RunUuid,

      JobTemplateName,
      @Search.defaultSearchElement: true
      JobText,
      @Search.defaultSearchElement: true
      ExecutionClass,
      Parameters,

      @EndUserText.label: 'Job Name (SM37)'
      JobName,
      @EndUserText.label: 'Job Count (SM37)'
      JobCount,

      @EndUserText.label: 'Scheduled'
      IsScheduled,

      CreatedBy,
      CreatedAt,
      LocalLastChangedAt
}
