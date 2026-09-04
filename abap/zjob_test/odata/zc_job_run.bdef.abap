projection;
strict ( 2 );

define behavior for ZC_JOB_RUN alias JobRun
{
  use create;
  use update;
  use delete;

  use action scheduleJob;
  use action refreshStatus;
  use action cancelJob;
}
