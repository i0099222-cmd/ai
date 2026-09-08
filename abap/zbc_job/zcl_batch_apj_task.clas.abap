"! <p class="shorttext synchronized">APJ 호출 작업 (별도 세션에서 실행)</p>
"!
"! CL_APJ_RT_API=>CANCEL_JOB 은 내부에서 COMMIT CONNECTION 을 한다.
"! RAP 은 BO 가 활성인 동안 커밋을 금지하므로 - 인터랙션 단계든 save
"! 단계든 - BO 안에서는 호출할 수 없다. 덤프 원문:
"!
"!   "Execution took place in a transactional context: a BO implementation
"!    is active. Statement COMMIT CONNECTION is therefore forbidden."
"!
"! 그래서 APJ 호출을 CL_ABAP_PARALLEL 로 자식 세션에 넘긴다.
"! 자식은 자기 LUW 라 커밋이 합법이고, 부모는 결과를 기다렸다가 받는다.
"! 동기라서 액션 응답에 JOBNAME 을 실을 수 있다 - AS-IS RFC 와 같은 모양이다.
"!
"! 입력과 출력이 같은 인스턴스에 실린다. RUN_INST 가 인스턴스를 직렬화해
"! 자식으로 보내고, DO( ) 가 채운 것을 다시 돌려주기 때문이다.
"! RUN_UUID 를 같이 실어 두면 결과를 순서에 기대지 않고 짝지을 수 있다.
CLASS zcl_batch_apj_task DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    " TODO: 시그니처 확인 - IF_ABAP_PARALLEL~DO 의 파라미터명/타입
    INTERFACES if_abap_parallel.

    "! 무엇을 할지. 취소와 스케줄을 한 인스턴스에서 이어서 한다.
    "! changeJob 은 취소 + 재생성이라 왕복을 한 번으로 줄인다.
    CONSTANTS:
      BEGIN OF gc_mode,
        schedule TYPE c LENGTH 1 VALUE 'S',
        cancel   TYPE c LENGTH 1 VALUE 'C',
        change   TYPE c LENGTH 1 VALUE 'X',
      END OF gc_mode.

    " --- 짝짓기용 -----------------------------------------------------
    DATA run_uuid TYPE ztbatch_sched-run_uuid READ-ONLY.
    DATA cid      TYPE abp_behv_cid           READ-ONLY.

    " --- 무엇을 돌리는 잡인가 (changeJob 이 새 행을 만들 때 그대로 쓴다) ---
    DATA template TYPE ztbatch_sched-template READ-ONLY.
    DATA jobtext  TYPE ztbatch_sched-jobtext  READ-ONLY.
    DATA param    TYPE string                 READ-ONLY.

    " --- 취소한 잡 (changeJob 이 옛 행을 닫을 때 쓴다) -------------------
    DATA old_name  TYPE ztbatch_sched-jobname  READ-ONLY.
    DATA old_count TYPE ztbatch_sched-jobcount READ-ONLY.

    " --- 결과 ---------------------------------------------------------
    DATA job_name  TYPE ztbatch_sched-jobname  READ-ONLY.
    DATA job_count TYPE ztbatch_sched-jobcount READ-ONLY.
    DATA message   TYPE string                 READ-ONLY.

    METHODS constructor
      IMPORTING
        iv_mode      TYPE c
        iv_run_uuid  TYPE ztbatch_sched-run_uuid OPTIONAL
        iv_cid       TYPE abp_behv_cid           OPTIONAL
        "! 취소할 잡 (CANCEL / CHANGE)
        iv_old_name  TYPE ztbatch_sched-jobname  OPTIONAL
        iv_old_count TYPE ztbatch_sched-jobcount OPTIONAL
        "! 걸 잡 (SCHEDULE / CHANGE)
        iv_template  TYPE ztbatch_sched-template OPTIONAL
        iv_jobtext   TYPE ztbatch_sched-jobtext  OPTIONAL
        iv_param     TYPE string                 OPTIONAL
        is_start     TYPE zif_batch_job=>ty_start_option OPTIONAL.

  PRIVATE SECTION.

    DATA mv_mode  TYPE c LENGTH 1.
    DATA ms_start TYPE zif_batch_job=>ty_start_option.

ENDCLASS.


CLASS zcl_batch_apj_task IMPLEMENTATION.

  METHOD constructor.
    mv_mode   = iv_mode.
    run_uuid  = iv_run_uuid.
    cid       = iv_cid.
    old_name  = iv_old_name.
    old_count = iv_old_count.
    template  = iv_template.
    jobtext   = iv_jobtext.
    param     = iv_param.
    ms_start  = is_start.
  ENDMETHOD.


  METHOD if_abap_parallel~do.

*   여기는 자식 세션이다. RAP BO 가 활성이 아니므로 APJ 가 커밋해도 된다.
    DATA(lo_adapter) = NEW zcl_batch_apj_adapter( ).

*   취소 - CANCEL / CHANGE 공통. 걸린 잡이 없으면 건너뛴다.
    IF mv_mode <> gc_mode-schedule AND old_name IS NOT INITIAL.
      message = lo_adapter->cancel( iv_job_name  = old_name
                                    iv_job_count = old_count ).
    ENDIF.

*   스케줄 - SCHEDULE / CHANGE 공통.
    IF mv_mode <> gc_mode-cancel.
      DATA(ls_sched) = lo_adapter->schedule( iv_template = template
                                             iv_jobtext  = jobtext
                                             iv_param    = param
                                             is_start    = ms_start ).
      job_name  = ls_sched-job_name.
      job_count = ls_sched-job_count.
      message   = ls_sched-message.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
