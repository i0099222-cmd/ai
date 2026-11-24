@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'TADIR 이름 (사용처 인덱스 형식)'
// [Standard ABAP 패키지 · 릴리즈 안 함] ZI_CMSM_DdlUse 만 읽는다.
// 테이블·CDS·DDIC 뷰 이름을 사용처 인덱스(DDLS_RIS_INDEX-USED_ARTIFACT_FULLNAME)의 형식 '\TY:<이름>' 으로 만들어 둔다.
//   왜 이쪽에서 만드나: 인덱스 칸을 잘라서(substring) 조인하면 통합 조회 검색(HANA CONTAINS)이 그 자르는 식까지
//   따라가서 덤프(SQL code 7 'contains predicates on expression')가 난다.
//   이름(ObjName)은 TADIR 칸 그대로라 검색이 걸리고, 식(FullName)은 조인에만 쓴다
define view entity ZI_CMSM_TadirFull
  as select from tadir
{
  key object                     as ObjObject,
  key obj_name                   as ObjName,
      concat( '\TY:', obj_name ) as FullName
}
where
       pgmid   = 'R3TR'
  and (    object = 'TABL'
        or object = 'DDLS'
        or object = 'VIEW' )
  and  delflag = ''
