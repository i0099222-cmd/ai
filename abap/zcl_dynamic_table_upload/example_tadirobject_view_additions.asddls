/*
 * 기존 TADIR 조회 뷰에 "추가"할 부분만 모은 스니펫.
 * 기존 뷰를 통째로 바꾸는 게 아니라, 아래 항목만 붙이면 된다.
 */

/* =====================================================================
 * 1) 인터페이스 뷰 ZI_TadirObject 에 composition 추가
 * =====================================================================
 *
 * define view entity ZI_TadirObject
 *   as select from tadir
 *   composition [0..1] of ZI_DynUploadStaging as _Staging   // <== 추가
 * {
 *   key pgmid    as PgmId,
 *   key object   as Object,
 *   key obj_name as ObjName,
 *       ... 기존 필드 ...
 *
 *       _Staging                                            // <== 추가
 * }
 *
 * composition [0..1] 인 이유: TADIR 행은 수백만 건인데 스테이징 행은
 * 실제로 업로드를 시도한 테이블에만 생긴다. 반드시 [0..1] 이어야 한다.
 *
 * =====================================================================
 * 2) Projection(consumption) 뷰 ZC_TadirObject 에 추가
 * =====================================================================
 *
 * define view entity ZC_TadirObject
 *   as projection on ZI_TadirObject
 * {
 *   key PgmId,
 *   key Object,
 *   key ObjName,
 *       ... 기존 필드 ...
 *
 *       @Consumption.hidden: true
 *       _Staging : redirected to composition child ZC_DynUploadStaging
 * }
 */

/* =====================================================================
 * 3) 스테이징 projection 뷰 (신규) — 실제로 파일 UI가 그려지는 곳
 * ===================================================================== */
@EndUserText.label: '동적 업로드 스테이징'
@Metadata.allowExtensions: true
define view entity ZC_DynUploadStaging
  as projection on ZI_DynUploadStaging
{
  key PgmId,
  key Object,
  key ObjName,

      /* @UI.fileUpload 가 붙어야 Fiori Elements가 파일 업로더 컨트롤을 그린다.
       * 이게 없으면 그냥 텍스트 필드로 렌더링된다. */
      @UI.fileUpload: { fileNamePropertyPath: 'UploadFileName',
                        mediaTypePropertyPath: 'UploadFileMimeType',
                        acceptableMediaTypes: [ 'text/csv' ] }
      UploadFile,
      UploadFileName,
      UploadFileMimeType,

      /* 템플릿은 읽기 전용 — 액션이 채워 넣고 사용자는 다운로드만 한다.
       * @UI.fileUpload 없이 @Semantics.largeObject 만 있으면
       * 업로더가 아니라 다운로드 링크로 렌더링된다. */
      TemplateFile,
      TemplateFileName,
      TemplateFileMimeType,

      LastTotalRows,
      LastSuccessRows,
      LastErrorRows,
      LastRunAt,

      LastChangedAt,
      LocalLastChangedAt,

      _TadirObject : redirected to parent ZC_TadirObject
}
