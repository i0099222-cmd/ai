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

  "! 실행일이 비근무일일 때 어떻게 할지.
  "! APJ EXCEPTION-START_RESTRICTION_CODE 의 값 도메인 그대로다.
  CONSTANTS:
    BEGIN OF gc_restriction,
      "! 실행하지 않고 건너뛴다
      do_not_process TYPE c LENGTH 1 VALUE 'D',
      "! 이전 근무일로 당긴다
      before         TYPE c LENGTH 1 VALUE 'B',
      "! 다음 근무일로 미룬다
      after          TYPE c LENGTH 1 VALUE 'A',
      "! 제한 없이 그날 실행한다
      none           TYPE c LENGTH 1 VALUE 'N',
    END OF gc_restriction.

  "! MONTH_INFO-SHIFT_DIRECTION - 작업일 기준 시작일을 어느 쪽에서 세는지.
  "! ("count direction for on workday start date of a job")
  "! NUMC(2) 이고 START_RESTRICTION_CODE(D/B/A/N)와 다른 도메인이다.
  "!
  "! TODO: 시그니처 확인 - 실제 값. 도메인 고정값이 없어 확인할 곳이
  "!       없으므로, 월초 기준으로 걸어 SM37 실행일이 맞는지로 판정한다.
  "!       01/02 는 NUMC 열거의 관례를 따른 추측이다.
  CONSTANTS:
    BEGIN OF gc_shift,
      "! 월초부터 센다
      from_month_start TYPE n LENGTH 2 VALUE '01',
      "! 월말부터 거꾸로 센다
      from_month_end   TYPE n LENGTH 2 VALUE '02',
    END OF gc_shift.

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

      " --- 제한 조건 (AS-IS SM36 Restrictions 팝업) ---------------------
      " AS-IS 어휘로 받고 APJ 구조로의 변환은 어댑터가 한다.
      " EXCEPTION{calendar_id, start_restriction_code} 와
      " MONTH_INFO{day, use_working_days_ind, shift_direction} 로 나뉜다.

      "! 공장달력 ID. 어느 날이 근무일인지의 기준.
      "! 비어 있으면 근무일 판정을 하지 않는다.
      calendar_id       TYPE c LENGTH 2,
      "! 월중 몇 번째 날에 실행할지 (AS-IS 공장근무일수 = WDAYNO).
      month_day         TYPE i,
      "! MONTH_DAY 를 달력일이 아니라 작업일로 센다.
      "! AS-IS 는 공장달력을 쓰므로 항상 작업일 기준이다.
      use_working_days  TYPE abap_bool,
      "! MONTH_DAY 를 월말부터 거꾸로 센다 (AS-IS EOFMONTH).
      "! 비어 있으면 월초부터 센다 (AS-IS BOFMONTH).
      "! 3 + 이 플래그 = "말일에서 3번째 작업일".
      count_from_end    TYPE abap_bool,
      "! 실행일이 비근무일일 때의 처리. GC_RESTRICTION 참조.
      "! AS-IS 는 SM36 제한조건 팝업의 4지선다를 그대로 쓴다.
      start_restriction TYPE c LENGTH 1,
    END OF ty_start_option.

ENDINTERFACE.
