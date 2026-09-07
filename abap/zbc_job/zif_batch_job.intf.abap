"! <p class="shorttext synchronized">배치 스케줄 공통 타입</p>
INTERFACE zif_batch_job
  PUBLIC.

  "! 잡 파라미터 값 하나의 range 원소.
  "! APJ 의 tt_templ_val 이 selname + sign/option/low/high 구조라
  "! select-option 도 표현할 수 있게 range 테이블로 받는다.
  TYPES:
    BEGIN OF ty_param_range,
      sign   TYPE c LENGTH 1,
      option TYPE c LENGTH 2,
      low    TYPE string,
      high   TYPE string,
    END OF ty_param_range,
    tt_param_range TYPE STANDARD TABLE OF ty_param_range WITH EMPTY KEY.

  "! 잡 파라미터 하나. ZTBATCH_SCHED-PARAM 의 JSON 배열 원소.
  "!
  "!   [{"name":"P_MODU","t_value":[{"sign":"I","option":"EQ","low":"SD"}]}]
  "!
  "! name 은 실행 클래스가 GET_PARAMETERS 에서 정의한 SELNAME 과 일치해야 한다.
  "! kind 는 호출자가 채운다 (아래 gc_kind).
  TYPES:
    BEGIN OF ty_param,
      name    TYPE c LENGTH 8,
      kind    TYPE c LENGTH 1,
      t_value TYPE tt_param_range,
    END OF ty_param,
    tt_param TYPE STANDARD TABLE OF ty_param WITH EMPTY KEY.

  "! APJ 파라미터 종류. 실행 클래스의 GET_PARAMETERS 가 정의한 KIND 와 맞아야 한다.
  "! TODO: 시그니처 확인 - IF_APJ_DT_EXEC_OBJECT 의 상수명/값
  CONSTANTS:
    BEGIN OF gc_kind,
      parameter     TYPE c LENGTH 1 VALUE 'P',
      select_option TYPE c LENGTH 1 VALUE 'S',
    END OF gc_kind.

  "! APJ 잡 상태 (adapter 가 정규화해서 돌려주는 값)
  CONSTANTS:
    BEGIN OF gc_status,
      scheduled TYPE c LENGTH 1 VALUE 'S',
      running   TYPE c LENGTH 1 VALUE 'R',
      finished  TYPE c LENGTH 1 VALUE 'F',
      error     TYPE c LENGTH 1 VALUE 'E',
      cancelled TYPE c LENGTH 1 VALUE 'C',
      unknown   TYPE c LENGTH 1 VALUE '?',
    END OF gc_status.

  "! 스케줄 옵션. 액션 파라미터로만 존재하고 DB 에 저장하지 않는다.
  TYPES:
    BEGIN OF ty_start_option,
      start_immediately TYPE abap_bool,
      start_date        TYPE d,
      start_time        TYPE t,
      timezone          TYPE c LENGTH 6,
      prd_mins          TYPE i,
      prd_hours         TYPE i,
      prd_days          TYPE i,
      prd_weeks         TYPE i,
      prd_months        TYPE i,
    END OF ty_start_option.

ENDINTERFACE.
