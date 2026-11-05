@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help'
define view entity ZI_CMSM_Vh
  as select from ztcmsm00200

  association [0..1] to ZI_CMSM_VhImplVH as _VhImpl    on $projection.VhImpl    = _VhImpl.Value
  association [0..1] to ZI_CMSM_SysId    as _Sys       on $projection.SysId     = _Sys.SysId
  association [0..1] to ZI_CMSM_ModuleVH as _SapModule on $projection.SapModule = _SapModule.Value
  association [0..1] to ZI_CMSM_UserVH   as _Owner     on $projection.OwnerId   = _Owner.UserId
  association [0..1] to ZI_CMSM_ReqVH    as _Request   on $projection.ReqId     = _Request.ReqId
  association [0..1] to ZI_CMSM_UserVH   as _TestBy    on $projection.TestBy    = _TestBy.UserId
{
      @EndUserText.label: 'VH UUID'
  key vhuuid             as VhUuid,
      @EndUserText.label: '등록번호'
      vhid               as VhId,
      @EndUserText.label: 'VH 이름'
      vhname             as VhName,
      @EndUserText.label: '구현 방식'
      vhimpl             as VhImpl,
      @EndUserText.label: '시스템 ID'
      sysid              as SysId,
      @EndUserText.label: '모듈'
      sapmodule          as SapModule,
      @EndUserText.label: '설명'
      description        as Description,
      @EndUserText.label: '담당자'
      ownerid            as OwnerId,
      @EndUserText.label: '오브젝트 생성자'
      objcreator         as ObjCreator,
      @EndUserText.label: '요청번호'
      reqid              as ReqId,
      @EndUserText.label: '테스트 파일'
      testfile           as TestFile,
      @EndUserText.label: 'MIME 타입'
      testmimetype       as TestMimeType,
      @EndUserText.label: '파일명'
      testfilename       as TestFileName,
      @EndUserText.label: '올린 사람'
      testby             as TestBy,
      // abap.dec(21,7) 그대로면 OData에서 숫자로 보여서 타임스탬프 타입으로 바꿈
      @EndUserText.label: '올린 일시'
      cast( testat as timestampl preserving type ) as TestAt,
      @EndUserText.label: '등록자'
      createdby          as CreatedBy,
      @EndUserText.label: '등록 일시'
      createdat          as CreatedAt,
      @EndUserText.label: '최종 변경자'
      lastchangedby      as LastChangedBy,
      @EndUserText.label: '최종 변경 일시'
      lastchangedat      as LastChangedAt,
      locallastchangedat as LocalLastChangedAt,

      _VhImpl,
      _Sys,
      _SapModule,
      _Owner,
      _Request,
      _TestBy
}
