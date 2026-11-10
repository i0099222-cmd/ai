"! custom entity 쿼리 에러 · OData 응답의 에러 메시지로 나간다.
CLASS zcx_cmup_query DEFINITION PUBLIC INHERITING FROM cx_rap_query_provider FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_text  TYPE string OPTIONAL
                previous LIKE previous OPTIONAL.
    METHODS get_text REDEFINITION.
  PRIVATE SECTION.
    DATA mv_text TYPE string.
ENDCLASS.

CLASS zcx_cmup_query IMPLEMENTATION.
  METHOD constructor.
    super->constructor( previous = previous ).
    mv_text = iv_text.
  ENDMETHOD.

  METHOD get_text.
    result = mv_text.
  ENDMETHOD.
ENDCLASS.
