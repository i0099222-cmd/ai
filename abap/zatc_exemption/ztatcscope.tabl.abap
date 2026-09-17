@EndUserText.label : 'ATC 체크그룹별 적용범위 허용 매트릭스 (설정)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
define table ztatcscope {

  key client     : abap.clnt not null;

  key checkgroup : abap.char(10) not null;

  "! FND / OBJ / PKG
  key scopetype  : abap.char(3) not null;

  "! 이 조합의 사용 허용 여부.
  "! Phase 1 초기 데이터: (NAMING, FND) = 공란, (NAMING, OBJ) = X, (NAMING, PKG) = X
  "! -> 요건 "패키지/오브젝트 단위로만 등록" 이 코드 변경 없이 충족된다.
  activeflg      : abap_boolean;

  "! 승인에 필요한 권한 레벨. 권한 오브젝트 ACTVT/필드와 매핑해 사용한다.
  "! 예: 1 팀리더 / 2 아키텍트 / 3 보안담당
  apprlevel      : abap.int1;

  "! 최대 유효기간(개월). 무기한 예외를 막는다.
  maxvalidmon    : abap.int2;

  "! 사유 코드/근거 텍스트 필수 여부
  reasonreq      : abap_boolean;

  include zscm00010;

}
