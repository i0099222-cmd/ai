@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '배치잡 스케줄 (Interface)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{ serviceQuality: #X, sizeCategory: #S, dataClass: #MIXED }
define root view entity ZI_JOB_RUN
  as select from ztjob_run
{
  key run_uuid              as RunUuid,

      // --- 실행 대상 ---
      pg_type               as ProgramType,
      pg_id                 as ProgramName,
      pg_variant            as Variant,
      pg_lang               as Language,

      sys_id                as SystemId,
      target_client         as TargetClient,
      biz_area              as BusinessArea,

      req_id                as RequesterId,
      req_name              as RequesterName,
      req_datetime          as RequestedAt,
      req_reason            as RequestReason,

      job_label             as JobLabel,
      job_class             as JobClass,
      job_user              as JobUser,

      start_immediately     as StartImmediately,
      start_date            as StartDate,
      start_time            as StartTime,
      timezone              as TimeZone,

      prd_mins              as PeriodMinutes,
      prd_hours             as PeriodHours,
      prd_days              as PeriodDays,
      prd_weeks             as PeriodWeeks,
      prd_months            as PeriodMonths,

      last_start_date       as LastStartDate,
      last_start_time       as LastStartTime,
      calendar_id           as CalendarId,
      workday_nr            as WorkdayNumber,
      workday_time          as WorkdayTime,

      job_template          as JobTemplateName,
      job_name              as JobName,
      job_count             as JobCount,

      job_status            as JobStatus,
      case job_status
        when 'S' then 'Scheduled'
        when 'R' then 'Running'
        when 'F' then 'Finished'
        when 'E' then 'Error'
        when 'C' then 'Cancelled'
        when 'K' then 'Skipped'
        else          'Not scheduled'
      end                   as JobStatusText,
      // Fiori criticality: 0 중립 / 1 부정 / 2 경고 / 3 긍정
      case job_status
        when 'F' then 3
        when 'E' then 1
        when 'C' then 2
        when 'K' then 2
        else          0
      end                   as JobStatusCriticality,

      scheduled_at          as ScheduledAt,
      last_checked_at       as LastCheckedAt,
      last_message          as LastMessage,

      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt
}
