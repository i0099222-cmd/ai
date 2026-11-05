@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help 데이터 소스'
define view entity ZI_CMSM_VhSrc
  as select from ztcmsm00210

  association [0..1] to ZI_CMSM_SrcKindVH as _SrcKind on $projection.SrcKind = _SrcKind.Value
{
      @EndUserText.label: '소스 UUID'
  key srcuuid            as SrcUuid,
      @EndUserText.label: 'VH UUID'
      vhuuid             as VhUuid,
      @EndUserText.label: '소스 유형'
      srckind            as SrcKind,
      @EndUserText.label: '소스 이름'
      srcname            as SrcName,
      locallastchangedat as LocalLastChangedAt,

      _SrcKind
}
