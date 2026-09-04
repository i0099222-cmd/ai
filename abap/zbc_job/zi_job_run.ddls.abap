@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '배치잡 스케줄 등록부 (Interface)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType:{ serviceQuality: #X, sizeCategory: #S, dataClass: #MIXED }
define root view entity ZI_JOB_RUN
  as select from ztjob_run
{
  key run_uuid              as RunUuid,

      template              as JobTemplateName,
      jobtext               as JobText,
      exec_class            as ExecutionClass,
      param                 as Parameters,

      jobname               as JobName,
      jobcount              as JobCount,

      // 스케줄 여부는 잡 이름 유무로 판단한다. 상태 컬럼을 두지 않는다.
      // 실제 실행 상태는 별도 로그 기능 / refreshStatus 액션이 APJ 에서 읽는다.
      case when jobname <> '' then 'X' else '' end as IsScheduled,

      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt
}
