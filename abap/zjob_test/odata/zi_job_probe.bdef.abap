managed implementation in class zbp_i_job_probe unique;
strict ( 2 );

// 프로브는 잡이 쓰고 서비스는 읽기만 한다. 그래서 create/update/delete 없음.
// (테스트 데이터 정리용으로 delete 가 필요하면 아래 delete; 주석을 풀면 된다.)
define behavior for ZI_JOB_PROBE alias Probe
persistent table ztjob_probe
lock master
authorization master ( global )
{
  field ( readonly ) ProbeUuid,
                     RunTag,
                     SequenceNumber,
                     ScheduleMode,
                     JobName,
                     JobCount,
                     ExecutedBy,
                     ExecutedAt,
                     ExecutionDate,
                     ExecutionTime,
                     UserTimeZone,
                     HostName,
                     IsBackgroundRun,
                     Message;

  // delete;

  mapping for ztjob_probe
  {
    ProbeUuid       = probe_uuid;
    RunTag          = run_tag;
    SequenceNumber  = seq_no;
    ScheduleMode    = schedule_mode;
    JobName         = job_name;
    JobCount        = job_count;
    ExecutedBy      = exec_user;
    ExecutedAt      = exec_stamp;
    ExecutionDate   = exec_date;
    ExecutionTime   = exec_time;
    UserTimeZone    = user_timezone;
    HostName        = host;
    IsBackgroundRun = is_batch;
    Message         = message;
  }
}
