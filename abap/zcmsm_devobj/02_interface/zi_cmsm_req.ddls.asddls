@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '요청'
define view entity ZI_CMSM_Req
  as select from ztcmsm00170

  association [0..1] to ZI_CMSM_ModuleVH    as _SapModule on $projection.SapModule = _SapModule.Value
  association [0..1] to ZI_CMSM_ReqStatusVH as _ReqStatus on $projection.ReqStatus = _ReqStatus.Value
  association [0..1] to ZI_CMSM_UserVH      as _Assignee  on $projection.Assignee  = _Assignee.UserId
  association [0..1] to ZI_CMSM_UserVH      as _CreatedBy on $projection.CreatedBy = _CreatedBy.UserId
{
      @EndUserText.label: '요청 UUID'
  key requuid            as ReqUuid,
      @EndUserText.label: '요청번호'
      reqid              as ReqId,
      @EndUserText.label: '제목'
      title              as Title,
      @EndUserText.label: '요청 내용'
      reqtext            as ReqText,
      @EndUserText.label: '모듈'
      sapmodule          as SapModule,
      @EndUserText.label: '담당자'
      assignee           as Assignee,
      @EndUserText.label: '상태'
      reqstatus          as ReqStatus,
      @EndUserText.label: '처리 내용'
      procresult         as ProcResult,
      @EndUserText.label: '관련 등록번호'
      relno              as RelNo,
      @EndUserText.label: '완료일'
      donedate           as DoneDate,
      @EndUserText.label: '반려·취소 사유'
      closereason        as CloseReason,
      @EndUserText.label: '요청자'
      createdby          as CreatedBy,
      @EndUserText.label: '요청 일시'
      createdat          as CreatedAt,
      @EndUserText.label: '최종 변경자'
      lastchangedby      as LastChangedBy,
      @EndUserText.label: '최종 변경 일시'
      lastchangedat      as LastChangedAt,
      locallastchangedat as LocalLastChangedAt,

      _SapModule,
      _ReqStatus,
      _Assignee,
      _CreatedBy
}
