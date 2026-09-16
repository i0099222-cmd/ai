@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Case3: 구매주문 아이템 (Root 하위)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZDQ_R_TABLE_TO_BO_ITEM
  as select from ZDQ_I_TABLE_TO_BO_ITEM as Itm

  association to parent ZDQ_R_TABLE_TO_BO_HEADER as _Header
    on $projection.OrderId = _Header.OrderId

{
  key Itm.OrderId,
  key Itm.ItemNo,

      Itm.Product,
      Itm.Quantity,
      Itm.QuantityUnit,
      Itm.NetAmount,
      Itm.Currency,
      Itm.DeliveryDate,

      Itm.CreatedBy,
      Itm.CreatedAt,
      Itm.LastChangedBy,
      Itm.LastChangedAt,
      Itm.LocalLastChangedAt,

      _Header,
      Itm._Product,
      Itm._ProductText
}
