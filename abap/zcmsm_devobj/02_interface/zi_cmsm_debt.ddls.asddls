@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '기술부채'
define view entity ZI_CMSM_Debt
  as select from ztcmsm00230

  association [0..1] to ZI_CMSM_ModuleVH    as _SapModule     on $projection.SapModule     = _SapModule.Value
  association [0..1] to ZI_CMSM_ObjTypeVH   as _ObjType       on $projection.ObjType       = _ObjType.Value
  association [0..1] to ZI_CMSM_WrapTypeVH  as _WrapType      on $projection.WrapType      = _WrapType.Value
  association [0..1] to ZI_CMSM_SysId       as _Sys           on $projection.SysId         = _Sys.SysId
  association [0..1] to ZI_CMSM_DebtLevelVH as _DebtLevel     on $projection.DebtLevel     = _DebtLevel.Value
  association [0..1] to ZI_CMSM_ImproveVH   as _ImproveStatus on $projection.ImproveStatus = _ImproveStatus.Value
  association [0..1] to ZI_CMSM_UserVH      as _BizOwner      on $projection.BizOwner      = _BizOwner.UserId
{
      @EndUserText.label: '기술부채 UUID'
  key debtuuid           as DebtUuid,
      @EndUserText.label: 'ID'
      debtid             as DebtId,
      @EndUserText.label: '모듈'
      sapmodule          as SapModule,
      @EndUserText.label: '개발 ID'
      devid              as DevId,
      @EndUserText.label: '오브젝트 유형'
      objtype            as ObjType,
      @EndUserText.label: '개발 오브젝트'
      devobj             as DevObj,
      @EndUserText.label: '래핑 여부'
      wraptype           as WrapType,
      @EndUserText.label: '시스템 ID'
      sysid              as SysId,
      @EndUserText.label: '비released 사용 내역'
      @EndUserText.quickInfo: '사용한 비released 오브젝트와 용도. 예) BSEG(TABLE) 조회, BAPI_ACC_DOCUMENT_POST(FM) 호출'
      debtdesc           as DebtDesc,
      @EndUserText.label: 'Debt Level'
      debtlevel          as DebtLevel,
      @EndUserText.label: '개선상태'
      improvestatus      as ImproveStatus,
      @EndUserText.label: '판단 사유·개선 계획'
      debtreason         as DebtReason,
      @EndUserText.label: '업무담당자'
      bizowner           as BizOwner,
      @EndUserText.label: '등록자'
      createdby          as CreatedBy,
      @EndUserText.label: '등록 일시'
      createdat          as CreatedAt,
      @EndUserText.label: '최종 변경자'
      lastchangedby      as LastChangedBy,
      @EndUserText.label: '최종 변경 일시'
      lastchangedat      as LastChangedAt,
      locallastchangedat as LocalLastChangedAt,

      _SapModule,
      _ObjType,
      _WrapType,
      _Sys,
      _DebtLevel,
      _ImproveStatus,
      _BizOwner
}
