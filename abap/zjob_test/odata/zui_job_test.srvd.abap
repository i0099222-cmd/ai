@EndUserText.label: 'Application Job / SM36 비교 테스트 서비스'
define service ZUI_JOB_TEST {
  expose ZC_JOB_RUN   as JobRun;
  expose ZC_JOB_PROBE as Probe;
}
