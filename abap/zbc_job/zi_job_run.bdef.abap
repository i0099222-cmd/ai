managed implementation in class zbp_i_job_run unique;
strict ( 2 );

// AS-IS 인터페이스 대응
//   ZBC_BATCH_JOB_CREATE  -> create + action scheduleJob
//   ZBC_BATCH_JOB_CHANGE  -> update (+ cancelJob + scheduleJob 재스케줄)
//   ZBC_BATCH_JOB_DELETE  -> action cancelJob (+ delete)
//   ZBC_BATCH_JOB_STATUS  -> action refreshStatus (APJ 에서 읽어 메시지로 반환)
//
// 이 BO 는 "스케줄 등록부"다. 실행 상태와 로그는 갖지 않는다 - 별도 로그 기능 담당.
// 시작일시/반복주기/타임존도 DB 에 없다. scheduleJob 액션 파라미터로만 받아
// APJ 에 넘긴다.
define behavior for ZI_JOB_RUN alias JobRun
persistent table ztjob_run
lock master
authorization master ( global )
etag master LocalLastChangedAt
{
  field ( numbering : managed, readonly ) RunUuid;

  // APJ 가 만들어주는 포인터는 사용자가 못 바꾼다
  field ( readonly ) JobName,
                     JobCount,
                     IsScheduled,
                     CreatedBy,
                     CreatedAt,
                     LocalLastChangedAt;

  field ( mandatory ) JobTemplateName, JobText, ExecutionClass;

  create;
  update;
  delete;

  // --- APJ 제어 액션 ------------------------------------------------------
  action ( features : instance ) scheduleJob parameter ZD_JOB_SCHEDULE result [1] $self;
  action ( features : instance ) cancelJob   result [1] $self;
  action ( features : instance ) refreshStatus result [1] $self;

  mapping for ztjob_run
  {
    RunUuid            = run_uuid;
    JobTemplateName    = template;
    JobText            = jobtext;
    ExecutionClass     = exec_class;
    Parameters         = param;
    JobName            = jobname;
    JobCount           = jobcount;
    CreatedBy          = created_by;
    CreatedAt          = created_at;
    LocalLastChangedAt = local_last_changed_at;
  }
}
