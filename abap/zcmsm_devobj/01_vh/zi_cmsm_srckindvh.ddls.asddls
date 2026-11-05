@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'VH 데이터 소스 유형 VH'
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_CMSM_SrcKindVH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE( p_domain_name: 'ZDO_DM_SRC_KIND' ) as Val
    left outer join DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZDO_DM_SRC_KIND' ) as Txt
      on  Txt.value_position = Val.value_position
      and Txt.language       = $session.system_language
{
      @ObjectModel.text.element: [ 'Text' ]
      @EndUserText.label: '소스 유형'
  key cast( Val.value_low as abap.char( 1 ) ) as Value,
      @Semantics.text: true
      @EndUserText.label: '내역'
      Txt.text as Text
}
