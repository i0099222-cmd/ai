"! 엑셀 업로드 -> 임의 테이블 마이그레이션 공통 인터페이스.
"!
"! 설계 원칙 (요구사항 확인 결과 반영):
"!   1) 대상 테이블은 화이트리스트(ZEXCEL_MIGR_WL) + AUTHORITY-CHECK(S_TABU_NAM)로
"!      이중 검증한다. 액션 파라미터로 넘어온 테이블명을 검증 없이 그대로
"!      동적 INSERT에 쓰면 임의 테이블(심지어 SAP 표준 테이블) 오염 위험이 있다.
"!   2) RAP 액션은 "접수"만 한다. 실제 파싱/INSERT는 백그라운드 잡에서
"!      처리한다 - 대량 엑셀을 액션의 단일 다이얼로그 LUW 안에서 처리하면
"!      타임아웃/장시간 락 문제가 생기기 때문.
"!   3) 엑셀 바이너리 파싱(CL_FDT_XL_SPREADSHEET)과 동적 테이블명 INSERT는
"!      둘 다 ABAP Cloud 릴리즈 API가 아니므로, zcl_parked_doc_poster와 동일하게
"!      Standard ABAP 언어버전 + Local Release 오브젝트(FM/리포트)로 분리한다.
"!
"! 필요 DDIC 오브젝트 (SE11/ADT에서 사전 생성):
"!   ZEXCEL_MIGR_WL  (화이트리스트, Customizing 테이블)
"!     TABNAME   TYPE TABNAME  (key)  - 마이그레이션 허용 대상 테이블
"!     ACTIVE    TYPE ABAP_BOOL       - 사용 여부
"!     DESCR     TYPE STRING         - 설명/담당 모듈
"!
"!   ZEXCEL_MIGR_REQ (업로드 접수/진행상태 테이블)
"!     REQUEST_ID    TYPE SYSUUID_X16 (key)
"!     TABNAME       TYPE TABNAME
"!     FILENAME      TYPE STRING
"!     FILE_CONTENT  TYPE XSTRING     - 업로드된 xlsx 바이너리 원본
"!     STATUS        TYPE CHAR1       - N(신규) P(처리중) S(성공) E(오류)
"!     TOTAL_ROWS    TYPE I
"!     PROCESSED_ROWS TYPE I
"!     ERROR_ROWS    TYPE I
"!     MESSAGE       TYPE STRING      - 마지막 오류 요약
"!     CREATED_BY    TYPE SYUNAME
"!     CREATED_AT    TYPE UTCLONG      - CL_ABAP_CONTEXT_INFO/UTCLONG_CURRENT( )와 타입 맞춤
INTERFACE zif_excel_table_migrator
  PUBLIC.

  "! 업로드 접수 요청
  TYPES:
    BEGIN OF ty_request,
      tabname      TYPE tabname,
      filename     TYPE string,
      file_content TYPE xstring,
    END OF ty_request.

  "! 접수 결과 - 실제 처리는 백그라운드 잡이 비동기로 수행하므로
  "! 여기서는 request_id만 돌려주고, 진행상태는 ZEXCEL_MIGR_REQ 조회로 확인한다.
  TYPES:
    BEGIN OF ty_accept_result,
      request_id TYPE sysuuid_x16,
      job_name   TYPE btcjob,
      job_count  TYPE btcjobcnt,
    END OF ty_accept_result.

  "! 테이블 화이트리스트 + AUTHORITY-CHECK(S_TABU_NAM) 검증.
  "! 액션 핸들러/리포트 양쪽에서 반드시 이 메서드를 통해서만 대상 테이블
  "! 허용 여부를 판단한다 (검증 로직 중복/누락 방지).
  METHODS check_table_allowed
    IMPORTING
      iv_tabname       TYPE tabname
      iv_activity      TYPE activ_auth DEFAULT '02'
    RETURNING
      VALUE(rv_allowed) TYPE abap_bool.

  "! 업로드 파일을 접수(스테이징 테이블 저장)하고, 실제 마이그레이션을
  "! 수행할 백그라운드 잡을 예약한다. 이 메서드 자체는 ABAP Cloud
  "! 릴리즈 API만 사용하므로 RAP behavior implementation에서 직접 호출 가능.
  METHODS accept_request
    IMPORTING
      is_request       TYPE ty_request
    RETURNING
      VALUE(rs_result) TYPE ty_accept_result
    RAISING
      zcx_excel_migr_error.

ENDINTERFACE.
