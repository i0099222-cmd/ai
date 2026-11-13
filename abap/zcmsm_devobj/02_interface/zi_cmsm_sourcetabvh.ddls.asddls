@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '등록 구분 VH'
@ObjectModel.resultSet.sizeCategory: #XS
// 통합 조회의 등록 구분(SourceTab) 텍스트·드롭다운. 데이터가 있는 구분만 나온다.
define view entity ZI_CMSM_SourceTabVH
  as select distinct from ZI_CMSM_DevObject
{
      @ObjectModel.text.element: [ 'Text' ]
      @EndUserText.label: '등록 구분'
  key SourceTab,
      @Semantics.text: true
      @EndUserText.label: '내역'
      cast( case SourceTab
              when 'TOBE' then '매핑 To-Be'
              when 'ASIS' then '매핑 As-Is'
              when 'VH'   then 'Value Help'
              when 'SB'   then 'OData 서비스'
              when 'TD'   then '기술부채'
              else ''
            end as abap.char( 20 ) ) as Text
}
