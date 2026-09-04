@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '배치잡 스텝 (Interface)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_JOB_STEP
  as select from ztjob_step
  association to parent ZI_JOB_RUN as _Run
    on $projection.RunUuid = _Run.RunUuid
{
  key run_uuid              as RunUuid,
  key step_uuid             as StepUuid,

      step_no               as StepNumber,

      pg_type               as ProgramType,
      pg_id                 as ProgramName,
      pg_variant            as Variant,
      pg_lang               as Language,
      step_user             as StepUser,

      exec_success          as ExecutionSuccess,
      exec_message          as ExecutionMessage,

      @Semantics.user.localInstanceLastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _Run
}
