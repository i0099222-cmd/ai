@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '시스템 서비스 바인딩 목록'
@Search.searchable: true
// OData 서비스 탭 'Service Binding' 입력용: 이 시스템에 있는 Z로 시작하는 서비스 바인딩(SRVB).
// 규칙이 바뀌면 where만 고친다. 등록번호가 있으면 OData 서비스 탭에 이미 등록된 것.
// 모듈: 이름의 Z 다음부터 첫 '_' 앞까지 (2·3글자). 고르면 OData 서비스의 모듈에 들어간다 (additionalBinding)
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
      @EndUserText.label: '모듈'
      cast( case
              when substring( Obj.ABAPObject, 4, 1 ) = '_' then substring( Obj.ABAPObject, 2, 2 )  // ZCM_0000 → CM
              when substring( Obj.ABAPObject, 5, 1 ) = '_' then substring( Obj.ABAPObject, 2, 3 )  // ZEWM_01  → EWM
              else ''
            end as abap.char( 4 ) ) as SapModule,
      @EndUserText.label: '등록번호'
      Reg.SbId        as RegisteredSbId
}
where
      Obj.ABAPObjectType = 'SRVB'
  and Obj.ABAPObject     like 'Z%'
