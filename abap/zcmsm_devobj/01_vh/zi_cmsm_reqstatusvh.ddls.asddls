@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '요청 상태 VH'
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZI_CMSM_ReqStatusVH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE( p_domain_name: 'ZDO_DM_REQ_STATUS' ) as Val
    left outer join DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZDO_DM_REQ_STATUS' ) as Txt
      on  Txt.value_position = Val.value_position
      and Txt.language       = $session.system_language
{
      @ObjectModel.text.element: [ 'Text' ]
      @EndUserText.label: '상태'
  key cast( Val.value_low as abap.char( 1 ) ) as Value,
      @Semantics.text: true
      @EndUserText.label: '내역'
      Txt.text as Text
}
