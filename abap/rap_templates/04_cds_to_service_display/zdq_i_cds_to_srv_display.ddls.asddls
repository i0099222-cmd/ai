@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Case4: 자재 마스터 (Interface, 표준 CDS 원천)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZDQ_I_CDS_TO_SRV_DISPLAY
  as select from I_Product as Product

  association [0..1] to I_ProductDescription as _ProductText
    on  $projection.Product   = _ProductText.Product
    and _ProductText.Language = $session.system_language

{
  key Product.Product                     as Product,

      Product.ProductType                 as ProductType,
      Product.ProductGroup                as ProductGroup,
      Product.Division                    as Division,
      Product.BaseUnit                    as BaseUnit,
      Product.CreationDate                as CreationDate,
      Product.CreatedByUser               as CreatedByUser,

      _ProductText.ProductDescription     as ProductDescription,

      _ProductText
}
