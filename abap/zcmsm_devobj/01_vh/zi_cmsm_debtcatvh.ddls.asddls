@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '부채 구분 VH'
@ObjectModel.resultSet.sizeCategory: #XS
// 기술부채 '부채 구분' 드롭다운. 도메인 ZDO_DM_DEBT_CAT(CHAR 4) 고정값 — 도메인 이름이 다르면 두 곳만 바꾼다
define view entity ZI_CMSM_DebtCatVH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE( p_domain_name: 'ZDO_DM_DEBT_CAT' ) as Val
    left outer join DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZDO_DM_DEBT_CAT' ) as Txt
      on  Txt.value_position = Val.value_position
      and Txt.language       = $session.system_language
    // 로그온 언어 텍스트가 없으면 한국어(언어 키 '3', 원본 언어)로 — 영어 로그온이어도 빈 값이 안 되게
    left outer join DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name: 'ZDO_DM_DEBT_CAT' ) as TxtKo
      on  TxtKo.value_position = Val.value_position
      and TxtKo.language       = '3'
{
      @ObjectModel.text.element: [ 'Text' ]
      @EndUserText.label: '부채 구분'
  key cast( Val.value_low as abap.char( 4 ) ) as Value,
      @Semantics.text: true
      @EndUserText.label: '내역'
      coalesce( Txt.text, TxtKo.text ) as Text
}
