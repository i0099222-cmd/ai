"! CBO 등 임의의 커스텀 테이블/릴리즈된 CDS 엔터티를 대상으로 동적 업로드를 수행하는
"! 엔진(zcl_dynamic_table_upload)의 인터페이스. 대상 테이블 이름은 이미 알고 있다는
"! 전제(예: CBO 관리 화면/레지스트리에서 key user가 고른 값)로 동작한다.
INTERFACE zif_dynamic_table_upload
  PUBLIC.

  "! 동적 테이블 1개 필드에 대한 메타정보(RTTI + DDIC 텍스트)
  TYPES:
    BEGIN OF ty_field,
      fieldname TYPE fieldname,
      rollname  TYPE rollname,
      ddtext    TYPE scrtext_m,
      is_key    TYPE abap_bool,
      datatype  TYPE datatype_d,
      leng      TYPE ddleng,
      decimals  TYPE decimals,
    END OF ty_field,
    tt_field TYPE STANDARD TABLE OF ty_field WITH EMPTY KEY.

  "! 업로드/마이그레이션 중 발생한 메시지 1건(행 단위)
  TYPES:
    BEGIN OF ty_message,
      row       TYPE i,
      fieldname TYPE fieldname,
      msgty     TYPE symsgty,
      message   TYPE string,
    END OF ty_message,
    tt_message TYPE STANDARD TABLE OF ty_message WITH EMPTY KEY.

  "! 마이그레이션 결과 요약
  TYPES:
    BEGIN OF ty_result,
      total_rows   TYPE i,
      success_rows TYPE i,
      error_rows   TYPE i,
      t_message    TYPE tt_message,
    END OF ty_result.

  "! 대상 이름이 실제로 "업로드해서 쓸 수 있는 DB 테이블"인지 검증한다.
  "! TADIR 기반 오브젝트 목록에는 TABL 외 오브젝트가 대부분이고, TABL 안에도
  "! 구조체(TABCLASS = INTTAB)가 섞여 있어서 MODIFY 대상이 될 수 없다.
  "! 여기서는 기술적 판정(= 쓰기 가능한 DB 테이블인가)만 하고, "CBO만 허용" 같은
  "! 업무 정책(네임스페이스/권한)은 호출자(behavior handler)에서 판단한다.
  METHODS is_uploadable
    IMPORTING
      iv_table_name TYPE tabname
    RETURNING
      VALUE(rv_ok)  TYPE abap_bool.

  "! 대상 테이블/CDS 엔터티의 필드 구조를 RTTI로 동적 조회한다.
  "! DDIC 필드 텍스트 조회가 불가능한 구조(계산 필드 등)는 필드명만 채워서 반환한다.
  METHODS get_table_fields
    IMPORTING
      iv_table_name   TYPE tabname
    RETURNING
      VALUE(rt_field) TYPE tt_field
    RAISING
      zcx_dynamic_table_upload.

  "! 대상 테이블 구조에 맞는 업로드용 Excel 템플릿을 생성한다.
  "! 외부 라이브러리 없이 ABAP Cloud에서 바로 만들 수 있도록 ZIP이 필요 없는
  "! SpreadsheetML(.xls, Excel XML) 포맷으로 만든다. 1행 = 기술 필드명(업로드 키),
  "! 2행 = 필드 설명(참고용, 업로드 시 자동으로 무시됨).
  METHODS create_excel_template
    IMPORTING
      iv_table_name  TYPE tabname
    RETURNING
      VALUE(rv_file) TYPE xstring
    RAISING
      zcx_dynamic_table_upload.

  "! 업로드된 CSV 파일(세미콜론 구분, UTF-8. 템플릿을 Excel에서 채운 뒤
  "! "CSV UTF-8"로 저장했다고 가정)을 대상 테이블 구조의 동적 내부테이블로 변환하고,
  "! JSON 문자열로 직렬화해서 반환한다.
  METHODS convert_upload_to_json
    IMPORTING
      iv_table_name  TYPE tabname
      iv_file        TYPE xstring
    RETURNING
      VALUE(rv_json) TYPE string
    RAISING
      zcx_dynamic_table_upload.

  "! JSON 문자열을 대상 테이블 구조의 동적 내부테이블로 역직렬화한 뒤 그대로
  "! 대상 테이블에 MODIFY(=migration)한다.
  "! iv_commit = abap_false로 호출하면 COMMIT/ROLLBACK WORK를 직접 하지 않는다
  "! (RAP behavior save 시퀀스 안에서 호출할 때 사용).
  METHODS migrate_json_to_table
    IMPORTING
      iv_table_name    TYPE tabname
      iv_json          TYPE string
      iv_commit        TYPE abap_bool DEFAULT abap_true
    RETURNING
      VALUE(rs_result) TYPE ty_result
    RAISING
      zcx_dynamic_table_upload.

  "! convert_upload_to_json + migrate_json_to_table를 한 번에 수행하는 편의 메서드.
  METHODS upload_and_migrate
    IMPORTING
      iv_table_name    TYPE tabname
      iv_file          TYPE xstring
      iv_commit        TYPE abap_bool DEFAULT abap_true
    RETURNING
      VALUE(rs_result) TYPE ty_result
    RAISING
      zcx_dynamic_table_upload.

ENDINTERFACE.
