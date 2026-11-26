@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '매핑 구성요소 (BO 자식)'
define view entity ZR_CMSM_MapComp
  as select from ZI_CMSM_MapComp
  association to parent ZR_CMSM_Map as _Map on $projection.MapUuid = _Map.MapUuid
{
  key CompUuid,
      MapUuid,
      AsisComp,
      TobeComp,
      CompDesc,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      LocalLastChangedAt,

      _Map
}
