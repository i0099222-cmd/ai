"! <p class="shorttext synchronized">배치잡 실행 예외</p>
"!
"! Application Job 실행 클래스가 실패를 알릴 때 던진다.
"! EXECUTE 밖으로 나가면 잡이 오류 종료된다.
CLASS zcx_batch_job DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    DATA message TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        message  TYPE string         OPTIONAL
        previous TYPE REF TO cx_root OPTIONAL.

    "! MESSAGE 를 예외 텍스트로 노출한다. 이게 없으면 CATCH cx_root 로
    "! 받아서 GET_TEXT( ) 하는 쪽에 클래스 설명만 가고 사유가 사라진다.
    METHODS get_text REDEFINITION.

ENDCLASS.


CLASS zcx_batch_job IMPLEMENTATION.

  METHOD constructor.
    super->constructor( previous = previous ).
    me->message = message.
  ENDMETHOD.


  METHOD get_text.
    result = COND #( WHEN message IS NOT INITIAL THEN message
                     ELSE super->get_text( ) ).
  ENDMETHOD.

ENDCLASS.
