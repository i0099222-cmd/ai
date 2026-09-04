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

ENDCLASS.


CLASS zcx_batch_job IMPLEMENTATION.

  METHOD constructor.
    super->constructor( previous = previous ).
    me->message = message.
  ENDMETHOD.

ENDCLASS.
