@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '배치잡 스케줄 등록부 (Interface)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{ serviceQuality: #X, sizeCategory: #S, dataClass: #MIXED }
define root view entity ZI_BATCH_SCHEDULE
  as select from ztbatch_sched
{
  key run_uuid              as RunUuid,

      template              as JobTemplateName,
      jobtext               as JobText,
      param                 as Parameters,

      start_immediately     as StartImmediately,
      start_datetime        as StartDateTime,
      timezone              as TimeZone,

      prd_mins              as PeriodMinutes,
      prd_hours             as PeriodHours,
      prd_days              as PeriodDays,
      prd_weeks             as PeriodWeeks,
      prd_months            as PeriodMonths,

      end_datetime          as EndDateTime,

      calendar_id           as CalendarId,
      month_day             as MonthDay,
      use_working_days      as UseWorkingDays,
      count_from_end        as CountFromMonthEnd,
      start_restriction     as StartRestriction,

      jobname               as JobName,
      jobcount              as JobCount,

      is_canceled           as IsCanceled,

      // 두 가지가 다른 질문이라 필드도 둘이다.
      //   IsScheduled : 스케줄이 성공했나  (실패하면 jobname 이 빈다)
      //   IsCanceled  : 그 잡이 아직 살아 있나
      // 실제 실행 상태(Running/Finished)는 refreshStatus 가 APJ 에서 읽고,
      // 로그는 별도 로그 기능이 담당한다.
      case when jobname <> '' then 'X' else '' end as IsScheduled,

      message               as Message,

      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt
}
