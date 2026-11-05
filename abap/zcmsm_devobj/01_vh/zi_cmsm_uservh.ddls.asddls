@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '사용자 VH'
@Search.searchable: true
// 사용자 이름 출처는 이 파일 하나에만 둔다.
// I_BusinessUserBasic 은 비즈니스 사용자(BP 연결된 사용자)만 나온다.
// SU01 사용자만 있는 환경이면 이 select 소스만 바꾸면 된다.
define view entity ZI_CMSM_UserVH
  as select from I_BusinessUserBasic
{
      @ObjectModel.text.element: [ 'PersonFullName' ]
      @Search.defaultSearchElement: true
      @EndUserText.label: '사용자 ID'
  key UserID         as UserId,
      @Semantics.text: true
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @EndUserText.label: '이름'
      PersonFullName
}
