@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '시스템 VH 목록'
@Search.searchable: true
// VH 탭 'VH 이름' 입력용: 이 시스템에 있는 고객 CDS(이름에 VH 포함)와 Search Help.
// VH 이름 규칙이 다르면 where만 고친다.
// 등록번호가 있으면 VH 탭에 이미 등록된 것.
define view entity ZI_CMSM_SysVhVH
  as select from I_CustABAPObjDirectoryEntry as Obj
    left outer to one join ZI_CMSM_Vh as Reg on Reg.VhName = Obj.ABAPObject
{
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @EndUserText.label: 'VH 이름'
  key Obj.ABAPObject     as VhName,
      @EndUserText.label: '오브젝트 유형'
  key Obj.ABAPObjectType as ObjectType,
      @Search.defaultSearchElement: true
      @EndUserText.label: '패키지'
      Obj.ABAPPackage    as Package,
      @EndUserText.label: '등록번호'
      Reg.VhId           as RegisteredVhId
}
where
     ( Obj.ABAPObjectType = 'DDLS' and Obj.ABAPObject like '%VH%' )
  or   Obj.ABAPObjectType = 'SHLP'
