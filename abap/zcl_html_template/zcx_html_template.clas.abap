"! HTML 템플릿 로드/치환 중 발생하는 오류.
"! RAP handler에서는 get_text( )를 new_message_with_text( )로 감싸
"! reported에 넣으면 된다.
CLASS zcx_html_template DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS constructor
      IMPORTING
        iv_text  TYPE string OPTIONAL
        previous LIKE previous OPTIONAL.

    METHODS if_message~get_text REDEFINITION.

  PRIVATE SECTION.

    DATA mv_text TYPE string.

ENDCLASS.


CLASS zcx_html_template IMPLEMENTATION.

  METHOD constructor ##ADT_SUPPRESS_GENERATION.

    super->constructor( previous = previous ).
    mv_text = iv_text.

  ENDMETHOD.


  METHOD if_message~get_text.

    result = mv_text.

    " 코드페이지 변환 오류 등 원인 예외가 있으면 그 내용을 덧붙인다.
    IF previous IS BOUND.
      result = |{ result } ({ previous->get_text( ) })|.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
