@EndUserText.label: 'refreshStatus 액션 파라미터'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define abstract entity ZD_BATCH_STATUS_IN
{
      // AS-IS ZBC_BATCH_JOB_STATUS 는 jobname 으로 잡을 지목한다.
      // APJ 잡의 키는 jobname + jobcount 라 둘 다 받는다.
      @EndUserText.label: '백그라운드 잡 이름 (SM37)'
      JobName  : abap.char(32);
      @EndUserText.label: '백그라운드 잡 카운트 (SM37)'
      JobCount : abap.char(8);
}
