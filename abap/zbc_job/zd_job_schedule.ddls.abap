@EndUserText.label: 'scheduleJob 액션 파라미터'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define abstract entity ZD_JOB_SCHEDULE
{
      @EndUserText.label: 'APJ 잡 템플릿 이름'
      JobTemplateName : abap.char(60);
}
