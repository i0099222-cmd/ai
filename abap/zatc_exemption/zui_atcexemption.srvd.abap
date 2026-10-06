@EndUserText.label: 'ATC Exemption Management'
// 서비스와 앱은 하나다. 신청과 승인을 한 서비스에 노출하고, 화면 안에서 권한과
// instance features 로 구분한다.
//   타일 ① My ATC Exemptions      내 ATC 예외 요청
//   타일 ② Review ATC Exemptions  ATC 예외 결재
// 같은 앱에 필터 프리셋만 다른 타일이다(① Requester = 본인, ② 상태 = 승인대기).
//
// ②를 "Approve ATC Exemptions" 로 부르지 않는다. 그것이 표준 Fiori 앱의 이름이고,
// 런치패드에 나란히 뜨면 어디서 결재해야 하는지 알 수 없게 된다.
//
// 위반 조회 앱은 없다. 요청서의 대상 줄에서 값 도움(FindingObjectVH / FindingPackageVH)
// 으로 위반이 있는 오브젝트·패키지를 고른다.
define service ZUI_AtcExemption {
  expose ZP_AtcExemption     as Exemption;
  expose ZP_AtcExemptionItem as ExemptionItem;
  expose ZP_AtcExemptionLog  as ExemptionLog;

  // 값 도움
  expose ZI_AtcReasonVH      as ReasonVH;
  expose ZI_AtcVariantVH     as VariantVH;
  expose ZI_AtcCheckClassVH  as CheckClassVH;
  expose ZI_AtcCheckCodeVH   as CheckCodeVH;
  expose ZI_AtcFindingObjVH  as FindingObjectVH;
  expose ZI_AtcFindingPkgVH  as FindingPackageVH;
  expose ZI_AtcPackageVH     as PackageVH;
}
