managed implementation in class zbp_i_batch_schedule unique;
strict ( 2 );

// AS-IS 인터페이스와 표준 CRUD 가 1:1 이다. 별도 액션이 필요 없다.
//   ZBC_BATCH_JOB_CREATE -> POST   (create)  -> SCHEDULE_JOB
//   ZBC_BATCH_JOB_CHANGE -> PATCH  (update)  -> CANCEL_JOB + SCHEDULE_JOB
//   ZBC_BATCH_JOB_DELETE -> DELETE (delete)  -> CANCEL_JOB
//   ZBC_BATCH_JOB_STATUS -> action refreshStatus
//
// SAP 에서 "잡 생성" 은 곧 "스케줄 등록" 이다. create 한 번이 등록부 행 1건과
// APJ 잡 1건을 만든다.
//
// CL_APJ_RT_API 는 RAP 인터랙션 단계에서 호출할 수 없다(LUW 충돌).
// with additional save 를 걸고 saver 의 save_modified 에서만 호출한다.
// 시작 조건이 전부 엔티티 필드라 create/update 를 그대로 읽으면 되고,
// 인터랙션 -> save 로 값을 넘기는 버퍼가 필요 없다.
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

  create;
  update;
  delete;

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
    StartDate          = start_date;
    StartTime          = start_time;
    TimeZone           = timezone;
    PeriodMinutes      = prd_mins;
    PeriodHours        = prd_hours;
    PeriodDays         = prd_days;
    PeriodWeeks        = prd_weeks;
    PeriodMonths       = prd_months;
    JobName            = jobname;
    JobCount           = jobcount;
    Message            = message;
    CreatedBy          = created_by;
    CreatedAt          = created_at;
    LocalLastChangedAt = local_last_changed_at;
  }
}
