/*
 * 동적 업로드 스테이징 테이블.
 *
 * TADIR은 읽기 전용 SAP 표준 테이블이라 업로드 파일이나 템플릿을 담을 수 없다.
 * 그래서 TADIR 주키(PGMID/OBJECT/OBJ_NAME)를 그대로 키로 갖는 CBO 테이블을 두고,
 * 조회 뷰에서 LEFT OUTER JOIN으로 붙인다.
 *
 * 이 테이블 하나가 업로드 파일과 템플릿 파일을 모두 담기 때문에,
 * 템플릿 다운로드에 HTTP 서비스를 쓰지 않아도 된다(TEMPLATE_FILE 스트림 필드로 처리).
 *
 * 주의: 파일을 DB에 그대로 보관하므로 운영에서는 업로드 완료 후 파일을 비우거나
 * 보관 기간 정책(주기 삭제 잡)을 같이 두는 것을 권장한다.
 */
@EndUserText.label : '동적 테이블 업로드 스테이징'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztb_dyn_upload_stg {

  key client            : abap.clnt not null;

  /* TADIR 주키와 동일하게 맞춘다 */
  key pgmid             : pgmid not null;
  key object            : trobjtype not null;
  key obj_name          : sobj_name not null;

  /* 사용자가 올린 업로드 파일 (CSV UTF-8) */
  upload_file           : abap.rawstring(0);
  upload_filename       : abap.char(255);
  upload_mimetype       : abap.char(128);

  /* 다운로드용으로 생성해 둔 Excel 템플릿 (SpreadsheetML .xls) */
  template_file         : abap.rawstring(0);
  template_filename     : abap.char(255);
  template_mimetype     : abap.char(128);

  /* 마지막 마이그레이션 실행 결과 요약 */
  last_total_rows       : abap.int4;
  last_success_rows     : abap.int4;
  last_error_rows       : abap.int4;
  last_run_at           : timestampl;

  /* RAP 관리 필드 (ETag / 관리자 정보) */
  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;

}
