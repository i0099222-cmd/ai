@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CDS 사용처 인덱스 (래퍼 내부용)'
// [Standard ABAP 패키지 · 릴리즈 안 함] ZI_CMSM_DdlUse 만 읽는다.
// 표준 테이블 DDLS_RIS_INDEX(CDS 사용처 인덱스)에서 'DDL 소스 → 그 소스가 쓰는 이름'.
//   USED_ARTIFACT_FULLNAME = '\TY:ZTCMTEST' → 5번째 글자부터가 이름
//   (뒤에 \… 가 더 붙은 줄은 이름이 이상해져서 ZI_CMSM_DdlUse 의 TADIR 조인에서 빠진다)
// USED_ARTIFACT_FULLNAME 이 긴 문자열(STRING) 타입이라 substring 이 에러면 SE11 에서 타입을 알려 주세요.
define view entity ZI_CMSM_DdlUseRaw
  as select distinct from ddls_ris_index
{
  key ddlsrc_name                                                           as DdlName,
  key cast( substring( used_artifact_fullname, 5, 40 ) as abap.char( 40 ) ) as UsedName
}
where
  used_artifact_fullname like '\TY:%'
