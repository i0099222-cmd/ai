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

      // --- 제한 조건 : 월 주기 잡에서 "그 달의 며칠에" ---------------------
      //
      // 아래 다섯은 PeriodMonths 와 짝으로 쓴다. 월 주기가 아니면 무의미하다.
      // 안 쓰면 전부 비워 보내면 되고, 그러면 시작일시의 일자가 매월 반복된다.
      //
      // 두 갈래가 답하는 질문이 다르다.
      //   MonthDay / UseWorkingDays / CountFromMonthEnd  어느 날에 돌릴까
      //   CalendarId / StartRestriction                  그날이 휴일이면 어쩔까
      //
      // 예) 매월 말일에서 3번째 작업일, 달력 01
      //     PeriodMonths=1, CalendarId='01', MonthDay=3,
      //     UseWorkingDays='X', CountFromMonthEnd='X'
      //
      // 예) 매월 15일, 휴일이면 이전 근무일로 당김
      //     PeriodMonths=1, CalendarId='01', MonthDay=15,
      //     UseWorkingDays='',  StartRestriction='B'

      // 근무일/휴일 판정의 기준 달력 (SCAL). 비우면 판정을 하지 않는다.
      // UseWorkingDays 나 StartRestriction 을 쓰려면 반드시 있어야 한다.
      @EndUserText.label: '공장달력'
      CalendarId        : abap.char(2);

      // 월중 몇 번째 날에 돌릴지. 0 이면 일자를 지정하지 않는다
      // (시작일시의 일자가 매월 반복된다).
      // UseWorkingDays 와 CountFromMonthEnd 가 이 숫자의 뜻을 바꾼다.
      //   3 + 둘 다 비움 : 매월 3일
      //   3 + 작업일     : 매월 3번째 작업일
      //   3 + 작업일+역순: 매월 말일에서 3번째 작업일
      @EndUserText.label: 'n번째 작업일 (공장근무일수)'
      MonthDay          : abap.int4;

      // MonthDay 를 달력일이 아니라 작업일로 센다. 주말·휴일을 건너뛴다.
      // CalendarId 없이 이걸 켜면 스케줄이 거부된다 - 셀 기준이 없어서다.
      // AS-IS 이관 시에는 항상 'X' 다 (공장달력을 쓰면 늘 작업일 기준이었다).
      @EndUserText.label: '작업일 기준'
      UseWorkingDays    : abap_boolean;

      // MonthDay 를 월말부터 거꾸로 센다. 비우면 월초부터.
      // 말일 자체를 지정하려면 MonthDay=1 + 이 플래그를 쓴다.
      // (AS-IS EOFMONTH / BOFMONTH 에 대응)
      @EndUserText.label: '월말부터 역순'
      CountFromMonthEnd : abap_boolean;

      // 고른 날이 근무일이 아닐 때의 처리. CalendarId 가 있어야 의미가 있다.
      //   D 그 회차를 건너뛴다 (안 돌린다)
      //   B 이전 근무일로 당긴다
      //   A 다음 근무일로 미룬다
      //   N 제한 없이 그날 그대로 실행한다
      // UseWorkingDays='X' 면 고르는 단계에서 이미 작업일만 세므로 쓸 일이 없다.
      // 비우면 APJ 기본 동작을 따른다 (AS-IS 도 이 값을 채우지 않았다).
      @EndUserText.label: '비근무일 처리'
      StartRestriction  : abap.char(1);
}
