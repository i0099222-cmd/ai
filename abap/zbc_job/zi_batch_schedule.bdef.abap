managed implementation in class zbp_i_batch_schedule unique;
strict ( 2 );

// AS-IS 인터페이스 대응
//   ZBC_BATCH_JOB_CREATE  -> action createAndSchedule  (등록 + 스케줄 한 번에)
//   ZBC_BATCH_JOB_CHANGE  -> update + action rescheduleJob
//   ZBC_BATCH_JOB_DELETE  -> action cancelJob (+ delete)
//   ZBC_BATCH_JOB_STATUS  -> action refreshStatus (APJ 에서 읽어 메시지로 반환)
//
// 표준 CRUD(create/update/delete)도 그대로 열어둔다. Fiori Elements 는 이쪽을
// 기대하고, 액션은 AS-IS 인터페이스와 1:1 로 맞추기 위한 것이다.
//
// 이 BO 는 "스케줄 등록부"다. 실행 상태와 로그는 갖지 않는다 - 별도 로그 기능 담당.
// 시작일시/반복주기/타임존도 DB 에 없다. scheduleJob 액션 파라미터로만 받아
// APJ 에 넘긴다.
define behavior for ZI_BATCH_SCHEDULE alias BatchSchedule
persistent table ztbatch_sched
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

  // --- AS-IS 인터페이스 1:1 대응 액션 --------------------------------------
  // 등록 + 스케줄을 한 번에. AS-IS ZBC_BATCH_JOB_CREATE 대응.
  static factory action createAndSchedule parameter ZD_BATCH_CREATE [1];

  // --- APJ 제어 액션 ------------------------------------------------------
  // 이미 등록된 행을 스케줄한다 (표준 create 로 만든 경우).
  action ( features : instance ) scheduleJob parameter ZD_BATCH_START_OPTION result [1] $self;
  // 취소 후 다시 건다. AS-IS ZBC_BATCH_JOB_CHANGE 의 재스케줄 부분.
  action ( features : instance ) rescheduleJob parameter ZD_BATCH_START_OPTION result [1] $self;
  action ( features : instance ) cancelJob   result [1] $self;
  action ( features : instance ) refreshStatus result [1] $self;

  mapping for ztbatch_sched
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
