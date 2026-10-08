"! ATC 예외 관리 앱 공통 상수/타입.
"! 코드값 리터럴과 정책 값은 전부 여기 둔다. 바뀌면 이 인터페이스만 고친다.
INTERFACE zif_atc_exemption
  PUBLIC.

  "! 적용 범위 (set_object_scope, 타입 SATC_CI_OBJ_SCOPE). 표준 고정값과 값이 같다.
  "!   obj  = ABAP Object
  "!   pckg = All Objects of Package
  CONSTANTS:
    BEGIN OF scope,
      obj  TYPE char4 VALUE 'OBJ',
      pckg TYPE char4 VALUE 'PCKG',
    END OF scope.

  "! 규칙 적용 축 (set_check_scope).
  "!   message = 이 메시지만          (코드를 넣은 오브젝트 대상)
  "!   check   = 이 체크의 모든 메시지  (패키지 대상, 코드를 비운 오브젝트 대상)
  "! ALL(모든 체크)은 쓰지 않는다. 대상의 ATC 체크가 통째로 꺼진다.
  CONSTANTS:
    BEGIN OF rulescope,
      message TYPE char3 VALUE 'MSG',
      check   TYPE char3 VALUE 'CHK',
    END OF rulescope.

  "! 요청서 상태
  CONSTANTS:
    BEGIN OF status,
      draft    TYPE char2 VALUE '10',
      pending  TYPE char2 VALUE '20',
      approved TYPE char2 VALUE '30',
      rejected TYPE char2 VALUE '40',
      revoked  TYPE char2 VALUE '50',
      expired  TYPE char2 VALUE '60',
    END OF status.

  "! 대상 한 줄의 표준 쪽 진행 상태 (ztatcexempti-stdstatus)
  CONSTANTS:
    BEGIN OF stdstatus,
      none     TYPE char1 VALUE ' ',
      pending  TYPE char1 VALUE 'P',
      approved TYPE char1 VALUE 'A',
      rejected TYPE char1 VALUE 'R',
    END OF stdstatus.

  "! 사유 코드. 값 목록은 표준 테이블 SATC_CI_REASONS 가 가진다(ZI_AtcReasonVH).
  CONSTANTS:
    BEGIN OF reason,
      false_positive TYPE char4 VALUE 'FPOS',
      other          TYPE char4 VALUE 'OTHR',
    END OF reason.

  "! 신청 정책. 모든 체크에 같게 적용한다.
  "!   maxvalidmon : 유효기간 상한(개월). 무기한 예외를 막는다
  "!   maxpriority : 이 값보다 심각한(작은) 우선순위의 위반이 있으면 예외 불가. 1 이 가장 심각
  "!   reasonreq   : 사유 서술 필수. 표준이 요구하지 않는 사유에도 받는다
  "!   minreason   : 사유 서술 최소 길이. 한 줄짜리 형식적 사유를 막는다
  "!   notiftype   : 표준 예외 메일 알림 (REJ 반려 시 / ALWS 항상 / NEVR 안 보냄)
  CONSTANTS:
    BEGIN OF policy,
      maxvalidmon TYPE i            VALUE 12,
      maxpriority TYPE i            VALUE 2,
      reasonreq   TYPE abap_boolean VALUE abap_true,
      minreason   TYPE i            VALUE 20,
      notiftype   TYPE char4        VALUE 'REJ',
    END OF policy.

  "! 이력 액션 코드
  CONSTANTS:
    BEGIN OF logaction,
      create   TYPE char10 VALUE 'CREATE',
      submit   TYPE char10 VALUE 'SUBMIT',
      withdraw TYPE char10 VALUE 'WITHDRAW',
      approve  TYPE char10 VALUE 'APPROVE',
      reject   TYPE char10 VALUE 'REJECT',
      expire   TYPE char10 VALUE 'EXPIRE',
    END OF logaction.

  "! 요청서의 대상 줄들
  TYPES tt_item TYPE STANDARD TABLE OF ztatcexempti WITH EMPTY KEY.

  "! 표준 반영 후 대상 한 줄의 상태. 처리 성공 여부와 무관하게 실제 상태를 담는다.
  "! 요청서 처리가 실패해도 표준에서 이미 바뀐 줄은 남겨야 다음 시도가 건너뛴다.
  TYPES:
    BEGIN OF ty_item_result,
      itemuuid    TYPE sysuuid_x16,
      extexemptid TYPE sysuuid_c32,
      stdstatus   TYPE char1,
    END OF ty_item_result,
    tt_item_result TYPE STANDARD TABLE OF ty_item_result WITH EMPTY KEY.

  "! 요청서 1건의 표준 반영 결과. success 는 모든 대상이 성공했을 때만 X 다.
  TYPES:
    BEGIN OF ty_batch_result,
      success TYPE abap_boolean,
      message TYPE string,
      items   TYPE tt_item_result,
    END OF ty_batch_result.

ENDINTERFACE.
