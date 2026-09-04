@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Application Job 스케줄 실행 로그 (Interface)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{ serviceQuality: #X, sizeCategory: #S, dataClass: #MIXED }
define root view entity ZI_JOB_RUN
  as select from ztjob_run
  // 프로브는 별도 root 엔티티로 두고 run_tag 로 연결만 한다.
  // (APJ 는 잡 이름을 자동 생성하므로 스케줄 시점에 잡 키를 알 수 없다.
  //  그래서 composition 대신 태그 기반 association 을 쓴다.)
  association [0..*] to ZI_JOB_PROBE as _Probe on $projection.RunTag = _Probe.RunTag
{
  key run_uuid                    as RunUuid,

      job_template                as JobTemplateName,
      job_name                    as JobName,
      job_count                   as JobCount,

      run_tag                     as RunTag,
      rec_count                   as RecordCount,
      sleep_secs                  as SleepSeconds,
      force_fail                  as ForceFail,

      start_immediately           as StartImmediately,
      start_date                  as StartDate,
      start_time                  as StartTime,
      timezone                    as TimeZone,
      recurrence_minutes          as RecurrenceMinutes,
      end_date                    as EndDate,

      job_status                  as JobStatus,
      case job_status
        when 'S' then 'Scheduled'
        when 'R' then 'Running'
        when 'F' then 'Finished'
        when 'E' then 'Error'
        when 'C' then 'Cancelled'
        else          'Unknown'
      end                         as JobStatusText,
      // Fiori criticality: 0 중립 / 1 부정 / 2 경고 / 3 긍정
      case job_status
        when 'F' then 3
        when 'E' then 1
        when 'C' then 2
        else          0
      end                         as JobStatusCriticality,

      scheduled_at                as ScheduledAt,
      last_checked_at             as LastCheckedAt,
      last_message                as LastMessage,

      @Semantics.user.createdBy: true
      created_by                  as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at                  as CreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      last_changed_by             as LastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at       as LocalLastChangedAt,

      _Probe
}
