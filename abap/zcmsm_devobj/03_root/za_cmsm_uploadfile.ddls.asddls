@EndUserText.label: '엑셀 업로드'
// 탭별 '엑셀 업로드' 액션(uploadExcel)의 입력 팝업 — 파일 하나.
// 팝업에 파일 선택 칸이 나오려면: root abstract entity + 추상 BDEF(ZA_CMSM_UploadFile, with hierarchy)
//   + 액션을 'deep parameter' 로 (그냥 parameter 면 파일 칸이 텍스트 입력칸으로 나온다). PCE 2023 이상
// 템플릿: 11_excel/ZCMSM_업로드_*.xlsx ('업로드' 시트, 1행 컬럼명·2행 필드명·3행부터 데이터)
define root abstract entity ZA_CMSM_UploadFile
{
  @EndUserText.label: '엑셀 파일'
  @Semantics.largeObject: { mimeType: 'MimeType',
                            fileName: 'FileName',
                            acceptableMimeTypes: [ 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ],
                            contentDispositionPreference: #ATTACHMENT }
  Attachment : abap.rawstring( 0 );
  @UI.hidden: true
  @Semantics.mimeType: true
  MimeType   : abap.char( 128 );
  @UI.hidden: true
  FileName   : abap.char( 128 );
}
