"! <p class="shorttext synchronized">배치잡 실행 예외</p>
"!
"! 스텝 클래스가 실패를 알릴 때 던진다. 런처가 잡아서 잡을 오류 종료시킨다.
CLASS zcx_bc_job DEFINITION
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


CLASS zcx_bc_job IMPLEMENTATION.

  METHOD constructor.
    super->constructor( previous = previous ).
    me->message = message.
  ENDMETHOD.

ENDCLASS.
