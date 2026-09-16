@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Case3: 구매주문 아이템 (Projection)'
@Metadata.allowExtensions: true
@UI.headerInfo: { typeName: '주문 아이템', typeNamePlural: '주문 아이템', title: { value: 'ItemNo' } }
define view entity ZDQ_P_TABLE_TO_BO_ITEM
  provider contract transactional_query
  as projection on ZDQ_R_TABLE_TO_BO_ITEM
{
      @UI.facet: [ { id: 'Item', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
                     label: '아이템 상세', position: 10 } ]

      @UI.lineItem      : [ { position: 10 } ]
      @UI.identification: [ { position: 10 } ]
  key OrderId,

      @UI.lineItem      : [ { position: 20 } ]
      @UI.identification: [ { position: 20 } ]
  key ItemNo,

      @UI.lineItem      : [ { position: 30 } ]
      @UI.identification: [ { position: 30 } ]
      @ObjectModel.text.element: [ 'ProductDescription' ]
      Product,

      @UI.hidden: true
      _ProductText.ProductDescription as ProductDescription,

      @UI.lineItem      : [ { position: 40 } ]
      @UI.identification: [ { position: 40 } ]
      Quantity,
      QuantityUnit,

      @UI.lineItem      : [ { position: 50 } ]
      @UI.identification: [ { position: 50 } ]
      NetAmount,
      Currency,

      @UI.lineItem      : [ { position: 60 } ]
      @UI.identification: [ { position: 60 } ]
      DeliveryDate,

      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,
      LocalLastChangedAt,

      _Header : redirected to parent ZDQ_P_TABLE_TO_BO_HEADER
}
