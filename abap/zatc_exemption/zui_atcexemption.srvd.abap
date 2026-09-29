@EndUserText.label: 'ATC Exemption Management'
// 서비스는 하나다. 신청과 승인을 한 서비스에 노출하고, 화면 안에서 권한과
// instance features 로 구분한다.
//
// Fiori 앱은 둘이다. Finding 과 Exemption 이 부모-자식이 아니라서 한 앱의
// 메인 엔티티가 될 수 없다. 서비스와 바인딩은 그대로 하나다.
//   앱 A  메인 = Finding    타일 ① "ATC 위반 조회"                  개발자
//   앱 B  메인 = Exemption  타일 ② "내 예외 신청"  Requester = 본인  개발자
//                           타일 ③ "ATC 예외 승인" 상태 = 승인대기   승인자
// ②와 ③은 같은 앱에 필터 프리셋만 다른 타일이다. 역할 카탈로그에 나누어 배치한다.
//
// 일은 ①에서 시작한다. 위반을 골라 requestExemption 을 누르면 신청서가 생기고,
// 그 뒤는 ②/③에서 흐른다.
define service ZUI_AtcExemption {
  expose ZP_AtcExemption     as Exemption;
  expose ZP_AtcExemptionItem as ExemptionItem;
  expose ZP_AtcExemptionLog  as ExemptionLog;

  // 위반 현황 조회 (읽기 전용). ATC 결과를 라이브로 읽는다.
  expose ZP_AtcFinding       as Finding;

  // 값 도움
  expose ZI_AtcReasonVH      as ReasonVH;
  expose ZI_AtcScopeVH       as ScopeVH;
  expose ZI_AtcVariantVH     as VariantVH;
  expose ZI_AtcPackageVH     as PackageVH;
}
