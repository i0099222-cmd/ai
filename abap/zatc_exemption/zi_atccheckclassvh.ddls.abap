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
// 대상 줄 Check Class 의 값 도움. 변형과 체크 클래스의 짝이라 변형 이름으로 그 변형의 체크를 찾는다.
// 같은 체크가 변형 여러 개에 있으면 변형마다 한 줄씩 나온다. 어느 줄을 골라도 체크 클래스는 같다.
//
// 표준은 변형의 체크 목록을 클러스터로 저장해 CDS 로 읽을 수 없다. 그래서 그 변형으로
// 실제로 돈 ATC 결과에서 짝을 만든다. 한 번도 돌지 않은 변형은 여기 없다.
//
// 체크 클래스는 ZI_AtcFinding 과 같은 컬럼(SATC_AC_CHM.ci_id), 같은 캐스트다.
// 표준 예외의 i_check_class 로 그대로 넘어간다.
define view entity ZI_AtcCheckClassVH
  as select distinct from satc_api_findings as Finding

    inner join satc_ac_chm as Chm
      on Chm.module_id = Finding.moduleid
{
      @Search.defaultSearchElement: true
      @EndUserText.label: 'Check Variant'
  key Finding.checkvariant                 as CheckVariant,

      @Search.defaultSearchElement: true
      @EndUserText.label: 'Check Class'
  key cast( Chm.ci_id as abap.char( 30 ) ) as CheckClass
}
