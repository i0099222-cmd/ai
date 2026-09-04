@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '배치잡 실행 프로브 (Projection)'
@Metadata.allowExtensions: true
define root view entity ZC_JOB_PROBE
  provider contract transactional_query
  as projection on ZI_JOB_PROBE
{
  key ProbeUuid,

      @Search.defaultSearchElement: true
      RunTag,
      SequenceNumber,

      @ObjectModel.text.element: ['ScheduleModeText']
      ScheduleMode,
      ScheduleModeText,
      JobName,
      JobCount,

      ExecutedBy,
      ExecutedAt,
      ExecutionDate,
      ExecutionTime,
      UserTimeZone,
      HostName,
      IsBackgroundRun,

      Message
}
