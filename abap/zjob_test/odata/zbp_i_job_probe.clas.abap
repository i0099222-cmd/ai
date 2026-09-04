"! <p class="shorttext synchronized">ZI_JOB_PROBE Behavior Implementation</p>
"!
"! 프로브는 읽기 전용이라 핸들러가 필요 없다.
"! (global authorization 만 구현)
CLASS zbp_i_job_probe DEFINITION
  PUBLIC
  ABSTRACT
  FINAL
  FOR BEHAVIOR OF zi_job_probe.
ENDCLASS.

CLASS zbp_i_job_probe IMPLEMENTATION.
ENDCLASS.


CLASS lhc_probe DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR probe RESULT result.
ENDCLASS.

CLASS lhc_probe IMPLEMENTATION.
  METHOD get_global_authorizations.
    " 테스트 서비스 - 전부 허용
  ENDMETHOD.
ENDCLASS.
