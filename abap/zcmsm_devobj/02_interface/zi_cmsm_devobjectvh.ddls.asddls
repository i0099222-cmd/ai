@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '개발 오브젝트 VH (기술부채용)'
@Search.searchable: true
// 기술부채 탭 '개발 오브젝트' 입력용: 통합 목록(ZI_CMSM_DevObject)에서 As-Is(ECC 오브젝트)를 뺀 것.
// As-Is는 이 시스템 오브젝트가 아니라 기술부채 대상이 아니다.
define view entity ZI_CMSM_DevObjectVH
  as select from ZI_CMSM_DevObject
{
  key SourceUuid,
  key SourceTab,
      SourceId,
      SysId,
      ObjType,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      DevObj,
      SapModule,
      @Search.defaultSearchElement: true
      Description
}
where
  SourceTab <> 'ASIS'
