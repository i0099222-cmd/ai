"! <p class="shorttext synchronized">배치잡 테스트 예외</p>
"!
"! force_fail 파라미터로 잡을 일부러 오류 종료시킬 때 사용한다.
"! 목적: 같은 오류가 SM37 에서는 어떤 상태로, Application Jobs 앱에서는
"! 어떤 상태로 보이는지 비교하는 것. (COMPARISON.md 항목 #15)
CLASS zcx_job_test DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    DATA message TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        message  TYPE string           OPTIONAL
        previous TYPE REF TO cx_root   OPTIONAL.

ENDCLASS.


CLASS zcx_job_test IMPLEMENTATION.

  METHOD constructor.
    super->constructor( previous = previous ).
    me->message = message.
  ENDMETHOD.

ENDCLASS.
