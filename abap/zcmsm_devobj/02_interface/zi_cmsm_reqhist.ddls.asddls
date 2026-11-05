@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '요청 변경 이력'
define view entity ZI_CMSM_ReqHist
  as select from ztcmsm00180

  association [0..1] to ZI_CMSM_HistKindVH as _HistKind  on $projection.HistKind  = _HistKind.Value
  association [0..1] to ZI_CMSM_UserVH     as _ChangedBy on $projection.ChangedBy = _ChangedBy.UserId
{
      @EndUserText.label: '이력 UUID'
  key histuuid           as HistUuid,
      @EndUserText.label: '요청 UUID'
      requuid            as ReqUuid,
      @EndUserText.label: '변경 일시'
      changedat          as ChangedAt,
      @EndUserText.label: '변경자'
      changedby          as ChangedBy,
      @EndUserText.label: '구분'
      histkind           as HistKind,
      @EndUserText.label: '필드'
      fieldname          as FieldName,
      @EndUserText.label: '이전 값'
      oldvalue           as OldValue,
      @EndUserText.label: '새 값'
      newvalue           as NewValue,
      @EndUserText.label: '사유'
      histnote           as HistNote,
      locallastchangedat as LocalLastChangedAt,

      _HistKind,
      _ChangedBy
}
