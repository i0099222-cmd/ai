@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '등록된 개발 오브젝트'
@Search.searchable: true
// 딕셔너리의 '오브젝트 UNION 뷰': 매핑 To-Be · Value Help · OData 서비스 · 기술부채의 개발 오브젝트를 한 목록으로.
// 한 행 = 등록 한 건 (기술부채는 부채마다 한 행이라 같은 오브젝트가 여러 번 나올 수 있다).
// 기술부채 탭 '개발 오브젝트' 값 도움말로 쓴다 (고르면 유형·모듈도 같이 채워짐).
// 탭마다 데이터 엘리먼트가 달라서 유형·이름·번호·설명은 같은 기본 타입으로 맞춘다.
define view entity ZI_CMSM_DevObject
  as select from ZI_CMSM_Map
{
      @EndUserText.label: '등록 UUID'
  key MapUuid                                   as SourceUuid,
      @EndUserText.label: '등록 탭'
      cast( 'MAP' as abap.char( 4 ) )           as SourceTab,
      @EndUserText.label: '등록번호'
      cast( MapId as abap.char( 10 ) )          as SourceId,
      @EndUserText.label: '오브젝트 유형'
      cast( TobeType as abap.char( 10 ) )       as ObjType,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @EndUserText.label: '개발 오브젝트'
      cast( TobeName as abap.char( 80 ) )       as DevObj,
      @EndUserText.label: '모듈'
      SapModule,
      @Search.defaultSearchElement: true
      @EndUserText.label: '설명'
      cast( Description as abap.char( 120 ) )   as Description
}
union all select from ZI_CMSM_Vh
{
  key VhUuid                                    as SourceUuid,
      cast( 'VH' as abap.char( 4 ) )            as SourceTab,
      cast( VhId as abap.char( 10 ) )           as SourceId,
      cast( 'VH' as abap.char( 10 ) )           as ObjType,
      cast( VhName as abap.char( 80 ) )         as DevObj,
      SapModule,
      cast( Description as abap.char( 120 ) )   as Description
}
union all select from ZI_CMSM_Sb
{
  key SbUuid                                    as SourceUuid,
      cast( 'SB' as abap.char( 4 ) )            as SourceTab,
      cast( SbId as abap.char( 10 ) )           as SourceId,
      cast( 'SRVB' as abap.char( 10 ) )         as ObjType,
      cast( SrvbName as abap.char( 80 ) )       as DevObj,
      SapModule,
      cast( Description as abap.char( 120 ) )   as Description
}
union all select from ZI_CMSM_Debt
{
  key DebtUuid                                  as SourceUuid,
      cast( 'TD' as abap.char( 4 ) )            as SourceTab,
      cast( DebtId as abap.char( 10 ) )         as SourceId,
      cast( ObjType as abap.char( 10 ) )        as ObjType,
      cast( DevObj as abap.char( 80 ) )         as DevObj,
      SapModule,
      // 부채 설명(1333자)은 목록 칸에 안 맞아서 비released 대상 이름을 보여준다
      cast( StdName as abap.char( 120 ) )       as Description
}
