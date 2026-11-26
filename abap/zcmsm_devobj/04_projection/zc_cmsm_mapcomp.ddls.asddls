@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '매핑 구성요소'
@Metadata.allowExtensions: true
@Search.searchable: true
define view entity ZC_CMSM_MapComp
  as projection on ZR_CMSM_MapComp
{
  key CompUuid,
      MapUuid,
      @Search.defaultSearchElement: true
      AsisComp,
      @Search.defaultSearchElement: true
      TobeComp,
      CompDesc,
      LocalLastChangedAt,

      _Map : redirected to parent ZC_CMSM_Map
}
