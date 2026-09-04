@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '배치잡 스텝'
@Metadata.allowExtensions: true
define view entity ZC_JOB_STEP
  as projection on ZI_JOB_STEP
{
  key RunUuid,
  key StepUuid,

      StepNumber,

      ProgramType,
      @EndUserText.label: 'Program'
      ProgramName,
      Variant,
      Language,
      StepUser,

      ExecutionSuccess,
      ExecutionMessage,

      LastChangedBy,
      LocalLastChangedAt,

      _Run : redirected to parent ZC_JOB_RUN
}
