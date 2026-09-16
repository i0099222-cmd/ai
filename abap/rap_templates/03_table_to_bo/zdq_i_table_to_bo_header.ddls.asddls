@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Case3: 구매주문 헤더 (Interface)'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZDQ_I_TABLE_TO_BO_HEADER
  as select from zdq_tordhdr as OrderHeader

  association [0..1] to I_Supplier as _Supplier on $projection.Supplier = _Supplier.Supplier
  association [0..1] to I_Plant    as _Plant    on $projection.Plant    = _Plant.Plant

{
  key OrderHeader.order_id                as OrderId,

      OrderHeader.order_date              as OrderDate,
      OrderHeader.supplier                as Supplier,
      OrderHeader.plant                   as Plant,
      OrderHeader.order_status            as OrderStatus,

      @Semantics.amount.currencyCode: 'Currency'
      OrderHeader.total_amount            as TotalAmount,
      @Semantics.currencyCode: true
      OrderHeader.currency                as Currency,

      @Semantics.user.createdBy: true
      OrderHeader.created_by              as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      OrderHeader.created_at              as CreatedAt,
      @Semantics.user.lastChangedBy: true
      OrderHeader.last_changed_by         as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      OrderHeader.last_changed_at         as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      OrderHeader.local_last_changed_at   as LocalLastChangedAt,

      _Supplier,
      _Plant
}
