@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Case8: 주문-자재별 집계 조회 (Consumption)'
@Metadata.allowExtensions: true
@Search.searchable: true
@UI.headerInfo: { typeName: '주문-자재 집계', typeNamePlural: '주문-자재 집계' }
define view entity ZDQ_C_TABLE_FUNC_TO_SERVICE
  as select from ZDQ_I_TABLE_FUNC_TO_SERVICE as Summary
{
      @UI.facet: [ { id: 'Summary', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
                     label: '집계 상세', position: 10 } ]

      @UI.lineItem      : [ { position: 10 } ]
      @UI.identification: [ { position: 10 } ]
      @UI.selectionField: [ { position: 10 } ]
      @Search.defaultSearchElement: true
  key Summary.OrderId,

      @UI.lineItem      : [ { position: 20 } ]
      @UI.identification: [ { position: 20 } ]
      @UI.selectionField: [ { position: 20 } ]
      @ObjectModel.text.element: [ 'ProductName' ]
  key Summary.Product,

  key Summary.QuantityUnit,
  key Summary.Currency,

      @UI.lineItem      : [ { position: 30 } ]
      @UI.identification: [ { position: 30 } ]
      Summary.ProductName,

      @UI.lineItem      : [ { position: 40 } ]
      @UI.identification: [ { position: 40 } ]
      Summary.TotalQuantity,

      @UI.lineItem      : [ { position: 50 } ]
      @UI.identification: [ { position: 50 } ]
      Summary.TotalAmount,

      @UI.lineItem      : [ { position: 60 } ]
      @UI.identification: [ { position: 60 } ]
      Summary.ItemCount
}
