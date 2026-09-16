@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Case5: 자재 검토 (Interface, 표준 CDS 원천 + CBO 조인)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZDQ_I_CDS_TO_SRV_ACTION
  as select from I_Product as Product

  -- 표준 CDS 는 읽기 전용이므로, 변경 대상 필드는 CBO 테이블에 둔다.
  left outer join zdq_tprdrev as Review on Review.product = Product.Product

  association [0..1] to I_ProductDescription as _ProductText
    on  $projection.Product   = _ProductText.Product
    and _ProductText.Language = $session.system_language

{
  key Product.Product                     as Product,

      Product.ProductType                 as ProductType,
      Product.ProductGroup                as ProductGroup,
      Product.BaseUnit                    as BaseUnit,

      Review.reviewstatus                 as ReviewStatus,
      Review.reviewnote                   as ReviewNote,

      @Semantics.user.createdBy: true
      Review.created_by                   as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      Review.created_at                   as CreatedAt,
      @Semantics.user.lastChangedBy: true
      Review.last_changed_by              as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      Review.last_changed_at              as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      Review.local_last_changed_at        as LocalLastChangedAt,

      _ProductText
}
