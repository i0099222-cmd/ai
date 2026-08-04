"! zcl_dynamic_table_upload 전용 예외 클래스.
"! RTTI/JSON 변환/동적 Open SQL 처리 중 발생한 오류를 previous 예외로 감싸서 던진다.
CLASS zcx_dynamic_table_upload DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS constructor
      IMPORTING
        textid   LIKE if_t100_message=>t100key OPTIONAL
        previous LIKE previous OPTIONAL.

ENDCLASS.


CLASS zcx_dynamic_table_upload IMPLEMENTATION.

  METHOD constructor.

    super->constructor( previous = previous ).

    CLEAR me->textid.
    IF textid IS NOT INITIAL.
      me->textid = textid.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
