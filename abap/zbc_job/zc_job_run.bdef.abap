projection;
strict ( 2 );

define behavior for ZC_JOB_RUN alias JobRun
{
  use create;
  use update;
  use delete;

  use association _Step { create; }

  use action scheduleJob;
  use action cancelJob;
  use action refreshStatus;
}

define behavior for ZC_JOB_STEP alias Step
{
  use update;
  use delete;

  use association _Run;
}
