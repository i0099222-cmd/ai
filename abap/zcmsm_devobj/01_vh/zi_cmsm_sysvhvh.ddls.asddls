@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '시스템 VH 목록'
@Search.searchable: true
// VH 탭 'VH 이름' 입력용: 이 시스템에 있는 CDS·Search Help 중 Z로 시작하고 이름에 _VH_ 가 들어간 것.
// like 에서 _ 는 한 글자 와일드카드라 # 으로 이스케이프한다. 규칙이 바뀌면 where만 고친다.
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
      ( Obj.ABAPObjectType = 'DDLS' or Obj.ABAPObjectType = 'SHLP' )
  and   Obj.ABAPObject like 'Z%#_VH#_%' escape '#'
