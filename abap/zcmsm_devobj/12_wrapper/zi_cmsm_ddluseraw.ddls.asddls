@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CDS 사용처 인덱스 (래퍼 내부용)'
// [Standard ABAP 패키지 · 릴리즈 안 함] ZI_CMSM_DdlUse 만 읽는다.
// 표준 테이블 DDLS_RIS_INDEX(CDS 사용처 인덱스)에서 'DDL 소스 → 그 소스가 쓰는 이름'.
//   USED_ARTIFACT_FULLNAME = '\TY:ZTCMTEST' → 5번째 글자부터가 이름
//   USED_ARTIFACT_FULLNAME 은 SSTRING(400) → 먼저 CHAR(400)으로 바꾼 뒤 자른다 (문자열 함수가 SSTRING 을 못 받아서)
//   '\TY:' 로 시작하는지는 따로 안 본다: 다른 형태의 줄이나 뒤에 \… 가 더 붙은 줄은 이름이 이상해져서
//   ZI_CMSM_DdlUse 의 TADIR 조인(TABL·DDLS·VIEW)에서 저절로 빠진다
define view entity ZI_CMSM_DdlUseRaw
  as select distinct from ddls_ris_index
{
  key ddlsrc_name                                                                   as DdlName,
  key cast( substring( cast( used_artifact_fullname as abap.char( 400 ) ), 5, 40 )
            as abap.char( 40 ) )                                                    as UsedName
}
