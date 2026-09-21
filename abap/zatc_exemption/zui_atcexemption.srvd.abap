@EndUserText.label: 'ATC Exemption Management'
// 앱은 하나다. 신청과 승인을 한 서비스에 함께 노출하고, 화면 안에서
// 권한과 instance features 로 구분한다.
//
// 런치패드 타일은 2개로 만든다 (앱을 나누는 것이 아니라 필터 프리셋만 다르게).
//   타일 A "ATC 예외 신청"  : Requester = 본인, 상태 = 초안/반려
//   타일 B "ATC 예외 승인"  : 상태 = 승인대기
// 각 타일을 개발자 / 승인자 역할 카탈로그에 나누어 배치한다.
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
