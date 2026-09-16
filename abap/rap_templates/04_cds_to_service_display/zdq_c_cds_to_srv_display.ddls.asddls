@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Case4: 자재 마스터 조회 (Consumption)'
@Metadata.allowExtensions: true
@Search.searchable: true
@UI.headerInfo: { typeName: '자재', typeNamePlural: '자재',
                  title: { value: 'Product' }, description: { value: 'ProductDescription' } }
@ObjectModel.semanticKey: [ 'Product' ]
define view entity ZDQ_C_CDS_TO_SRV_DISPLAY
  as select from ZDQ_I_CDS_TO_SRV_DISPLAY as Prd
{
      @UI.facet: [ { id: 'Product', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
                     label: '자재 기본정보', position: 10 } ]

      @UI.lineItem      : [ { position: 10 } ]
      @UI.identification: [ { position: 10 } ]
      @UI.selectionField: [ { position: 10 } ]
      @Search.defaultSearchElement: true
      @ObjectModel.text.element: [ 'ProductDescription' ]
  key Prd.Product,

      @UI.lineItem      : [ { position: 20 } ]
      @UI.identification: [ { position: 20 } ]
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      Prd.ProductDescription,

      @UI.lineItem      : [ { position: 30 } ]
      @UI.identification: [ { position: 30 } ]
      @UI.selectionField: [ { position: 20 } ]
      Prd.ProductType,

      @UI.lineItem      : [ { position: 40 } ]
      @UI.identification: [ { position: 40 } ]
      @UI.selectionField: [ { position: 30 } ]
      Prd.ProductGroup,

      @UI.lineItem      : [ { position: 50 } ]
      @UI.identification: [ { position: 50 } ]
      Prd.Division,

      @UI.lineItem      : [ { position: 60 } ]
      @UI.identification: [ { position: 60 } ]
      Prd.BaseUnit,

      @UI.identification: [ { position: 90 } ]
      Prd.CreationDate,
      @UI.identification: [ { position: 91 } ]
      Prd.CreatedByUser
}
