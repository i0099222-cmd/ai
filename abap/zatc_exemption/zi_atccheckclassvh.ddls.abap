@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ATC Check Class Value Help'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #D,
  sizeCategory: #S,
  dataClass: #MIXED
}
@Search.searchable: true
// 신청서의 체크 클래스 값 도움. 선등록은 프리필할 finding 이 없어 사용자가 고른다.
//
// ATC 에 등록된 체크 모듈(SATC_AC_CHM)의 체크 ID 다. ZI_AtcFinding 이 finding 의
// CheckClass 를 같은 컬럼에서 같은 캐스트로 만들므로, 여기서 고른 값과 조회 화면
// 신청의 값이 같은 형태가 된다. 표준 예외의 i_check_class 로 그대로 넘어간다.
define view entity ZI_AtcCheckClassVH
  as select distinct from satc_ac_chm
{
      @Search.defaultSearchElement: true
      @EndUserText.label: 'Check Class'
  key cast( ci_id as abap.char( 30 ) ) as CheckClass
}
