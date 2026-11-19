@EndUserText.label: 'To-Be 오브젝트 사용처 (같은 패키지 CDS)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_CMSM_TOBEUSE_QUERY'
@UI.headerInfo: { typeName: '사용처', typeNamePlural: '사용처' }
// To-Be 오브젝트와 같은 패키지의 CDS 중 To-Be 를 데이터 소스(select from)·연관 대상으로 쓰는 것 (저장 안 함, 열 때 읽음).
// 매핑 상세 화면의 '사용처 (같은 패키지 CDS)' 섹션 — ZC_CMSM_Map 의 _Usage 연관으로 연결.
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
}
