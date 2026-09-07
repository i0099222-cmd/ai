managed implementation in class zbp_i_batch_schedule unique;
strict ( 2 );

// AS-IS 인터페이스와 1:1
//   ZBC_BATCH_JOB_CREATE -> createJob
//   ZBC_BATCH_JOB_CHANGE -> changeJob
//   ZBC_BATCH_JOB_DELETE -> cancelJob
//   ZBC_BATCH_JOB_STATUS -> refreshStatus
//
// SAP 에서 "잡 생성" 은 곧 "스케줄 등록" 이다. 둘을 분리하지 않는다.
// createJob 한 번이 DB 등록부 행 1건 + APJ 잡 1건을 만든다.
// (DB 행은 SAP 개념이 아니라 이 서비스가 관리하려고 두는 것이다)
//
// 표준 create/update 는 projection 에서 노출하지 않는다 - 스케줄 안 된
// 반쪽 행이 생기는 것을 막기 위해서다. 액션이 내부적으로만 쓴다.
// delete 는 열어둔다: 등록부 행 정리용이며 APJ 잡과 무관하다.
//
// 이 BO 는 "스케줄 등록부"다. 실행 상태와 로그는 갖지 않는다 - 별도 로그 기능 담당.
// 시작일시/반복주기/타임존은 DB 에 없다. 액션 파라미터로만 받아 APJ 에 넘긴다.
define behavior for ZI_BATCH_SCHEDULE alias BatchSchedule
persistent table ztbatch_sched
lock master
authorization master ( global )
etag master LocalLastChangedAt
// APJ 호출(SCHEDULE_JOB/CANCEL_JOB)은 인터랙션 단계에서 금지된다.
// 액션은 요청만 버퍼에 담고, 실제 호출은 saver 의 save_modified 에서 한다.
with additional save
{
  field ( numbering : managed, readonly ) RunUuid;

  // APJ 가 만들어주는 포인터는 사용자가 못 바꾼다
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

  // --- AS-IS 인터페이스 1:1 액션 -------------------------------------------
  // 잡 생성 = 스케줄 등록. 한 번의 호출로 등록부 행 + APJ 잡이 만들어진다.
  static factory action createJob parameter ZD_BATCH_CREATE [1];

  // 스케줄 변경. APJ 에 잡 수정 API 가 없어 취소 + 재생성이며,
  // 그 결과 SM37 의 jobname/jobcount 가 바뀐다.
  action ( features : instance ) changeJob parameter ZD_BATCH_START_OPTION result [1] $self;

  // 잡 취소. 등록부 행은 남고 APJ 포인터만 비워진다 (다시 걸 수 있음).
  action ( features : instance ) cancelJob result [1] $self;

  // APJ 에서 현재 상태를 읽어 메시지로 돌려준다. DB 에 쓰지 않는다.
  action ( features : instance ) refreshStatus result [1] $self;

  mapping for ztbatch_sched
  {
    RunUuid            = run_uuid;
    JobTemplateName    = template;
    JobText            = jobtext;
    Parameters         = param;
    JobName            = jobname;
    JobCount           = jobcount;
    Message            = message;
    CreatedBy          = created_by;
    CreatedAt          = created_at;
    LocalLastChangedAt = local_last_changed_at;
  }
}
