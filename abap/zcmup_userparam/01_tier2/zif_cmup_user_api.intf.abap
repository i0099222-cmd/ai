"! SU3(사용자 기본값·파라미터) 래퍼 인터페이스 · Tier 2
"!
"! ABAP Cloud 코드는 BAPI·미공개 테이블을 직접 못 쓰므로 이 인터페이스로만 접근한다.
"! 시그니처에는 BAPI 구조(BAPIDEFAUL 등)를 쓰지 않고 기본 타입만 쓴다.
"! release: API State → Use System-Internally (Contract C1) + Use in Cloud Development
INTERFACE zif_cmup_user_api PUBLIC.

  TYPES:
    ty_user  TYPE c LENGTH 12,
    "! 항목 ID = 기본값 필드명(DATFM 등) 또는 파라미터 ID(BUK 등, TPARA-PARAMID 20자리)
    ty_item  TYPE c LENGTH 20,
    ty_value TYPE c LENGTH 40,

    BEGIN OF ty_setting,
      item_id TYPE ty_item,
      value   TYPE ty_value,
    END OF ty_setting,
    tt_setting TYPE SORTED TABLE OF ty_setting WITH UNIQUE KEY item_id.

  CONSTANTS:
    "! SU3 기본값 탭 항목. 이 5개가 아니면 전부 파라미터 ID 로 본다.
    BEGIN OF c_default,
      langu  TYPE ty_item VALUE 'LANGU',    " 로그온 언어 (SAP 언어 키 3, E … 그대로)
      datfm  TYPE ty_item VALUE 'DATFM',    " 날짜 형식
      dcpfm  TYPE ty_item VALUE 'DCPFM',    " 소수점 표기
      timefm TYPE ty_item VALUE 'TIMEFM',   " 시간 형식
      tzone  TYPE ty_item VALUE 'TZONE',    " 타임존
    END OF c_default.

  "! 사용자의 기본값 5개 + 파라미터 전체 (BAPI_USER_GET_DETAIL)
  METHODS get_settings
    IMPORTING iv_user           TYPE ty_user
    RETURNING VALUE(rt_setting) TYPE tt_setting
    RAISING   zcx_cmup_user_api.

  "! 넘긴 항목만 바꾸고 나머지(다른 파라미터 포함)는 그대로 둔다 (BAPI_USER_CHANGE)
  "! - 파라미터 값이 빈 값이면 그 파라미터를 지운다
  "! - COMMIT 하지 않는다 → RAP 저장 단계에서 호출, 커밋은 RAP 가 한다
  METHODS change_settings
    IMPORTING iv_user    TYPE ty_user
              it_setting TYPE tt_setting
    RAISING   zcx_cmup_user_api.

ENDINTERFACE.
