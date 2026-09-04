"! <p class="shorttext synchronized">배치잡 실행 단위</p>
"!
"! 스케줄 대상이 되는 클래스는 이 인터페이스를 구현한다.
"! 런처가 ZTBATCH_SCHED-EXEC_CLASS 에 적힌 이름으로 동적 생성해서 EXECUTE 를 부른다.
"!
"! ** 왜 리포트가 아니라 클래스인가 **
"!   SUBMIT 은 ABAP for Cloud Development 에서 금지된다.
"!   임의 리포트를 돌리려면 Standard ABAP FM 을 경유해야 하는데,
"!   그러면 순수 Cloud 구성이 깨진다.
"!   실행 대상을 클래스로 두면 Standard ABAP 티어가 전혀 필요 없다.
"!
"! ** 기존 배치 리포트 이관 **
"!   ZR_XXX 리포트의 START-OF-SELECTION 로직을 이 인터페이스를 구현하는
"!   클래스로 옮긴다. 셀렉션 스크린 파라미터는 IV_PARAM(JSON)으로 받는다.
INTERFACE zif_batch_step
  PUBLIC.

  "! 배치 실행 본체.
  "!
  "! @parameter iv_param | ZTBATCH_SCHED-PARAM 의 app 영역. 업무 파라미터를 담은 JSON.
  "!                       배리언트를 대신하는 자리다.
  "! @parameter rv_message | 잡 로그에 남길 결과 요약
  "! @raising zcx_batch_job | 실행 실패. 던지면 잡이 오류 종료된다.
  METHODS execute
    IMPORTING
      iv_param          TYPE string OPTIONAL
    RETURNING
      VALUE(rv_message) TYPE string
    RAISING
      zcx_batch_job.

ENDINTERFACE.
