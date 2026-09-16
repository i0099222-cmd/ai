@EndUserText.label: 'Case7: 자재 검토 (Custom Entity + Action)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_DQ_CE_ACTION_QUERY'
@UI.headerInfo: { typeName: '자재 검토', typeNamePlural: '자재 검토',
                  title: { value: 'Product' }, description: { value: 'ProductDescription' } }
define custom entity ZDQ_CE_CUSTOM_ENT_ACTION
{
      @UI.facet: [ { id: 'Review', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
                     label: '자재 검토정보', position: 10 } ]

      @UI.lineItem      : [ { position: 10 },
                            { type: #FOR_ACTION, dataAction: 'approveReview', label: '검토 승인' } ]
      @UI.identification: [ { position: 10 },
                            { type: #FOR_ACTION, dataAction: 'approveReview', label: '검토 승인' } ]
      @UI.selectionField: [ { position: 10 } ]
  key Product            : matnr;

      @UI.lineItem      : [ { position: 20 } ]
      @UI.identification: [ { position: 20 } ]
      ProductDescription : abap.char(40);

      @UI.lineItem      : [ { position: 30 } ]
      @UI.identification: [ { position: 30 } ]
      @UI.selectionField: [ { position: 20 } ]
      ProductType        : abap.char(4);

      @UI.lineItem      : [ { position: 40 } ]
      @UI.identification: [ { position: 40 } ]
      @UI.selectionField: [ { position: 30 } ]
      ReviewStatus       : abap.char(2);

      @UI.lineItem      : [ { position: 50 } ]
      @UI.identification: [ { position: 50 } ]
      ReviewNote         : abap.char(60);

      @UI.identification: [ { position: 90 } ]
      @Semantics.user.lastChangedBy: true
      LastChangedBy      : abp_lastchange_user;

      @UI.identification: [ { position: 91 } ]
      @Semantics.systemDateTime.lastChangedAt: true
      LastChangedAt      : abp_lastchange_tmstmp;
}
