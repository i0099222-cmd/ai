@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Application Job 스케줄 실행 로그 (Projection)'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_JOB_RUN
  provider contract transactional_query
  as projection on ZI_JOB_RUN
{
  key RunUuid,

      @EndUserText.label: 'Job Template'
      JobTemplateName,
      @EndUserText.label: 'Job Name (SM37)'
      JobName,
      @EndUserText.label: 'Job Count (SM37)'
      JobCount,

      @Search.defaultSearchElement: true
      RunTag,
      MessageCount,
      SleepSeconds,
      ForceFail,

      StartImmediately,
      StartDate,
      StartTime,
      TimeZone,
      RecurrenceMinutes,
      EndDate,

      @ObjectModel.text.element: ['JobStatusText']
      JobStatus,
      JobStatusText,
      @UI.hidden: true
      JobStatusCriticality,

      ScheduledAt,
      LastCheckedAt,
      LastMessage,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt : LocalLastChangedAt
}
