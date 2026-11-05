@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '시스템 ID'
@ObjectModel.resultSet.sizeCategory: #XS
// 시스템 ID 설정 테이블 (ZDO_SYSID). 테이블 이름이 다르면 여기 한 줄만 바꾼다.
define view entity ZI_CMSM_SysId
  as select from ztcmsm00240
{
      @ObjectModel.text.element: [ 'Description' ]
      @EndUserText.label: '시스템 ID'
  key sysid       as SysId,
      @Semantics.text: true
      @EndUserText.label: '설명'
      description as Description
}
