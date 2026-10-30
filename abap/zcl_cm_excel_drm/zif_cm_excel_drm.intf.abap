INTERFACE zif_cm_excel_drm PUBLIC.
  " (기존 타입 정의 그대로: ty_s_excel_upload_res, ty_s_parse_body, ty_s_parse_res, tt_rows, ty_s_del_body ...)
  " ty_s_upload_body는 multipart로 바뀌면서 더 이상 쓰지 않음 → 삭제 가능

  CONSTANTS:
    BEGIN OF c_apiid,
      upload TYPE string VALUE 'if_upload',
      parse  TYPE string VALUE 'if_parse',
      delete TYPE string VALUE 'if_delete',
    END OF c_apiid,

    BEGIN OF c_upload_field,             " 업로드 API 문서의 폼 필드명
      key   TYPE string VALUE 'key',
      empno TYPE string VALUE 'empno',
      file  TYPE string VALUE 'file',
    END OF c_upload_field,

    c_upload_ok         TYPE string  VALUE '300',
    c_parse_ok          TYPE i       VALUE 200,
    c_parse_status_done TYPE i       VALUE 3,
    c_return_type_json  TYPE string  VALUE 'json',
    c_daily_limit       TYPE i       VALUE 300,
    c_limit_tz          TYPE tznzone VALUE 'KOREA'.   " ← 콘솔에서 확인한 타임존 키로
ENDINTERFACE.
