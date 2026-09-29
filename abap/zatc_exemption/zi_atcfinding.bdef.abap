// 위반 조회는 읽기 전용이다. 여기 두는 것은 액션 하나뿐이고, finding 자체는
// 아무것도 바뀌지 않는다. 신청서를 만드는 것은 ZR_AtcExemption 쪽이다.
//
// 🔴 구문 점검이 lock 이나 authorization 을 요구하면 여기에 추가한다.
//   읽기 전용 엔티티에 인스턴스 액션만 다는 구성이라 릴리스에 따라 다르다.
unmanaged implementation in class zbp_i_atcfinding unique;
strict ( 2 );

define behavior for ZI_AtcFinding alias Finding
{
  // 선택한 위반들로 예외 신청서를 만든다.
  // PCKG 범위면 같은 패키지끼리 신청서 하나로 묶인다.
  action requestExemption parameter ZD_AtcRequestExemption result [1] $self;
}
