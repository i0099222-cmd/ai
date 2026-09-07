projection;
strict ( 2 );

// 엔티티는 조회 전용이다. 표준 CRUD 를 노출하지 않는다 -
// 이력 한 줄 고쳤다고 잡이 재스케줄되거나, 잡을 끊으려다 이력이
// 사라지는 일을 막기 위해서다. APJ 조작은 전부 액션으로만 한다.
define behavior for ZC_BATCH_SCHEDULE alias BatchSchedule
{
  use action scheduleJob;
  use action changeJob;
  use action cancelJob;
  use action refreshStatus;
}
