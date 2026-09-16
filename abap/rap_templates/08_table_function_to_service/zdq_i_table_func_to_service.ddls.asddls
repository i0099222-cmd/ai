@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Case8: 주문-자재별 집계 (Interface)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZDQ_I_TABLE_FUNC_TO_SERVICE
  as select from ZDQ_TF_TABLE_FUNC_TO_SERVICE as Summary

  association [0..1] to I_Product as _Product on $projection.Product = _Product.Product

{
      // 단위·통화까지 포함해야 키가 유일해진다.
  key Summary.orderid                     as OrderId,
  key Summary.product                     as Product,
  key Summary.quantityunit                as QuantityUnit,
  key Summary.currency                    as Currency,

      Summary.productname                 as ProductName,

      @Semantics.quantity.unitOfMeasure: 'QuantityUnit'
      Summary.totalqty                    as TotalQuantity,
      @Semantics.amount.currencyCode: 'Currency'
      Summary.totalamount                 as TotalAmount,

      Summary.itemcount                   as ItemCount,

      _Product
}
