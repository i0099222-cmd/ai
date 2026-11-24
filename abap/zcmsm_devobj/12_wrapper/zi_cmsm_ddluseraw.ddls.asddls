@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CDS 사용처 인덱스 (래퍼 내부용)'
// [Standard ABAP 패키지 · 릴리즈 안 함] ZI_CMSM_DdlUse 만 읽는다.
// 표준 테이블 DDLS_RIS_INDEX(CDS 사용처 인덱스): 'DDL 소스 → 쓰는 오브젝트'
//   USED_ARTIFACT_FULLNAME = '\TY:ZTCMTEST' (SSTRING 400) → CHAR 로 바꾼 뒤 2번째 글자부터 = 'TY:ZTCMTEST'
//   (CDS 문자열 리터럴에 백슬래시를 못 써서 앞의 \ 는 떼고 ZI_CMSM_TadirFull 의 'TY:' + 이름과 비교한다)
//   DdlName 은 DDLSRC_NAME 칸 그대로 — 통합 조회 검색(HANA CONTAINS)은 실제 칸에만 걸린다 (그래서 distinct 도 안 씀)
define view entity ZI_CMSM_DdlUseRaw
  as select from ddls_ris_index
{
  key ddlsrc_name                                                                   as DdlName,
  key cast( substring( cast( used_artifact_fullname as abap.char( 400 ) ), 2, 43 )
            as abap.char( 43 ) )                                                    as UsedFull
}
