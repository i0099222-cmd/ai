@EndUserText.label: 'To-Be 데이터 소스 (최하위까지)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CMSM_TOBESRC_QUERY'
@UI.headerInfo: { typeName: '데이터 소스', typeNamePlural: '데이터 소스' }
// To-Be CDS 의 메인 데이터 소스(select from)를 따라 내려가서 맨 아래(테이블)까지 보여 준다
//   (저장 안 함, 열 때 래퍼 ZCL_CMSM_DDL_WHERE_USED=>source_chain( ) 이 CDS 소스 원문으로 읽음).
//   예: ZC_… → ZR_… → ZI_… → ZTABLE (단계 1, 2, 3 …). 유형: CDS / 테이블 / DDIC 뷰 / 도메인 고정값 / 기타
// 매핑 상세 화면의 'To-Be 데이터 소스' 섹션 — ZC_CMSM_Map 의 _TobeSource 연관으로 연결.
// 키 = To-Be 이름 + 순번 (화면에는 안 보임)
define custom entity ZCE_CMSM_TobeSource
{
      @UI.hidden: true
      @EndUserText.label: 'To-Be 오브젝트'
  key TobeName : abap.char( 80 );
      @UI.hidden: true
      @EndUserText.label: '순번'
  key SrcPos   : abap.int4;
      @UI.lineItem: [{ position: 10, importance: #HIGH }]
      @EndUserText.label: '단계'
      SrcLevel : abap.int4;
      @UI.lineItem: [{ position: 20, importance: #HIGH }]
      @EndUserText.label: '유형'
      SrcKind  : abap.char( 20 );
      @UI.lineItem: [{ position: 30, importance: #HIGH }]
      @EndUserText.label: '이름'
      SrcName  : abap.char( 80 );
      @UI.lineItem: [{ position: 40 }]
      @EndUserText.label: '읽는 오브젝트'
      UsedBy   : abap.char( 80 );
}
