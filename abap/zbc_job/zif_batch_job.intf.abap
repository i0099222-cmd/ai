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
      "! 시작 일시. AS-IS 인터페이스 형식 그대로 CHAR(15) 로 받는다.
      "! 어댑터가 숫자만 뽑아 YYYYMMDD + HHMMSS 로 파싱한다.
      start_datetime    TYPE c LENGTH 15,
      timezone          TYPE c LENGTH 6,
      " 반복 주기. 하나만 채운다. granularity + value 로 변환된다.
      prd_mins          TYPE i,
      prd_hours         TYPE i,
      prd_days          TYPE i,
      prd_weeks         TYPE i,
      prd_months        TYPE i,

      "! 종료 일시 - AS-IS 배치잡 close시간. 같은 CHAR(15) 형식.
      "! 값이 있으면 APJ END_INFO type = BY, 없으면 NONE(무한 반복)
      end_datetime      TYPE c LENGTH 15,
    END OF ty_start_option.

ENDINTERFACE.
