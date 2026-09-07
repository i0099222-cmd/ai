"! <p class="shorttext synchronized">배치 스케줄 공통 타입</p>
INTERFACE zif_batch_job
  PUBLIC.

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
      " 반복 주기. 하나만 채운다. granularity + value 로 변환된다.
      prd_mins          TYPE i,
      prd_hours         TYPE i,
      prd_days          TYPE i,
      prd_weeks         TYPE i,
      prd_months        TYPE i,

      " 종료 조건 - AS-IS 배치잡 close시간
      "   값이 있으면 APJ END_INFO type = BY, 없으면 NONE(무한 반복)
      end_date          TYPE d,
      end_time          TYPE t,
    END OF ty_start_option.

ENDINTERFACE.
