@EndUserText.label: 'Case6: 주문 아이템 현황 (Custom Entity, 조회 전용)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_DQ_CE_DISPLAY_QUERY'
@UI.headerInfo: { typeName: '주문 아이템', typeNamePlural: '주문 아이템' }
define custom entity ZDQ_CE_CUSTOM_ENT_DISPLAY
{
      @UI.facet: [ { id: 'Item', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
                     label: '아이템 상세', position: 10 } ]

      @UI.lineItem      : [ { position: 10 } ]
      @UI.identification: [ { position: 10 } ]
      @UI.selectionField: [ { position: 10 } ]
  key OrderId            : abap.char(10);

      @UI.lineItem      : [ { position: 20 } ]
      @UI.identification: [ { position: 20 } ]
  key ItemNo             : abap.numc(5);

      @UI.lineItem      : [ { position: 30 } ]
      @UI.identification: [ { position: 30 } ]
      @UI.selectionField: [ { position: 20 } ]
      Product            : matnr;

      @UI.lineItem      : [ { position: 40 } ]
      @UI.identification: [ { position: 40 } ]
      ProductDescription : abap.char(40);

      @UI.lineItem      : [ { position: 50 } ]
      @UI.identification: [ { position: 50 } ]
      @Semantics.quantity.unitOfMeasure: 'QuantityUnit'
      Quantity           : abap.quan(13,3);

      @Semantics.unitOfMeasure: true
      QuantityUnit       : meins;

      @UI.lineItem      : [ { position: 60 } ]
      @UI.identification: [ { position: 60 } ]
      @Semantics.amount.currencyCode: 'Currency'
      NetAmount          : abap.curr(15,2);

      @Semantics.currencyCode: true
      Currency           : waers;

      @UI.lineItem      : [ { position: 70 } ]
      @UI.identification: [ { position: 70 } ]
      DeliveryDate       : abap.dats;
}
