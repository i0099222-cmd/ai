@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CDS가 바로 쓰는 오브젝트'
// [Standard ABAP 패키지 · Cloud 개발용 릴리즈(C1)] 통합 조회 UNION(ZI_CMSM_DevObject)의 소스 줄용.
//   DDL 소스(DdlName) → 그 소스가 바로(1단계) 쓰는 테이블·CDS·DDIC 뷰(UsedName)
//   select from·join·연관을 다 포함하고 쓰는 방식은 구분하지 않는다
//   캐스트에 쓴 데이터 요소 같은 것은 ZI_CMSM_TadirFull(TABL·DDLS·VIEW만)과 안 맞아서 빠진다
// 조인: 인덱스 쪽 'TY:<이름>'(ZI_CMSM_DdlUseRaw.UsedFull) = TADIR 쪽 'TY:<이름>'(ZI_CMSM_TadirFull.FullName) — 식끼리 비교
//   두 이름(DdlName = DDLSRC_NAME, UsedName = TADIR OBJ_NAME)은 실제 칸이고 식과 같다고 묶이지 않는다
//   → 통합 조회 검색(HANA CONTAINS)이 덤프 없이 걸린다
//   (이름 칸을 식과 '=' 로 직접 묶으면 HANA 가 검색을 그 식까지 따라가서 SQL code 7 'contains predicates on expression')
// 릴리즈: ADT → Properties → API State → Use in Cloud Development = Released
// 기술부채로 등록: 개발 오브젝트 ZI_CMSM_DDLUSE, 부채 구분 TAB(미릴리즈 테이블 조회), Debt Level C, 래핑 여부 W
define view entity ZI_CMSM_DdlUse
  as select from ZI_CMSM_DdlUseRaw as Use
    inner join   ZI_CMSM_TadirFull as Obj on Obj.FullName = Use.UsedFull
{
      @EndUserText.label: '쓰는 CDS'
  key Use.DdlName,
      @EndUserText.label: '쓰이는 오브젝트'
  key Obj.ObjName as UsedName,
      @EndUserText.label: '오브젝트 유형'
      cast( case Obj.ObjObject
              when 'TABL' then 'TABLE'
              when 'DDLS' then 'CDS'
              else ''
            end as abap.char( 10 ) ) as ObjType
}
