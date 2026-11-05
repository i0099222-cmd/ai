@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help 데이터 소스'
@Metadata.allowExtensions: true
define view entity ZC_CMSM_VhSrc
  as projection on ZR_CMSM_VhSrc
{
  key SrcUuid,
      VhUuid,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_SrcKindVH', element: 'Value' } }]
      @ObjectModel.text.element: [ 'SrcKindText' ]
      SrcKind,
      @EndUserText.label: '소스 유형 내역'
      _SrcKind.Text as SrcKindText,
      SrcName,
      LocalLastChangedAt,

      _Vh : redirected to parent ZC_CMSM_Vh
}
