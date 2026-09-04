managed implementation in class zbp_i_job_run unique;
strict ( 2 );

// AS-IS 인터페이스 대응
//   ZBC_BATCH_JOB_CREATE  -> create (+ 스텝 deep create) + action scheduleJob
//   ZBC_BATCH_JOB_CHANGE  -> update (+ 재스케줄)
//   ZBC_BATCH_JOB_DELETE  -> action cancelJob (+ delete)
//   ZBC_BATCH_JOB_STATUS  -> action refreshStatus / 조회
//
// 액션은 전부 CL_APJ_RT_API 를 호출한다. BDC 는 없다.
define behavior for ZI_JOB_RUN alias JobRun
persistent table ztjob_run
lock master
authorization master ( global )
etag master LocalLastChangedAt
{
  field ( numbering : managed, readonly ) RunUuid;

  // APJ 가 만들어주는 값과 상태는 사용자가 못 바꾼다
  field ( readonly ) JobTemplateName,
                     JobName,
                     JobCount,
                     JobStatus,
                     ScheduledAt,
                     LastCheckedAt,
                     LastMessage,
                     CreatedBy,
                     CreatedAt,
                     LastChangedBy,
                     LocalLastChangedAt,
                     LastChangedAt;

  field ( mandatory ) JobLabel;

  create;
  update;
  delete;

  association _Step { create; }

  // --- APJ 제어 액션 ------------------------------------------------------
  action ( features : instance ) scheduleJob parameter ZD_JOB_SCHEDULE result [1] $self;
  action ( features : instance ) cancelJob   result [1] $self;
  action refreshStatus result [1] $self;

  // 스케줄 전 검증. BDC 화면이 걸러주던 것을 코드로 대신한다.
  validation validateSchedule on save { create; update; }

  mapping for ztjob_run
  {
    RunUuid            = run_uuid;
    SystemId           = sys_id;
    TargetClient       = target_client;
    BusinessArea       = biz_area;
    RequesterId        = req_id;
    RequesterName      = req_name;
    RequestedAt        = req_datetime;
    RequestReason      = req_reason;
    JobLabel           = job_label;
    JobClass           = job_class;
    JobUser            = job_user;
    StartImmediately   = start_immediately;
    StartDate          = start_date;
    StartTime          = start_time;
    TimeZone           = timezone;
    PeriodMinutes      = prd_mins;
    PeriodHours        = prd_hours;
    PeriodDays         = prd_days;
    PeriodWeeks        = prd_weeks;
    PeriodMonths       = prd_months;
    LastStartDate      = last_start_date;
    LastStartTime      = last_start_time;
    CalendarId         = calendar_id;
    WorkdayNumber      = workday_nr;
    WorkdayTime        = workday_time;
    JobTemplateName    = job_template;
    JobName            = job_name;
    JobCount           = job_count;
    JobStatus          = job_status;
    ScheduledAt        = scheduled_at;
    LastCheckedAt      = last_checked_at;
    LastMessage        = last_message;
    CreatedBy          = created_by;
    CreatedAt          = created_at;
    LastChangedBy      = last_changed_by;
    LocalLastChangedAt = local_last_changed_at;
    LastChangedAt      = last_changed_at;
  }
}


define behavior for ZI_JOB_STEP alias Step
persistent table ztjob_step
lock dependent by _Run
authorization dependent by _Run
{
  field ( numbering : managed, readonly ) StepUuid;
  field ( readonly ) RunUuid, ExecutionSuccess, ExecutionMessage,
                     LastChangedBy, LocalLastChangedAt;

  field ( mandatory ) ProgramName;

  update;
  delete;

  association _Run;

  mapping for ztjob_step
  {
    RunUuid            = run_uuid;
    StepUuid           = step_uuid;
    StepNumber         = step_no;
    ProgramType        = pg_type;
    ProgramName        = pg_id;
    Variant            = pg_variant;
    Language           = pg_lang;
    StepUser           = step_user;
    ExecutionSuccess   = exec_success;
    ExecutionMessage   = exec_message;
    LastChangedBy      = last_changed_by;
    LocalLastChangedAt = local_last_changed_at;
  }
}
