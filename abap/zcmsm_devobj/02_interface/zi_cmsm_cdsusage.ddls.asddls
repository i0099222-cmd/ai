@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CDS 사용처 인덱스'
@UI.headerInfo: { typeName: '사용처', typeNamePlural: '사용처' }
// 시스템 Z CDS 중 어떤 오브젝트를 데이터 소스(select from)·연관 대상으로 쓰는지.
// 배치 잡 ZCL_CMSM_USAGE_JOB 가 매일 다시 만든다 → 화면은 테이블만 읽어서 바로 뜬다 (기준은 '확인 일시').
// 매핑 상세의 '사용처 (Z CDS)' 섹션 — ZC_CMSM_Map 의 _Usage 연관 (To-Be 이름 = 쓰이는 오브젝트)
define view entity ZI_CMSM_CdsUsage
  as select from ztcmsm00250
{
      @UI.hidden: true
      @EndUserText.label: '쓰이는 오브젝트'
  key usedobject as UsedObject,
      @UI.lineItem: [{ position: 10, importance: #HIGH }]
      @EndUserText.label: '사용하는 CDS'
  key usedby     as UsedBy,
      @UI.lineItem: [{ position: 20, importance: #HIGH }]
      @EndUserText.label: '사용 방식'
      usekind    as UseKind,
      @UI.lineItem: [{ position: 30 }]
      @EndUserText.label: '패키지'
      devpackage as DevPackage,
      @UI.lineItem: [{ position: 40 }]
      @EndUserText.label: '확인 일시'
      scannedat  as ScannedAt
}
