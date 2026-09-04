@EndUserText.label: 'Application Job 스케줄 액션 파라미터'
@AccessControl.authorizationCheck: #NOT_REQUIRED
define abstract entity ZD_JOB_SCHEDULE
{
      @EndUserText.label: 'Job Template Name'
      JobTemplateName   : abap.char(60);

      // --- 잡 파라미터 (템플릿 파라미터로 전달) --------------------------
      @EndUserText.label: '테스트 태그'
      RunTag            : abap.char(20);
      MessageCount      : abap.int4;
      SleepSeconds      : abap.int4;
      ForceFail         : abap_boolean;

      // --- 스케줄 옵션 -----------------------------------------------------
      // 여기 있는 것 = APJ 가 지원하는 스케줄 옵션의 전부.
      // SM36 의 이벤트 시작 / 선행 잡 후 시작 / 대상 서버 / 잡 클래스 /
      // 팩토리캘린더 주기에는 대응 필드가 아예 없다. 그 "없음"이 비교 결과다.
      @EndUserText.label: '즉시 시작'
      StartImmediately  : abap_boolean;
      @EndUserText.label: '최초 시작일'
      StartDate         : abap.dats;
      @EndUserText.label: '최초 시작시각'
      StartTime         : abap.tims;
      @EndUserText.label: '타임존 (APJ 우위 항목)'
      TimeZone          : abap.char(6);
      @EndUserText.label: '반복 주기(분). 0 = 1회성'
      RecurrenceMinutes : abap.int4;
      @EndUserText.label: '종료일 (반복 잡)'
      EndDate           : abap.dats;
}
