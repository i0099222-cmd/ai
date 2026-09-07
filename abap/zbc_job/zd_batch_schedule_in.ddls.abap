@EndUserText.label: 'scheduleJob 액션 파라미터'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define abstract entity ZD_BATCH_SCHEDULE_IN
{
      // --- 무엇을 돌릴 것인가 ---------------------------------------------
      @EndUserText.label: 'APJ 잡 템플릿'
      JobTemplateName   : abap.char(60);
      @EndUserText.label: '잡 텍스트 (논리 잡명)'
      JobText           : abap.char(64);
      @EndUserText.label: '잡 파라미터 값 (JSON)'
      Parameters        : abap.string(0);

      // --- 언제 돌릴 것인가 -----------------------------------------------
      @EndUserText.label: '즉시 시작'
      StartImmediately  : abap_boolean;
      @EndUserText.label: '시작일'
      StartDate         : abap.dats;
      @EndUserText.label: '시작시각'
      StartTime         : abap.tims;
      @EndUserText.label: '타임존'
      TimeZone          : abap.char(6);

      // 반복 주기. 하나만 채운다.
      PeriodMinutes     : abap.int4;
      PeriodHours       : abap.int4;
      @EndUserText.label: '일반복주기'
      PeriodDays        : abap.int4;
      PeriodWeeks       : abap.int4;
      PeriodMonths      : abap.int4;
}
