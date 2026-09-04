projection;
strict ( 2 );

// 표준 create/update 는 노출하지 않는다.
// 잡 생성은 createJob, 변경은 changeJob 으로만 한다 -
// 스케줄 안 된 반쪽 행이 생기는 것을 막기 위해서다.
// delete 는 등록부 행 정리용으로 열어둔다 (APJ 잡과 무관).
define behavior for ZC_BATCH_SCHEDULE alias BatchSchedule
{
  use delete;

  use action createJob;
  use action changeJob;
  use action cancelJob;
  use action refreshStatus;
}
