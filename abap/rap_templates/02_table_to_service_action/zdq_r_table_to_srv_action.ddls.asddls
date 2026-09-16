@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Case2: 구매주문 헤더 (Root, behavior 대상)'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZDQ_R_TABLE_TO_SRV_ACTION
  as select from ZDQ_I_TABLE_TO_SRV_ACTION as Ord
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

      Ord._Supplier,
      Ord._Plant
}
