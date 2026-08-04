/*
 * 스테이징 엔터티(ZI_DynUploadStaging)용 draft 테이블.
 *
 * 활성 테이블(ZTB_DYN_UPLOAD_STG)과 필드 구성이 동일해야 하며,
 * 여기에 draft 관리 include만 추가된다.
 *
 * 스트림 필드(UPLOAD_FILE / TEMPLATE_FILE)도 반드시 draft 테이블에 있어야 한다.
 * 없으면 편집 중(draft) 상태에서 첨부한 파일이 저장되지 않는다.
 */
@EndUserText.label : '동적 업로드 스테이징 - Draft'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztb_dyn_upl_stg_d {

  key mandt             : mandt not null;
  key pgmid             : pgmid not null;
  key object            : trobjtype not null;
  key obj_name          : sobj_name not null;

  upload_file           : abap.rawstring(0);
  upload_filename       : abap.char(255);
  upload_mimetype       : abap.char(128);

  template_file         : abap.rawstring(0);
  template_filename     : abap.char(255);
  template_mimetype     : abap.char(128);

  last_total_rows       : abap.int4;
  last_success_rows     : abap.int4;
  last_error_rows       : abap.int4;
  last_run_at           : timestampl;

  created_by            : abp_creation_user;
  created_at            : abp_creation_tstmpl;
  last_changed_by       : abp_lastchange_user;
  last_changed_at       : abp_lastchange_tstmpl;
  local_last_changed_at : abp_locinst_lastchange_tstmpl;

  /* RAP draft 관리 필드 (표준 include) */
  "%admin"              : include sych_bdl_draft_admin_inc;

}
