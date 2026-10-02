"! ZI_AtcFinding 의 behavior pool.
"!
"! 조회 화면에서 고른 위반들로 예외 신청서를 만든다. 신청서 생성 자체는
"! ZR_AtcExemption 의 createFromFinding 이 하고, 여기서는 선택 건을 묶어
"! 몇 건을 만들지만 정한다.
CLASS zbp_i_atcfinding DEFINITION
  PUBLIC
  ABSTRACT
  FINAL
  FOR BEHAVIOR OF zi_atcfinding.
ENDCLASS.


CLASS zbp_i_atcfinding IMPLEMENTATION.
ENDCLASS.
