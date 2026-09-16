@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Case8: 주문-자재별 집계 (Interface)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZDQ_I_TABLE_FUNC_TO_SERVICE
  as select from ZDQ_TF_TABLE_FUNC_TO_SERVICE as Summary

  association [0..1] to I_Product as _Product on $projection.Product = _Product.Product

{
      // 단위·통화까지 포함해야 키가 유일해진다.
  key Summary.order_id                    as OrderId,
  key Summary.product                     as Product,
  key Summary.quantity_unit               as QuantityUnit,
  key Summary.currency                    as Currency,

      Summary.product_name                as ProductName,

      @Semantics.quantity.unitOfMeasure: 'QuantityUnit'
      Summary.total_qty                   as TotalQuantity,
      @Semantics.amount.currencyCode: 'Currency'
      Summary.total_amount                as TotalAmount,

      Summary.item_count                  as ItemCount,

      _Product
}
