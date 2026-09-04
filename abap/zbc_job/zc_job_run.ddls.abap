@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '배치잡 스케줄'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_JOB_RUN
  provider contract transactional_query
  as projection on ZI_JOB_RUN
{
  key RunUuid,

      ProgramType,
      @Search.defaultSearchElement: true
      @EndUserText.label: 'Program'
      ProgramName,
      Variant,
      Language,

      SystemId,
      TargetClient,
      BusinessArea,

      RequesterId,
      RequesterName,
      RequestedAt,
      RequestReason,

      @Search.defaultSearchElement: true
      JobLabel,
      JobClass,
      JobUser,

      StartImmediately,
      StartDate,
      StartTime,
      TimeZone,

      PeriodMinutes,
      PeriodHours,
      PeriodDays,
      PeriodWeeks,
      PeriodMonths,

      LastStartDate,
      LastStartTime,
      CalendarId,
      WorkdayNumber,
      WorkdayTime,

      JobTemplateName,
      @EndUserText.label: 'Job Name (SM37)'
      JobName,
      @EndUserText.label: 'Job Count (SM37)'
      JobCount,

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
      LastChangedAt
}
