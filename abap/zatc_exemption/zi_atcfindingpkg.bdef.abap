// 패키지 탭. 위반 탭(ZI_AtcFinding)과 같은 구성이다 - 읽기 전용이고
// 신청서를 만드는 액션 하나뿐이다.
unmanaged implementation in class zbp_i_atcfindingpkg unique;
strict ( 2 );

define behavior for ZI_AtcFindingPkg alias FindingPackage
{
  // 선택한 패키지마다 패키지 예외 신청서를 하나씩 만든다.
  action requestExemption parameter ZD_AtcRequestExemption result [1] $self;
}
