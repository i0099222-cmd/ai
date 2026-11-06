@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'To-Be 유형 VH'
@ObjectModel.resultSet.sizeCategory: #XS
// 매핑 탭 To-Be에 쓸 수 있는 유형. VH·Service Binding은 각자 탭에서 등록하니 뺀다.
// 매핑 BO 검증(validateObjectType)도 이 뷰를 보니 바꿀 때는 where만 고친다.
define view entity ZI_CMSM_TobeTypeVH
  as select from ZI_CMSM_ObjTypeVH
{
      @ObjectModel.text.element: [ 'Text' ]
  key Value,
      Text
}
where
      Value <> 'VH'
  and Value <> 'SRVB'
