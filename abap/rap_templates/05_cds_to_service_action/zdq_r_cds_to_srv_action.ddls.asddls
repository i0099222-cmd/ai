@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Case5: 자재 검토 (Root, behavior 대상)'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZDQ_R_CDS_TO_SRV_ACTION
  as select from ZDQ_I_CDS_TO_SRV_ACTION as Rev
{
  key Rev.Product,

      Rev.ProductType,
      Rev.ProductGroup,
      Rev.BaseUnit,
      Rev.ReviewStatus,
      Rev.ReviewNote,

      Rev.CreatedBy,
      Rev.CreatedAt,
      Rev.LastChangedBy,
      Rev.LastChangedAt,
      Rev.LocalLastChangedAt,

      Rev._ProductText
}
