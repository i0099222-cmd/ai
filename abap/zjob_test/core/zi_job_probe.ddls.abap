@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '배치잡 실행 프로브 (Interface)'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZI_JOB_PROBE
  as select from ztjob_probe
{
  key probe_uuid      as ProbeUuid,

      run_tag         as RunTag,
      seq_no          as SequenceNumber,

      schedule_mode   as ScheduleMode,
      case schedule_mode
        when 'A' then 'Application Job'
        when 'C' then 'Classic (SM36)'
        else          'Unknown'
      end             as ScheduleModeText,

      job_name        as JobName,
      job_count       as JobCount,

      exec_user       as ExecutedBy,
      exec_stamp      as ExecutedAt,
      exec_date       as ExecutionDate,
      exec_time       as ExecutionTime,
      user_timezone   as UserTimeZone,
      host            as HostName,
      is_batch        as IsBackgroundRun,

      message         as Message
}
