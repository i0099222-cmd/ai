@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Package Value Help'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #D,
  sizeCategory: #S,
  dataClass: #MIXED
}
@ObjectModel.resultSet.sizeCategory: #S
// TODO 확인 필요: TDEVC 의 API State. ABAP Cloud 에서 막히면 released 패키지 뷰로 교체.
// 고객 네임스페이스만 노출해 표준 패키지에 예외가 걸리는 것을 화면 단계에서 막는다.
define view entity ZI_AtcPackageVH
  as select from tdevc
{
  key devclass as Devclass,
      parentcl as ParentPackage,
      pdevclass as PackageType
}
where devclass like 'Z%'
   or devclass like 'Y%'
   or devclass like '/%'
