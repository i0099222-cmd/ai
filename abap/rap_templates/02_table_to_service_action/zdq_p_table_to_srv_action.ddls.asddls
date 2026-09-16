@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Case2: 구매주문 헤더 (Projection)'
@Metadata.allowExtensions: true
@Search.searchable: true
@UI.headerInfo: { typeName: '구매주문', typeNamePlural: '구매주문', title: { value: 'OrderId' } }
@ObjectModel.semanticKey: [ 'OrderId' ]
define root view entity ZDQ_P_TABLE_TO_SRV_ACTION
  provider contract transactional_query
  as projection on ZDQ_R_TABLE_TO_SRV_ACTION
{
      @UI.facet: [ { id: 'Header', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
                     label: '주문 기본정보', position: 10 } ]

      @UI.hidden: true
  key OrderUUID,

      @UI.lineItem      : [ { position: 10 },
                            { type: #FOR_ACTION, dataAction: 'releaseOrder', label: '릴리즈' },
                            { type: #FOR_ACTION, dataAction: 'changeStatus', label: '상태변경' } ]
      @UI.identification: [ { position: 10 },
                            { type: #FOR_ACTION, dataAction: 'releaseOrder', label: '릴리즈' },
                            { type: #FOR_ACTION, dataAction: 'changeStatus', label: '상태변경' } ]
      @UI.selectionField: [ { position: 10 } ]
      @Search.defaultSearchElement: true
      OrderId,

      @UI.lineItem      : [ { position: 20 } ]
      @UI.identification: [ { position: 20 } ]
      @UI.selectionField: [ { position: 20 } ]
      OrderDate,

      @UI.lineItem      : [ { position: 30 } ]
      @UI.identification: [ { position: 30 } ]
      @UI.selectionField: [ { position: 30 } ]
      @ObjectModel.text.element: [ 'SupplierName' ]
      Supplier,

      @UI.hidden: true
      _Supplier.SupplierName as SupplierName,

      @UI.lineItem      : [ { position: 40 } ]
      @UI.identification: [ { position: 40 } ]
      Plant,

      @UI.lineItem      : [ { position: 50 } ]
      @UI.identification: [ { position: 50 } ]
      @UI.selectionField: [ { position: 40 } ]
      OrderStatus,

      @UI.lineItem      : [ { position: 60 } ]
      @UI.identification: [ { position: 60 } ]
      TotalAmount,
      Currency,

      @UI.identification: [ { position: 90 } ]
      CreatedBy,
      @UI.identification: [ { position: 91 } ]
      CreatedAt,
      @UI.identification: [ { position: 92 } ]
      LastChangedBy,
      @UI.identification: [ { position: 93 } ]
      LastChangedAt,

      LocalLastChangedAt
}
