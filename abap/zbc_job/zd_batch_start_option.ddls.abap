@EndUserText.label: 'changeJob 액션 파라미터 (새 시작 조건)'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define abstract entity ZD_BATCH_START_OPTION
{
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

      // 종료 조건 - AS-IS 배치잡 close시간
      @EndUserText.label: '종료일 (close)'
      EndDate           : abap.dats;
      @EndUserText.label: '종료시각 (close)'
      EndTime           : abap.tims;
}
