@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'As-Is 유형 VH'
@ObjectModel.resultSet.sizeCategory: #XS
// 매핑 탭 As-Is에 쓸 수 있는 유형 (ECC 쪽 오브젝트).
// 매핑 BO 검증(validateObjectType)도 이 뷰를 보니 바꿀 때는 where만 고친다.
define view entity ZI_CMSM_AsisTypeVH
  as select from ZI_CMSM_ObjTypeVH
{
      @ObjectModel.text.element: [ 'Text' ]
  key Value,
      Text
}
where
     Value = 'RFC'
  or Value = 'FM'
  or Value = 'PROXY'
  or Value = 'TABLE'
  or Value = 'TCODE'
  or Value = 'CLASS'
  or Value = 'CDS'
