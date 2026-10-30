CLASS zcl_cm_multipart_util DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_s_part,
             name         TYPE string,    " 폼 필드명
             text         TYPE string,    " 텍스트 파트 값
             filename     TYPE string,    " 파일 파트만
             content_type TYPE string,    " 파일 파트만 (비우면 확장자로 자동 판단)
             binary       TYPE xstring,   " 파일 파트만
           END OF ty_s_part,
           tt_part TYPE STANDARD TABLE OF ty_s_part WITH EMPTY KEY.

    CLASS-METHODS get_mime_type
      IMPORTING iv_filename    TYPE string
      RETURNING VALUE(rv_mime) TYPE string.
ENDCLASS.

CLASS zcl_cm_multipart_util IMPLEMENTATION.
  METHOD get_mime_type.
    rv_mime = SWITCH #( to_lower( substring_after( val = iv_filename sub = '.' occ = -1 ) )
                WHEN 'xlsx' THEN `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`
                WHEN 'xls'  THEN `application/vnd.ms-excel`
                WHEN 'csv'  THEN `text/csv`
                WHEN 'pdf'  THEN `application/pdf`
                ELSE             `application/octet-stream` ).
  ENDMETHOD.
ENDCLASS.
