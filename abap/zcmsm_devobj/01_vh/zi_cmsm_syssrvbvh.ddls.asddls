@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '시스템 서비스 바인딩 목록'
@Search.searchable: true
// OData 서비스 탭 'Service Binding' 입력용: 이 시스템에 있는 Z로 시작하는 서비스 바인딩(SRVB).
// 규칙이 바뀌면 where만 고친다. 등록번호가 있으면 OData 서비스 탭에 이미 등록된 것.
define view entity ZI_CMSM_SysSrvbVH
  as select from I_CustABAPObjDirectoryEntry as Obj
    left outer to one join ZI_CMSM_Sb as Reg on Reg.SrvbName = Obj.ABAPObject
{
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @EndUserText.label: 'Service Binding'
  key Obj.ABAPObject  as SrvbName,
      @Search.defaultSearchElement: true
      @EndUserText.label: '패키지'
      Obj.ABAPPackage as Package,
      @EndUserText.label: '등록번호'
      Reg.SbId        as RegisteredSbId
}
where
      Obj.ABAPObjectType = 'SRVB'
  and Obj.ABAPObject     like 'Z%'
