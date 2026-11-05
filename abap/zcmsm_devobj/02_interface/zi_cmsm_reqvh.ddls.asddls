@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '요청번호 VH'
@Search.searchable: true
// 등록 탭(매핑·VH·SB)의 요청번호 입력용
define view entity ZI_CMSM_ReqVH
  as select from ZI_CMSM_Req
{
      @ObjectModel.text.element: [ 'Title' ]
      @Search.defaultSearchElement: true
  key ReqId,
      @Semantics.text: true
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      Title,
      @ObjectModel.text.element: [ 'ReqStatusText' ]
      ReqStatus,
      _ReqStatus.Text as ReqStatusText,
      CreatedBy
}
where
  ReqId <> ''
