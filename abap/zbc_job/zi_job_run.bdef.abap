managed implementation in class zbp_i_job_run unique;
strict ( 2 );

// AS-IS 인터페이스 대응
//   ZBC_BATCH_JOB_CREATE  -> create + action scheduleJob
//   ZBC_BATCH_JOB_CHANGE  -> update (+ cancelJob + scheduleJob 재스케줄)
//   ZBC_BATCH_JOB_DELETE  -> action cancelJob (+ delete)
//   ZBC_BATCH_JOB_STATUS  -> action refreshStatus / 조회
//
// 액션은 전부 CL_APJ_RT_API 를 호출한다. BDC 는 없다.
//
// 시작일시/반복주기/타임존은 DB 에 없다. scheduleJob 액션 파라미터로만 받아
// APJ 에 넘긴다. 그 값들의 진실의 원천은 APJ 이므로 중복 저장하지 않는다.
define behavior for ZI_JOB_RUN alias JobRun
persistent table ztjob_run
lock master
authorization master ( global )
etag master LocalLastChangedAt
{
  field ( numbering : managed, readonly ) RunUuid;

  // APJ 가 만들어주는 값과 상태는 사용자가 못 바꾼다
  field ( readonly ) JobName,
                     JobCount,
                     JobStatus,
                     Message,
                     CreatedBy,
                     CreatedAt,
                     LastChangedBy,
                     LocalLastChangedAt;

  field ( mandatory ) JobTemplateName, JobText, ProgramName;

  create;
  update;
  delete;

  // --- APJ 제어 액션 ------------------------------------------------------
  action ( features : instance ) scheduleJob parameter ZD_JOB_SCHEDULE result [1] $self;
  action ( features : instance ) cancelJob   result [1] $self;
  action refreshStatus result [1] $self;

  mapping for ztjob_run
  {
    RunUuid            = run_uuid;
    JobTemplateName    = template;
    JobText            = jobtext;
    ProgramName        = pgmid;
    Parameters         = param;
    JobName            = jobname;
    JobCount           = jobcount;
    JobStatus          = status;
    Message            = message;
    CreatedBy          = created_by;
    CreatedAt          = created_at;
    LastChangedBy      = last_changed_by;
    LocalLastChangedAt = local_last_changed_at;
  }
}
