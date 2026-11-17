@EndUserText.label: 'Value Help 데이터 소스 (시스템에서 읽음)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CMSM_VHSRC_QUERY'
@UI.headerInfo: { typeName: '데이터 소스', typeNamePlural: '데이터 소스' }
// VH(CDS view entity) 정의를 XCO 로 읽어서 메인 데이터 소스·연관 대상을 보여준다 (저장 안 함, 열 때 읽음).
// VH 상세 화면의 '데이터 소스 (자동)' 섹션 — ZC_CMSM_Vh 의 _SysSource 연관으로 연결.
define custom entity ZCE_CMSM_VhSource
{
      @UI.hidden: true
      @EndUserText.label: 'VH 이름'
  key VhName    : abap.char( 80 );
      @UI.hidden: true
      @EndUserText.label: '순번'
  key SrcPos    : abap.int4;
      @UI.lineItem: [{ position: 10, importance: #HIGH }]
      @EndUserText.label: '구분'
      SrcRole   : abap.char( 20 );
      @UI.lineItem: [{ position: 20, importance: #HIGH }]
      @EndUserText.label: '소스 유형'
      SrcKind   : abap.char( 20 );
      @UI.lineItem: [{ position: 30, importance: #HIGH }]
      @EndUserText.label: '소스 이름'
      SrcName   : abap.char( 80 );
      @UI.lineItem: [{ position: 40 }]
      @EndUserText.label: '연관 이름'
      AssocName : abap.char( 40 );
}
