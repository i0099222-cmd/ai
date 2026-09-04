@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '배치잡 스케줄 (Interface)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{ serviceQuality: #X, sizeCategory: #S, dataClass: #MIXED }
define root view entity ZI_JOB_RUN
  as select from ztjob_run
{
  key run_uuid              as RunUuid,

      template              as JobTemplateName,
      jobtext               as JobText,
      pgmid                 as ProgramName,
      param                 as Parameters,

      jobname               as JobName,
      jobcount              as JobCount,

      status                as JobStatus,
      case status
        when 'S' then 'Scheduled'
        when 'R' then 'Running'
        when 'F' then 'Finished'
        when 'E' then 'Error'
        when 'C' then 'Cancelled'
        when 'K' then 'Skipped'
        else          'Not scheduled'
      end                   as JobStatusText,
      // Fiori criticality: 0 중립 / 1 부정 / 2 경고 / 3 긍정
      case status
        when 'F' then 3
        when 'E' then 1
        when 'C' then 2
        when 'K' then 2
        else          0
      end                   as JobStatusCriticality,

      message               as Message,

      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt
}
