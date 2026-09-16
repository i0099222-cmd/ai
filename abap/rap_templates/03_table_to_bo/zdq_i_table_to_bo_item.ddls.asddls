@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Case3: 구매주문 아이템 (Interface)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZDQ_I_TABLE_TO_BO_ITEM
  as select from zdq_torditm as OrderItem

  association [0..1] to I_Product as _Product on $projection.Product = _Product.Product

  association [0..1] to I_ProductDescription as _ProductText
    on  $projection.Product   = _ProductText.Product
    and _ProductText.Language = $session.system_language

{
  key OrderItem.orderuuid                 as OrderUUID,
  key OrderItem.itemuuid                  as ItemUUID,

      OrderItem.itemno                    as ItemNo,
      OrderItem.product                   as Product,

      @Semantics.quantity.unitOfMeasure: 'QuantityUnit'
      OrderItem.quantity                  as Quantity,
      @Semantics.unitOfMeasure: true
      OrderItem.quantityunit              as QuantityUnit,

      @Semantics.amount.currencyCode: 'Currency'
      OrderItem.netamount                 as NetAmount,
      @Semantics.currencyCode: true
      OrderItem.currency                  as Currency,

      OrderItem.deliverydate              as DeliveryDate,

      @Semantics.user.createdBy: true
      OrderItem.created_by                as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      OrderItem.created_at                as CreatedAt,
      @Semantics.user.lastChangedBy: true
      OrderItem.last_changed_by           as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      OrderItem.last_changed_at           as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      OrderItem.local_last_changed_at     as LocalLastChangedAt,

      _Product,
      _ProductText
}
