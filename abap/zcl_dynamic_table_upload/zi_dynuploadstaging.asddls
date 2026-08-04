/*
 * 업로드 스테이징 인터페이스 뷰.
 *
 * TADIR 조회 엔터티(ZI_TadirObject)의 composition child로 붙는다.
 * managed BO에서는 엔터티마다 각자의 persistent table을 가질 수 있으므로,
 * 부모(TADIR)는 읽기 전용으로 두고 이 자식만 쓰기 가능하게 만든다.
 *
 * 스트림 필드(UploadFile / TemplateFile)가 여기 있기 때문에
 * Fiori Elements가 파일 업로더와 다운로드 링크를 표준으로 렌더링해 준다.
 */
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: '동적 업로드 스테이징'
define view entity ZI_DynUploadStaging
  as select from ztb_dyn_upload_stg
  association to parent ZI_TadirObject as _TadirObject
    on  $projection.PgmId   = _TadirObject.PgmId
    and $projection.Object  = _TadirObject.Object
    and $projection.ObjName = _TadirObject.ObjName
{
  key pgmid    as PgmId,
  key object   as Object,
  key obj_name as ObjName,

      /* --- 업로드 파일 ---
       * contentDispositionPreference: #ATTACHMENT 를 주면 브라우저가 인라인 표시 대신
       * 다운로드로 처리한다. fileName이 가리키는 필드값이 실제 저장 파일명이 된다. */
      @Semantics.largeObject: { mimeType: 'UploadFileMimeType',
                                fileName: 'UploadFileName',
                                acceptableMimeTypes: [ 'text/csv' ],
                                contentDispositionPreference: #ATTACHMENT }
      upload_file       as UploadFile,

      @Semantics.mimeType: true
      upload_mimetype   as UploadFileMimeType,
      upload_filename   as UploadFileName,

      /* --- 템플릿 파일 ---
       * downloadTemplate 액션이 여기에 파일을 생성해 넣으면,
       * UI는 .../TemplateFile/$value 로 바로 다운로드할 수 있다.
       * => 템플릿 다운로드에 별도 HTTP 서비스가 필요 없어진다. */
      @Semantics.largeObject: { mimeType: 'TemplateFileMimeType',
                                fileName: 'TemplateFileName',
                                contentDispositionPreference: #ATTACHMENT }
      template_file     as TemplateFile,

      @Semantics.mimeType: true
      template_mimetype as TemplateFileMimeType,
      template_filename as TemplateFileName,

      /* --- 마지막 실행 결과 --- */
      last_total_rows   as LastTotalRows,
      last_success_rows as LastSuccessRows,
      last_error_rows   as LastErrorRows,
      last_run_at       as LastRunAt,

      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.lastChangedBy: true
      last_changed_by       as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,

      _TadirObject
}
