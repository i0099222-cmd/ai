@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CDS가 바로 쓰는 오브젝트'
// [Standard ABAP 패키지 · Cloud 개발용 릴리즈(C1)] 통합 조회 UNION(ZI_CMSM_DevObject)의 소스 줄용.
//   DDL 소스(DdlName) → 그 소스가 바로(1단계) 쓰는 테이블·CDS·DDIC 뷰(UsedName)
//   select from·join·연관을 다 포함하고 쓰는 방식은 구분하지 않는다
//   캐스트에 쓴 데이터 요소 같은 것은 ZI_CMSM_TadirFull(TABL·DDLS·VIEW만)과 안 맞아서 빠진다
// 조인: 인덱스 칸(USED_ARTIFACT_FULLNAME, SSTRING)은 그대로 두고 TADIR 쪽에서 만든 '\TY:<이름>' 과 비교한다.
//   두 이름(DdlName·UsedName)은 실제 칸(DDLSRC_NAME, TADIR OBJ_NAME) — 통합 조회 검색(HANA CONTAINS)은 실제 칸에만 걸린다
// 릴리즈: ADT → Properties → API State → Use in Cloud Development = Released
// 기술부채로 등록: 개발 오브젝트 ZI_CMSM_DDLUSE, 부채 구분 TAB(미릴리즈 테이블 조회), Debt Level C, 래핑 여부 W
define view entity ZI_CMSM_DdlUse
  as select from ddls_ris_index    as Idx
    inner join   ZI_CMSM_TadirFull as Obj on Obj.FullName = Idx.used_artifact_fullname
{
      @EndUserText.label: '쓰는 CDS'
  key Idx.ddlsrc_name as DdlName,
      @EndUserText.label: '쓰이는 오브젝트'
  key Obj.ObjName     as UsedName,
      @EndUserText.label: '오브젝트 유형'
      cast( case Obj.ObjObject
              when 'TABL' then 'TABLE'
              when 'DDLS' then 'CDS'
              else ''
            end as abap.char( 10 ) ) as ObjType
}
