@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '요청 변경 이력'
@Metadata.allowExtensions: true
define view entity ZC_CMSM_ReqHist
  as projection on ZR_CMSM_ReqHist
{
  key HistUuid,
      ReqUuid,
      ChangedAt,
      @ObjectModel.text.element: [ 'ChangedByName' ]
      ChangedBy,
      @EndUserText.label: '변경자 이름'
      _ChangedBy.PersonFullName as ChangedByName,
      @ObjectModel.text.element: [ 'HistKindText' ]
      HistKind,
      @EndUserText.label: '구분 내역'
      _HistKind.Text as HistKindText,
      FieldName,
      OldValue,
      NewValue,
      HistNote,
      LocalLastChangedAt,

      _Req : redirected to parent ZC_CMSM_Req
}
