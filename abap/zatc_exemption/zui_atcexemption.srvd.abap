@EndUserText.label: 'ATC Exemption Management'
// 서비스는 하나다. 신청과 승인을 한 서비스에 노출하고, 화면 안에서 권한과
// instance features 로 구분한다.
//
// Fiori 앱은 둘이다. Finding 과 Exemption 이 부모-자식이 아니라서 한 앱의
// 메인 엔티티가 될 수 없다. 서비스와 바인딩은 그대로 하나다.
//   앱 A  메인 = Finding    타일 ① Display ATC Findings   ATC 위반 조회
//   앱 B  메인 = Exemption  타일 ② My ATC Exemptions       내 ATC 예외 신청
//                           타일 ③ Review ATC Exemptions   ATC 예외 결재
// ②와 ③은 같은 앱에 필터 프리셋만 다른 타일이다(② Requester = 본인,
// ③ 상태 = 승인대기). 역할 카탈로그에 나누어 배치한다.
//
// ③을 "Approve ATC Exemptions" 로 부르지 않는다. 그것이 표준 Fiori 앱의 이름이고,
// 런치패드에 나란히 뜨면 어디서 결재해야 하는지 알 수 없게 된다. 결재 창구를 이
// 앱 하나로 남기는 것이 이 앱을 CBO 로 만든 이유다.
//
// 일은 ①에서 시작한다. 위반을 골라 requestExemption 을 누르면 신청서가 생기고,
// 그 뒤는 ②/③에서 흐른다.
define service ZUI_AtcExemption {
  expose ZP_AtcExemption     as Exemption;
  expose ZP_AtcExemptionItem as ExemptionItem;
  expose ZP_AtcExemptionLog  as ExemptionLog;

  // 위반 현황 조회 (읽기 전용). ATC 결과를 라이브로 읽는다.
  // 앱 A 의 두 탭이다. Finding = 오브젝트 탭, FindingPackage = 패키지 탭.
  expose ZP_AtcFinding       as Finding;
  expose ZP_AtcFindingPkg    as FindingPackage;

  // 값 도움
  expose ZI_AtcReasonVH      as ReasonVH;
  expose ZI_AtcScopeVH       as ScopeVH;
  expose ZI_AtcVariantVH     as VariantVH;
  expose ZI_AtcPackageVH     as PackageVH;
  expose ZI_AtcCheckClassVH  as CheckClassVH;
  expose ZI_AtcCheckCodeVH   as CheckCodeVH;
}
