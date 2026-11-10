"! SU3 래퍼 예외 · BAPI RETURN 의 에러 메시지를 그대로 담는다.
CLASS zcx_cmup_user_api DEFINITION PUBLIC INHERITING FROM cx_static_check FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_text  TYPE string OPTIONAL
                previous LIKE previous OPTIONAL.
    METHODS get_text REDEFINITION.
  PRIVATE SECTION.
    DATA mv_text TYPE string.
ENDCLASS.

CLASS zcx_cmup_user_api IMPLEMENTATION.
  METHOD constructor.
    super->constructor( previous = previous ).
    mv_text = iv_text.
  ENDMETHOD.

  METHOD get_text.
    result = mv_text.
  ENDMETHOD.
ENDCLASS.
