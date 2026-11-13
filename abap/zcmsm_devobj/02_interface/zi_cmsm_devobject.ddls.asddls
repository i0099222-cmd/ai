@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '등록된 개발 오브젝트'
@Search.searchable: true
// 딕셔너리의 '오브젝트 UNION 뷰': 등록 탭 세 개(매핑 To-Be · Value Help · OData 서비스)를 한 목록으로.
// 기술부채 탭 '개발 오브젝트' 값 도움말로 쓴다 (고르면 유형·모듈도 같이 채워짐).
// 탭마다 데이터 엘리먼트가 달라서 유형·이름·번호는 같은 기본 타입으로 맞춘다.
define view entity ZI_CMSM_DevObject
  as select from ZI_CMSM_Map
{
      @EndUserText.label: '등록 UUID'
  key MapUuid                                   as RegUuid,
      @EndUserText.label: '등록 탭'
      cast( 'MAP' as abap.char( 4 ) )           as RegTab,
      @EndUserText.label: '등록번호'
      cast( MapId as abap.char( 10 ) )          as RegId,
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
      Description
}
union all select from ZI_CMSM_Vh
{
  key VhUuid                                    as RegUuid,
      cast( 'VH' as abap.char( 4 ) )            as RegTab,
      cast( VhId as abap.char( 10 ) )           as RegId,
      cast( 'VH' as abap.char( 10 ) )           as ObjType,
      cast( VhName as abap.char( 80 ) )         as DevObj,
      SapModule,
      Description
}
union all select from ZI_CMSM_Sb
{
  key SbUuid                                    as RegUuid,
      cast( 'SB' as abap.char( 4 ) )            as RegTab,
      cast( SbId as abap.char( 10 ) )           as RegId,
      cast( 'SRVB' as abap.char( 10 ) )         as ObjType,
      cast( SrvbName as abap.char( 80 ) )       as DevObj,
      SapModule,
      Description
}
