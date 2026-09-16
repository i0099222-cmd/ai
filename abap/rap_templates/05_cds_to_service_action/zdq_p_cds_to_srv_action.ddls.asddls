@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Case5: 자재 검토 (Projection)'
@Metadata.allowExtensions: true
@Search.searchable: true
@UI.headerInfo: { typeName: '자재 검토', typeNamePlural: '자재 검토',
                  title: { value: 'Product' }, description: { value: 'ProductDescription' } }
@ObjectModel.semanticKey: [ 'Product' ]
define root view entity ZDQ_P_CDS_TO_SRV_ACTION
  provider contract transactional_query
  as projection on ZDQ_R_CDS_TO_SRV_ACTION
{
      @UI.facet: [ { id: 'Review', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
                     label: '자재 검토정보', position: 10 } ]

      @UI.lineItem      : [ { position: 10 },
                            { type: #FOR_ACTION, dataAction: 'approveReview', label: '검토 승인' } ]
      @UI.identification: [ { position: 10 },
                            { type: #FOR_ACTION, dataAction: 'approveReview', label: '검토 승인' } ]
      @UI.selectionField: [ { position: 10 } ]
      @Search.defaultSearchElement: true
      @ObjectModel.text.element: [ 'ProductDescription' ]
  key Product,

      @UI.hidden: true
      _ProductText.ProductDescription as ProductDescription,

      @UI.lineItem      : [ { position: 20 } ]
      @UI.identification: [ { position: 20 } ]
      @UI.selectionField: [ { position: 20 } ]
      ProductType,

      @UI.lineItem      : [ { position: 30 } ]
      @UI.identification: [ { position: 30 } ]
      ProductGroup,

      @UI.lineItem      : [ { position: 40 } ]
      @UI.identification: [ { position: 40 } ]
      BaseUnit,

      @UI.lineItem      : [ { position: 50 } ]
      @UI.identification: [ { position: 50 } ]
      @UI.selectionField: [ { position: 30 } ]
      ReviewStatus,

      @UI.lineItem      : [ { position: 60 } ]
      @UI.identification: [ { position: 60 } ]
      ReviewNote,

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
