@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '부채 구분 VH'
@ObjectModel.resultSet.sizeCategory: #XS
// 기술부채 '부채 구분' 드롭다운. 도메인 ZDO_DM_DEBT_CAT(CHAR 4) 고정값 — 도메인 이름이 다르면 두 곳만 바꾼다
define view entity ZI_CMSM_DebtCatVH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE( p_domain_name: 'ZDO_DM_DEBT_CAT' ) as Val
    left outer join DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZDO_DM_DEBT_CAT' ) as Txt
      on  Txt.value_position = Val.value_position
      and Txt.language       = $session.system_language
{
      @ObjectModel.text.element: [ 'Text' ]
      @EndUserText.label: '부채 구분'
  key cast( Val.value_low as abap.char( 4 ) ) as Value,
      @Semantics.text: true
      @EndUserText.label: '내역'
      Txt.text as Text
}
