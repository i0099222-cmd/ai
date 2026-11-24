@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'TADIR 이름 (사용처 인덱스 형식)'
// [Standard ABAP 패키지 · 릴리즈 안 함] ZI_CMSM_DdlUse 만 읽는다.
// 테이블·CDS·DDIC 뷰 이름 + 사용처 인덱스 형식에서 앞의 \ 를 뗀 'TY:<이름>' (FullName, 조인용)
//   (CDS 문자열 리터럴에 백슬래시를 못 써서 'TY:' 만 붙인다. 인덱스 쪽도 \ 를 떼서 맞춘다 — ZI_CMSM_DdlUseRaw)
//   ObjName 은 TADIR 칸 그대로 — 통합 조회 검색(HANA CONTAINS)은 실제 칸에만 걸린다
define view entity ZI_CMSM_TadirFull
  as select from tadir
{
  key object                   as ObjObject,
  key obj_name                 as ObjName,
      concat( 'TY:', obj_name ) as FullName
}
where
       pgmid   = 'R3TR'
  and (    object = 'TABL'
        or object = 'DDLS'
        or object = 'VIEW' )
  and  delflag = ''
