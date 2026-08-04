/*
 * 루트 엔터티(ZI_TadirObject)용 draft 테이블.
 *
 * draft를 쓰는 BO는 composition tree의 **모든 엔터티**가 각자 draft 테이블을 가져야 한다.
 * 루트가 읽기 전용(TADIR)이어도 예외가 아니다.
 *
 * 주의: 이 테이블의 필드는 기존 ZI_TadirObject 뷰가 노출하는 필드와 맞아야 한다.
 * 아래는 TADIR 표준 필드 기준 예시이므로, 실제 뷰에서 노출하는 필드에 맞춰 가감할 것.
 */
@EndUserText.label : '오브젝트 조회 - Draft'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztb_tadirobj_d {

  key mandt      : mandt not null;
  key pgmid      : pgmid not null;
  key object     : trobjtype not null;
  key obj_name   : sobj_name not null;

  /* 기존 뷰에서 노출 중인 TADIR 필드들 — 실제 뷰에 맞춰 조정 */
  devclass       : devclass;
  author         : responsibl;
  srcsystem      : srcsystem;
  genflag        : genflag;

  /* 루트의 total etag용. 자식(스테이징)의 변경시각을 끌어올린 값이다.
   * TADIR 자체에는 변경시각 필드가 없기 때문에 이 방식을 쓴다. */
  last_changed_at : abp_lastchange_tstmpl;

  /* RAP draft 관리 필드 (표준 include) */
  "%admin"       : include sych_bdl_draft_admin_inc;

}
