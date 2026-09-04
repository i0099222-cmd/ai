@EndUserText.label: '배치잡 스케줄 서비스 (Application Job)'
define service ZUI_BC_JOB {
  expose ZC_JOB_RUN  as JobRun;
  expose ZC_JOB_STEP as Step;
}
