@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help 데이터 소스 (BO 자식)'
define view entity ZR_CMSM_VhSrc
  as select from ZI_CMSM_VhSrc
  association to parent ZR_CMSM_Vh as _Vh on $projection.VhUuid = _Vh.VhUuid
{
  key SrcUuid,
      VhUuid,
      SrcKind,
      SrcName,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      LocalLastChangedAt,

      _Vh,
      _SrcKind
}
