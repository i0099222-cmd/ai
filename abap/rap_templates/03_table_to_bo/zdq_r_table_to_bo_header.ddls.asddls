@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Case3: 구매주문 헤더 (Root, behavior 대상)'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZDQ_R_TABLE_TO_BO_HEADER
  as select from ZDQ_I_TABLE_TO_BO_HEADER as Ord

  composition [0..*] of ZDQ_R_TABLE_TO_BO_ITEM as _Item

{
  key Ord.OrderId,

      Ord.OrderDate,
      Ord.Supplier,
      Ord.Plant,
      Ord.OrderStatus,
      Ord.TotalAmount,
      Ord.Currency,

      Ord.CreatedBy,
      Ord.CreatedAt,
      Ord.LastChangedBy,
      Ord.LastChangedAt,
      Ord.LocalLastChangedAt,

      _Item,
      Ord._Supplier,
      Ord._Plant
}
