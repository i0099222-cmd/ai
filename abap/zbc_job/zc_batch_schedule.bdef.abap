projection;
strict ( 2 );

define behavior for ZC_BATCH_SCHEDULE alias BatchSchedule
{
  use create;
  use update;
  use delete;

  use action createAndSchedule;
  use action scheduleJob;
  use action rescheduleJob;
  use action cancelJob;
  use action refreshStatus;
}
