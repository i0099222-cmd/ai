@EndUserText.label: 'To-Be 오브젝트 사용처 (Z CDS)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CMSM_TOBEUSE_QUERY'
@UI.headerInfo: { typeName: '사용처', typeNamePlural: '사용처' }
// Z CDS 중 To-Be 를 쓰는 것 — 데이터 소스(select from·projection on) / join / 연관 / 기타 (저장 안 함, 열 때 읽음).
// 래퍼 ZCL_CMSM_DDL_WHERE_USED 가 표준 CDS 사용처 인덱스(DDLS_RIS_INDEX)에서 찾는다.
// 매핑 상세 화면의 '사용처' 섹션 — ZC_CMSM_Map 의 _Usage 연관으로 연결.
// 키 = To-Be 이름 + 사용하는 CDS (CDS 하나에 한 줄)
define custom entity ZCE_CMSM_TobeUsage
{
      @UI.hidden: true
      @EndUserText.label: 'To-Be 오브젝트'
  key TobeName : abap.char( 80 );
      @UI.lineItem: [{ position: 10, importance: #HIGH }]
      @EndUserText.label: '사용하는 CDS'
  key UsedBy   : abap.char( 40 );
      @UI.lineItem: [{ position: 20, importance: #HIGH }]
      @EndUserText.label: '사용 방식'
      UseKind  : abap.char( 20 );
      @UI.lineItem: [{ position: 30 }]
      @EndUserText.label: '패키지'
      Package  : abap.char( 30 );
}
