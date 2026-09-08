@EndUserText.label: 'changeJob 액션 파라미터'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define abstract entity ZD_BATCH_CHANGE_IN
{
      // --- 어느 잡을 --------------------------------------------------------
      // AS-IS ZBC_BATCH_JOB_CHANGE 는 jobid 로 잡을 지목한다.
      // 호출자는 RunUuid 가 아니라 SM37 잡 이름을 들고 있다.
      @EndUserText.label: '백그라운드 잡 이름 (SM37)'
      JobName           : abap.char(32);
      @EndUserText.label: '백그라운드 잡 카운트 (SM37)'
      JobCount          : abap.char(8);

      // --- 새 시작 조건 -----------------------------------------------------
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

      // --- 제한 조건 (AS-IS SM36 Restrictions) ----------------------------
      @EndUserText.label: '공장달력'
      CalendarId        : abap.char(2);
      @EndUserText.label: 'n번째 작업일 (공장근무일수)'
      MonthDay          : abap.int4;
      @EndUserText.label: '작업일 기준'
      UseWorkingDays    : abap_boolean;
      // 비우면 월초부터, 'X' 면 월말부터 거꾸로 센다
      @EndUserText.label: '월말부터 역순'
      CountFromMonthEnd : abap_boolean;
      // D=건너뜀 B=앞당김 A=미룸 N=제한없음
      @EndUserText.label: '비근무일 처리'
      StartRestriction  : abap.char(1);
}
