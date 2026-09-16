@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Case1: 구매주문 헤더 조회 (Consumption)'
@Metadata.allowExtensions: true
@Search.searchable: true
@UI.headerInfo: { typeName: '구매주문', typeNamePlural: '구매주문', title: { value: 'OrderId' } }
@ObjectModel.semanticKey: [ 'OrderId' ]
define view entity ZDQ_C_TABLE_TO_SERVICE
  as select from ZDQ_I_TABLE_TO_SERVICE as Ord
{
      @UI.facet: [ { id: 'Header', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
                     label: '주문 기본정보', position: 10 } ]

      // 기술 키는 화면에 노출하지 않고 업무 키(OrderId)를 semanticKey 로 보여준다.
      @UI.hidden: true
  key Ord.OrderUUID,

      @UI.lineItem      : [ { position: 10 } ]
      @UI.identification: [ { position: 10 } ]
      @UI.selectionField: [ { position: 10 } ]
      @Search.defaultSearchElement: true
      Ord.OrderId,

      @UI.lineItem      : [ { position: 20 } ]
      @UI.identification: [ { position: 20 } ]
      @UI.selectionField: [ { position: 20 } ]
      Ord.OrderDate,

      @UI.lineItem      : [ { position: 30 } ]
      @UI.identification: [ { position: 30 } ]
      @UI.selectionField: [ { position: 30 } ]
      @ObjectModel.text.element: [ 'SupplierName' ]
      Ord.Supplier,

      @UI.hidden: true
      Ord._Supplier.SupplierName as SupplierName,

      @UI.lineItem      : [ { position: 40 } ]
      @UI.identification: [ { position: 40 } ]
      @UI.selectionField: [ { position: 40 } ]
      @ObjectModel.text.element: [ 'PlantName' ]
      Ord.Plant,

      @UI.hidden: true
      Ord._Plant.PlantName       as PlantName,

      @UI.lineItem      : [ { position: 50 } ]
      @UI.identification: [ { position: 50 } ]
      Ord.OrderStatus,

      @UI.lineItem      : [ { position: 60 } ]
      @UI.identification: [ { position: 60 } ]
      Ord.TotalAmount,
      Ord.Currency,

      @UI.identification: [ { position: 90 } ]
      Ord.CreatedBy,
      @UI.identification: [ { position: 91 } ]
      Ord.CreatedAt,
      @UI.identification: [ { position: 92 } ]
      Ord.LastChangedBy,
      @UI.identification: [ { position: 93 } ]
      Ord.LastChangedAt
}
