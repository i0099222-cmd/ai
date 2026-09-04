@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '배치잡 스케줄'
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
      ProgramName,
      Parameters,

      @EndUserText.label: 'Job Name (SM37)'
      JobName,
      @EndUserText.label: 'Job Count (SM37)'
      JobCount,

      @ObjectModel.text.element: ['JobStatusText']
      JobStatus,
      JobStatusText,
      @UI.hidden: true
      JobStatusCriticality,

      Message,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LocalLastChangedAt
}
