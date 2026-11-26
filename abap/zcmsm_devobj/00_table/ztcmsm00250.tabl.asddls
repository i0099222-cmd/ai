@EndUserText.label : '매핑 구성요소 (메서드·필드 등 하위 단위 매핑)'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
// 매핑(ztcmsm00190) 한 건 아래 여러 줄: As-Is 클래스의 메서드가 To-Be 에서 이름이 바뀌는 경우 등
// 테이블 번호 00250 은 가정 (딕셔너리 순서상 다음 번호). 다르면 이 이름과 ZI_CMSM_MapComp·BDEF 의 테이블 이름만 바꾼다
// 드래프트 테이블 ztcmsm00250_d 는 R BDEF 의 'draft table ztcmsm00250_d' 에서 ADT 빠른 수정(Ctrl+1)으로 만든다
define table ztcmsm00250 {
  key client             : abap.clnt not null;
  key compuuid           : sysuuid_x16 not null;
  mapuuid                : sysuuid_x16;
  asiscomp               : abap.char(80);
  tobecomp               : abap.char(80);
  compdesc               : abap.char(255);
  locallastchangedat     : abp_locinst_lastchange_tstmpl;
}
