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
// CL_APJ_RT_API 는 RAP 인터랙션 단계에서 호출할 수 없다(LUW 충돌).
// 액션은 엔티티에 쓰기만 하고, 그 결과가 create/update 테이블에 실려
// saver 의 save_modified 로 넘어간다. 별도 버퍼가 필요 없는 이유다.
define behavior for ZI_BATCH_SCHEDULE alias BatchSchedule
persistent table ztbatch_sched
lock master
authorization master ( global )
etag master LocalLastChangedAt
with additional save
{
  field ( numbering : managed, readonly ) RunUuid;

  // APJ 가 만들어주는 값은 사용자가 못 바꾼다
  field ( readonly ) JobName,
                     JobCount,
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

  field ( readonly ) CancelRequested;

  // --- APJ 제어 ------------------------------------------------------------
  // 잡 생성 = 스케줄 등록. 이력 행 1건 + APJ 잡 1건이 만들어진다.
  static factory action scheduleJob parameter ZD_BATCH_SCHEDULE_IN [1];

  // 스케줄 변경. APJ 에 잡 수정 API 가 없어 취소 + 재생성이며,
  // 그 결과 SM37 의 jobname/jobcount 가 바뀐다.
  action ( features : instance ) changeJob parameter ZD_BATCH_START_OPTION result [1] $self;

  // 잡만 끊는다. 이력 행은 남는다.
  action ( features : instance ) cancelJob result [1] $self;

  // APJ 에서 현재 상태를 읽어 메시지로 돌려준다.
  // GET_JOB_STATUS 는 읽기만 하므로 인터랙션 단계에서 호출해도 된다.
  action ( features : instance ) refreshStatus result [1] $self;

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
    EndOfMonth         = eof_month;
    UseWorkingDays     = use_working_days;
    StartRestriction   = start_restriction;
    JobName            = jobname;
    JobCount           = jobcount;
    CancelRequested    = cancel_requested;
    Message            = message;
    CreatedBy          = created_by;
    CreatedAt          = created_at;
    LocalLastChangedAt = local_last_changed_at;
  }
}
