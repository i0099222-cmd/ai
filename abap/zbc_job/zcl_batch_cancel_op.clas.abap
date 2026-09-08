"! <p class="shorttext synchronized">APJ 잡 취소 (bgPF 오퍼레이션)</p>
"!
"! CL_APJ_RT_API=>CANCEL_JOB 은 내부에서 COMMIT CONNECTION 을 한다.
"! RAP 은 BO 가 활성인 동안 커밋을 금지하므로 - 인터랙션 단계든 save
"! 단계든 - 그 안에서는 호출할 수 없다. 덤프 원문:
"!
"!   "Execution took place in a transactional context: a BO implementation
"!    is active. Statement COMMIT CONNECTION is therefore forbidden."
"!
"! 그래서 취소만 bgPF 로 뺀다. saver 는 큐에 넣기만 하고(커밋 없음),
"! RAP 트랜잭션이 닫힌 뒤 이 클래스가 별도 LUW 에서 실행된다.
"!
"! SCHEDULE_JOB 은 커밋을 하지 않아 saver 에서 그대로 호출한다.
CLASS zcl_batch_cancel_op DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    " TODO: 시그니처 확인 - 오퍼레이션 인터페이스 이름.
    "       IF_BGMC_OP_SINGLE_TX_UNCONTROLLED 는 "오퍼레이션이 자기
    "       트랜잭션을 직접 제어한다" 는 뜻이라 CANCEL_JOB 에 맞는다.
    INTERFACES if_bgmc_op_single_tx_uncontrolled.

    METHODS constructor
      IMPORTING
        iv_run_uuid  TYPE ztbatch_sched-run_uuid
        iv_job_name  TYPE ztbatch_sched-jobname
        iv_job_count TYPE ztbatch_sched-jobcount.

  PRIVATE SECTION.

    DATA mv_run_uuid  TYPE ztbatch_sched-run_uuid.
    DATA mv_job_name  TYPE ztbatch_sched-jobname.
    DATA mv_job_count TYPE ztbatch_sched-jobcount.

ENDCLASS.


CLASS zcl_batch_cancel_op IMPLEMENTATION.

  METHOD constructor.
    mv_run_uuid  = iv_run_uuid.
    mv_job_name  = iv_job_name.
    mv_job_count = iv_job_count.
  ENDMETHOD.


  METHOD if_bgmc_op_single_tx_uncontrolled~execute.

*   여기는 RAP 트랜잭션 밖이다. CANCEL_JOB 이 커밋을 해도 문제없다.
    DATA(lv_message) = NEW zcl_batch_apj_adapter( )->cancel(
                         iv_job_name  = mv_job_name
                         iv_job_count = mv_job_count ).

*   DB 는 saver 가 이미 갱신했다(포인터를 비웠다). 여기서는 APJ 응답만
*   덧쓴다. 취소가 실패하면 DB 는 끊긴 것으로 보이는데 잡은 살아 있으므로,
*   그 사실이 MESSAGE 에 남아야 한다.
    UPDATE ztbatch_sched
      SET message = @( CONV ztbatch_sched-message( lv_message ) )
      WHERE run_uuid = @mv_run_uuid.

    COMMIT WORK.

  ENDMETHOD.

ENDCLASS.
