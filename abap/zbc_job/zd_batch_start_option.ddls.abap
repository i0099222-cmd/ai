@EndUserText.label: 'changeJob 액션 파라미터 (새 시작 조건)'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define abstract entity ZD_BATCH_START_OPTION
{
      @EndUserText.label: '즉시 시작'
      StartImmediately  : abap_boolean;
      // AS-IS 인터페이스 형식 그대로 CHAR(15)(날짜+시각). 예: '20261001020000'
      @EndUserText.label: '시작 일시'
      StartDateTime     : abap.char(15);
      @EndUserText.label: '타임존'
      TimeZone          : abap.char(6);

      // 반복 주기. 하나만 채운다.
      PeriodMinutes     : abap.int4;
      PeriodHours       : abap.int4;
      @EndUserText.label: '일반복주기'
      PeriodDays        : abap.int4;
      PeriodWeeks       : abap.int4;
      @EndUserText.label: '반복주기'
      PeriodMonths      : abap.int4;

      // 종료 일시 - AS-IS 배치잡 close시간. 같은 CHAR(15) 형식.
      @EndUserText.label: '종료 일시 (close)'
      EndDateTime       : abap.char(15);
}
