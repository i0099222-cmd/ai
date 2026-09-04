@EndUserText.label: 'scheduleJob 액션 파라미터'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define abstract entity ZD_JOB_SCHEDULE
{
      // 시작 조건과 반복 주기는 여기서만 존재한다.
      // APJ 에 넘기고 나면 APJ 가 갖고 있으므로 DB 에 저장하지 않는다.
      // 상태/스케줄 확인은 refreshStatus 로 APJ 에 물어본다.

      @EndUserText.label: '즉시 시작'
      StartImmediately : abap_boolean;
      @EndUserText.label: '시작일'
      StartDate        : abap.dats;
      @EndUserText.label: '시작시각'
      StartTime        : abap.tims;
      @EndUserText.label: '타임존 (APJ 기본 제공)'
      TimeZone         : abap.char(6);

      // 반복 주기. 하나만 채운다.
      PeriodMinutes    : abap.int4;
      PeriodHours      : abap.int4;
      @EndUserText.label: '일반복주기'
      PeriodDays       : abap.int4;
      PeriodWeeks      : abap.int4;
      PeriodMonths     : abap.int4;
}
