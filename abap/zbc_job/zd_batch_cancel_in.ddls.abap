@EndUserText.label: 'cancelJob 액션 파라미터'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define abstract entity ZD_BATCH_CANCEL_IN
{
      // AS-IS ZBC_BATCH_JOB_DELETE 는 jobid / jobcount 로 잡을 지목한다.
      // 호출자는 RunUuid 를 모르고 SM37 잡 이름을 들고 있으므로,
      // 이 둘로 이력 행을 찾아 취소한다.
      @EndUserText.label: '백그라운드 잡 이름 (SM37)'
      JobName  : abap.char(32);
      @EndUserText.label: '백그라운드 잡 카운트 (SM37)'
      JobCount : abap.char(8);
}
