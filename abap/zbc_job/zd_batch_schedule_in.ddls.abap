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

      // --- 월 주기 잡에서 "그 달의 며칠에" ---------------------------------
      // 안 쓰면 다 비운다. PeriodMonths 와 짝으로 쓴다.
      // 예) 매월 말일에서 3번째 작업일
      //     PeriodMonths=1 CalendarId='01' MonthDay=3
      //     UseWorkingDays='X' CountFromMonthEnd='X'

      // 근무일 판정 기준 달력. 아래 UseWorkingDays / StartRestriction 에 필수
      @EndUserText.label: '공장달력'
      CalendarId        : abap.char(2);

      // 월중 며칠째. 0 이면 시작일시의 일자가 매월 반복
      @EndUserText.label: '월중 실행일'
      MonthDay          : abap.int4;

      // MonthDay 를 작업일로 센다 (주말·휴일 건너뜀)
      @EndUserText.label: '작업일 기준'
      UseWorkingDays    : abap_boolean;

      // MonthDay 를 월말부터 거꾸로 센다. 말일 = MonthDay 1 + 이 플래그
      @EndUserText.label: '월말부터 역순'
      CountFromMonthEnd : abap_boolean;

      // 휴일에 걸리면: D 건너뜀 / B 앞당김 / A 미룸 / N 그냥 실행
      @EndUserText.label: '비근무일 처리'
      StartRestriction  : abap.char(1);
}
