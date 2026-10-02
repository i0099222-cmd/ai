// 위반 조회는 읽기 전용이다. 여기 두는 것은 액션 하나뿐이고, finding 자체는
// 아무것도 바뀌지 않는다. 신청서를 만드는 것은 ZR_AtcExemption 쪽이다.
//
// read 를 선언하지 않는다. 목록 조회는 ZP_AtcFinding 의 transactional_query 가
// CDS 뷰를 직접 읽으므로 BO 의 read 가 필요 없고, 액션 안에서 쓸 필드는
// 핸들러가 뷰에서 SELECT 한다. unmanaged 에서 read 를 선언하면 그 SELECT 를
// 옮겨 담는 메서드만 하나 늘어난다.
//
// 🔴 구문 점검이 lock 이나 authorization 을 요구하면 여기에 추가한다.
//   읽기 전용 엔티티에 인스턴스 액션만 다는 구성이라 릴리스에 따라 다르다.
unmanaged implementation in class zbp_i_atcfinding unique;
strict ( 2 );

define behavior for ZI_AtcFinding alias Finding
{
  // 선택한 위반들로 오브젝트 단위(OBJ) 예외 신청서를 만든다.
  // 패키지 단위는 패키지 탭(ZI_AtcFindingPkg)의 같은 이름 액션이다.
  action requestExemption parameter ZD_AtcRequestExemption result [1] $self;
}
