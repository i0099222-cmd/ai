managed implementation in class zbp_i_batch_schedule unique;
strict ( 2 );

// 이 BO 의 엔티티는 "스케줄 이력" 이다. 조회가 목적이고,
// APJ 잡에 대한 조작은 CRUD 가 아니라 명령이므로 액션으로 노출한다.
//   ZBC_BATCH_JOB_CREATE -> action scheduleJob
//   ZBC_BATCH_JOB_CHANGE -> action changeJob
//   ZBC_BATCH_JOB_DELETE -> action cancelJob
//   ZBC_BATCH_JOB_STATUS -> action refreshStatus
//
// 표준 create/update/delete 는 projection 에서 노출하지 않는다.
// 열어두면 이력 한 줄 고쳤다고 잡이 재스케줄되거나, 잡을 끊으려다
// 이력이 사라진다. 액션 핸들러가 내부적으로만 쓴다.
//
// ** 액션 4개가 전부 정적 액션인 이유 **
//   외부 호출자는 RunUuid 를 모른다. AS-IS 인터페이스가 jobid/jobcount 로
//   잡을 지목하고, 호출하는 쪽은 그 둘을 자기 DB 에 들고 있기 때문이다.
//   그래서 잡 이름을 파라미터로 받아 이력 행을 찾는다.
//
// CL_APJ_RT_API 는 RAP 인터랙션 단계에서 호출할 수 없다(LUW 충돌).
// 액션은 엔티티에 쓰기만 하고, 그 결과가 create/update 테이블에 실려
// saver 의 save_modified 로 넘어간다. 별도 버퍼가 필요 없는 이유다.
//
// ** APJ 호출은 자식 세션에서 한다 **
//   CANCEL_JOB 이 내부에서 COMMIT CONNECTION 을 하는데, RAP 은 BO 가
//   활성인 동안 커밋을 금지한다 - 액션 핸들러도 save 단계도 마찬가지다.
//   그래서 APJ 호출만 CL_ABAP_PARALLEL 로 자식 세션에 넘기고 결과를
//   기다린다. 자식은 자기 LUW 라 커밋이 합법이다.
//
//   덕분에 저장은 평범한 managed 다. 액션이 인터랙션 단계에서 이미
//   jobname 을 알고 있으므로 그냥 엔티티에 써 두면 런타임이 저장한다.
define behavior for ZI_BATCH_SCHEDULE alias BatchSchedule
persistent table ztbatch_sched
lock master
authorization master ( global )
etag master LocalLastChangedAt
{
  field ( numbering : managed, readonly ) RunUuid;

  // APJ 가 만들어주는 값은 사용자가 못 바꾼다
  field ( readonly ) JobName,
                     JobCount,
                     EndedAt,
                     IsScheduled,
                     Message,
                     CreatedBy,
                     CreatedAt,
                     LocalLastChangedAt;

  field ( mandatory ) JobTemplateName, JobText;

  // 액션 핸들러가 내부적으로만 쓴다. projection 에서는 노출하지 않는다.
  create;
  update;
  delete;

  // --- APJ 제어 ------------------------------------------------------------
  // 잡 생성 = 스케줄 등록. 이력 행 1건 + APJ 잡 1건이 만들어진다.
  //   result 로 만들어진 행을 돌려준다. JobName 까지 실려 나간다.
  //
  //   factory 를 붙이지 않는다. factory 액션은 생성된 인스턴스를 mapped 로
  //   내보내는 것이 계약이라 result 를 같이 선언할 수 없다. 행 생성은
  //   핸들러의 MODIFY CREATE 가 하므로 factory 없이도 그대로 만들어지고,
  //   네 액션의 모양이 같아진다.
  static action scheduleJob parameter ZD_BATCH_SCHEDULE_IN [1] result [1] $self;

  // 스케줄 변경. APJ 에 잡 수정 API 가 없어 취소 + 재생성이며,
  // 그 결과 SM37 의 jobname/jobcount 가 바뀐다.
  static action changeJob parameter ZD_BATCH_CHANGE_IN [1] result [1] $self;

  // 잡만 끊는다. 이력 행은 남는다.
  //
  //   AS-IS ZBC_BATCH_JOB_DELETE 와 같은 모양으로 정적 액션이다.
  //   호출자(외부 API)는 RunUuid 가 아니라 SM37 잡 이름을 들고 있어서,
  //   인스턴스 액션이면 주소를 잡을 수 없다.
  static action cancelJob parameter ZD_BATCH_CANCEL_IN [1] result [1] $self;

  // APJ 에서 현재 상태를 읽어 메시지로 돌려준다.
  // GET_JOB_STATUS 는 읽기만 하므로 인터랙션 단계에서 호출해도 된다.
  static action refreshStatus parameter ZD_BATCH_STATUS_IN [1] result [1] $self;

  mapping for ztbatch_sched
  {
    RunUuid            = run_uuid;
    JobTemplateName    = template;
    JobText            = jobtext;
    Parameters         = param;
    StartImmediately   = start_immediately;
    StartDateTime      = start_datetime;
    TimeZone           = timezone;
    PeriodMinutes      = prd_mins;
    PeriodHours        = prd_hours;
    PeriodDays         = prd_days;
    PeriodWeeks        = prd_weeks;
    PeriodMonths       = prd_months;
    EndDateTime        = end_datetime;
    CalendarId         = calendar_id;
    MonthDay           = month_day;
    UseWorkingDays     = use_working_days;
    CountFromMonthEnd  = count_from_end;
    StartRestriction   = start_restriction;
    EndedAt            = ended_at;
    JobName            = jobname;
    JobCount           = jobcount;
    Message            = message;
    CreatedBy          = created_by;
    CreatedAt          = created_at;
    LocalLastChangedAt = local_last_changed_at;
  }
}
