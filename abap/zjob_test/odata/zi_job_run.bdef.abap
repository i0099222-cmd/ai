managed implementation in class zbp_i_job_run unique;
strict ( 2 );

// Application Job 기능을 OData 로 노출/테스트하기 위한 BO.
// 엔티티 자체는 "스케줄 이력 테이블"이고, 실제 APJ 기능은 액션으로 붙는다.
//   scheduleJob   -> CL_APJ_RT_API=>SCHEDULE_JOB
//   refreshStatus -> CL_APJ_RT_API=>GET_JOB_STATUS
//   cancelJob     -> CL_APJ_RT_API=>CANCEL_JOB
define behavior for ZI_JOB_RUN alias JobRun
persistent table ztjob_run
lock master
authorization master ( global )
etag master LocalLastChangedAt
{
  field ( numbering : managed, readonly ) RunUuid;

  field ( readonly ) JobName,
                     JobCount,
                     JobStatus,
                     ScheduledAt,
                     LastCheckedAt,
                     LastMessage,
                     CreatedBy,
                     CreatedAt,
                     LastChangedBy,
                     LocalLastChangedAt;

  field ( mandatory ) JobTemplateName, RunTag;

  create;
  update;
  delete;

  // --- Application Job 제어 액션 -----------------------------------------
  // 스케줄은 "잡을 만들고 그 결과를 새 인스턴스로 기록"하므로 factory action.
  static factory action scheduleJob parameter ZD_JOB_SCHEDULE [1];

  // 상태 폴링 / 취소. SM37 의 "Job 개요 / Job 중지" 에 대응하는 최소 기능이며,
  // SM37 에 있는 나머지 관리 기능(반복 실행, 복사, 대상 서버 이동, 스텝 편집)에는
  // 대응하는 API 가 없다는 점을 이 액션 목록이 그대로 보여준다.
  action refreshStatus result [1] $self;
  action ( features : instance ) cancelJob result [1] $self;

  // 잡이 남긴 프로브 조회용
  association _Probe;

  mapping for ztjob_run
  {
    RunUuid            = run_uuid;
    JobTemplateName    = job_template;
    JobName            = job_name;
    JobCount           = job_count;
    RunTag             = run_tag;
    RecordCount        = rec_count;
    SleepSeconds       = sleep_secs;
    ForceFail          = force_fail;
    StartImmediately   = start_immediately;
    StartDate          = start_date;
    StartTime          = start_time;
    TimeZone           = timezone;
    RecurrenceMinutes  = recurrence_minutes;
    EndDate            = end_date;
    JobStatus          = job_status;
    ScheduledAt        = scheduled_at;
    LastCheckedAt      = last_checked_at;
    LastMessage        = last_message;
    CreatedBy          = created_by;
    CreatedAt          = created_at;
    LastChangedBy      = last_changed_by;
    LocalLastChangedAt = local_last_changed_at;
  }
}
