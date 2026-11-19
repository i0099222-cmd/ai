@EndUserText.label: '엑셀 업로드'
// 탭별 '엑셀 업로드' 액션(uploadExcel)의 입력 팝업 — 파일 하나.
// 템플릿: 11_excel/ZCMSM_업로드_*.xlsx ('업로드' 시트, 1행 컬럼명·2행 필드명·3행부터 데이터)
define abstract entity ZA_CMSM_UploadFile
{
  @EndUserText.label: '엑셀 파일'
  @Semantics.largeObject: { mimeType: 'MimeType',
                            fileName: 'FileName',
                            contentDispositionPreference: #ATTACHMENT }
  Attachment : abap.rawstring( 0 );
  @UI.hidden: true
  @Semantics.mimeType: true
  MimeType   : abap.char( 128 );
  @UI.hidden: true
  FileName   : abap.char( 128 );
}
