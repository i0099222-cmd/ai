@EndUserText.label: 'Value Help 데이터 소스 (시스템에서 읽음)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CMSM_VHSRC_QUERY'
@UI.headerInfo: { typeName: '데이터 소스', typeNamePlural: '데이터 소스' }
// VH(CDS view entity) 정의를 XCO 로 읽어서 데이터 소스(메인 소스·연관 대상)를 보여준다 (저장 안 함, 열 때 읽음).
// VH 상세 화면의 '데이터 소스 (자동)' 섹션 — ZC_CMSM_Vh 의 _SysSource 연관으로 연결.
// 키 = VH 이름 + 순번 (행마다 키가 달라야 해서 순번을 둔다. 화면에는 안 보임)
define custom entity ZCE_CMSM_VhSource
{
      @UI.hidden: true
      @EndUserText.label: 'VH 이름'
  key VhName  : abap.char( 80 );
      @UI.hidden: true
      @EndUserText.label: '순번'
  key SrcPos  : abap.int4;
      @UI.lineItem: [{ position: 10, importance: #HIGH }]
      @EndUserText.label: '유형'
      SrcKind : abap.char( 20 );
      @UI.lineItem: [{ position: 20, importance: #HIGH }]
      @EndUserText.label: '이름'
      SrcName : abap.char( 80 );
}
