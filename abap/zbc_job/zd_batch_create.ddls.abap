@EndUserText.label: 'createAndSchedule 액션 파라미터'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define abstract entity ZD_BATCH_CREATE
{
      // AS-IS ZBC_BATCH_JOB_CREATE 는 "등록 + 스케줄" 을 한 번에 한다.
      // 표준 CRUD 로는 create -> scheduleJob 2회 호출이 필요하므로,
      // AS-IS 1:1 대응을 위해 두 단계를 묶은 액션의 파라미터다.

      // --- 등록 내용 (ZTBATCH_SCHED 에 저장) -----------------------------
      @EndUserText.label: 'APJ 잡 템플릿'
      JobTemplateName   : abap.char(60);
      @EndUserText.label: '잡 텍스트 (논리 잡명)'
      JobText           : abap.char(64);
      @EndUserText.label: '실행 클래스'
      ExecutionClass    : abap.char(30);
      @EndUserText.label: '파라미터 (JSON)'
      Parameters        : abap.string(0);

      // --- 스케줄 옵션 (APJ 로만 전달, 저장하지 않음) ---------------------
      @EndUserText.label: '즉시 시작'
      StartImmediately  : abap_boolean;
      @EndUserText.label: '시작일'
      StartDate         : abap.dats;
      @EndUserText.label: '시작시각'
      StartTime         : abap.tims;
      @EndUserText.label: '타임존'
      TimeZone          : abap.char(6);

      PeriodMinutes     : abap.int4;
      PeriodHours       : abap.int4;
      @EndUserText.label: '일반복주기'
      PeriodDays        : abap.int4;
      PeriodWeeks       : abap.int4;
      PeriodMonths      : abap.int4;
}
