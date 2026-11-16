@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '등록된 개발 오브젝트'
@Search.searchable: true
// 딕셔너리의 '오브젝트 UNION 뷰': 모든 탭의 오브젝트를 한 목록으로.
// 등록 구분(SourceTab)
//   TOBE : 매핑의 To-Be 오브젝트      ASIS : 매핑의 As-Is 오브젝트 (신규 매핑은 없음)
//   VH   : Value Help                 SB   : OData 서비스        TD : 기술부채의 개발 오브젝트
// 매핑 한 건은 TOBE·ASIS 두 줄 (등록번호 MP-nnnn이 같아서 짝을 알 수 있다), 기술부채는 부채마다 한 줄.
// 시스템: ASIS는 소스 시스템(ECC), 나머지는 타겟·등록 시스템.
// 공통: 담당자(기술부채는 업무담당자), 오브젝트 생성자, 요청번호, 관리 필드.
// 탭마다 데이터 엘리먼트가 달라서 유형·이름·번호·설명·담당자 등은 같은 기본 타입으로 맞춘다.
define view entity ZI_CMSM_DevObject
  as select from ZI_CMSM_Map
{
      @EndUserText.label: '등록 UUID'
  key MapUuid                                   as SourceUuid,
      @EndUserText.label: '등록 구분'
  key cast( 'TOBE' as abap.char( 4 ) )          as SourceTab,
      @EndUserText.label: '등록번호'
      cast( MapId as abap.char( 10 ) )          as SourceId,
      @EndUserText.label: '시스템'
      cast( TgtSysId as abap.char( 8 ) )        as SysId,
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
      cast( Description as abap.char( 120 ) )   as Description,
      @EndUserText.label: '담당자'
      cast( OwnerId as abap.char( 12 ) )        as OwnerId,
      @EndUserText.label: '오브젝트 생성자'
      cast( ObjCreator as abap.char( 40 ) )     as ObjCreator,
      @EndUserText.label: '요청번호'
      cast( ReqId as abap.char( 10 ) )          as ReqId,
      @EndUserText.label: '등록자'
      CreatedBy,
      @EndUserText.label: '등록 일시'
      CreatedAt,
      @EndUserText.label: '최종 변경자'
      LastChangedBy,
      @EndUserText.label: '최종 변경 일시'
      LastChangedAt
}
union all select from ZI_CMSM_Map
{
  key MapUuid                                   as SourceUuid,
  key cast( 'ASIS' as abap.char( 4 ) )          as SourceTab,
      cast( MapId as abap.char( 10 ) )          as SourceId,
      cast( SrcSysId as abap.char( 8 ) )        as SysId,
      cast( AsisType as abap.char( 10 ) )       as ObjType,
      cast( AsisName as abap.char( 80 ) )       as DevObj,
      SapModule,
      cast( Description as abap.char( 120 ) )   as Description,
      cast( OwnerId as abap.char( 12 ) )        as OwnerId,
      cast( ObjCreator as abap.char( 40 ) )     as ObjCreator,
      cast( ReqId as abap.char( 10 ) )          as ReqId,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt
}
where
  AsisName <> ''
union all select from ZI_CMSM_Vh
{
  key VhUuid                                    as SourceUuid,
  key cast( 'VH' as abap.char( 4 ) )            as SourceTab,
      cast( VhId as abap.char( 10 ) )           as SourceId,
      cast( SysId as abap.char( 8 ) )           as SysId,
      cast( 'VH' as abap.char( 10 ) )           as ObjType,
      cast( VhName as abap.char( 80 ) )         as DevObj,
      SapModule,
      cast( Description as abap.char( 120 ) )   as Description,
      cast( OwnerId as abap.char( 12 ) )        as OwnerId,
      cast( ObjCreator as abap.char( 40 ) )     as ObjCreator,
      cast( ReqId as abap.char( 10 ) )          as ReqId,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt
}
union all select from ZI_CMSM_Sb
{
  key SbUuid                                    as SourceUuid,
  key cast( 'SB' as abap.char( 4 ) )            as SourceTab,
      cast( SbId as abap.char( 10 ) )           as SourceId,
      cast( SysId as abap.char( 8 ) )           as SysId,
      cast( 'SRVB' as abap.char( 10 ) )         as ObjType,
      cast( SrvbName as abap.char( 80 ) )       as DevObj,
      SapModule,
      cast( Description as abap.char( 120 ) )   as Description,
      cast( OwnerId as abap.char( 12 ) )        as OwnerId,
      cast( ObjCreator as abap.char( 40 ) )     as ObjCreator,
      cast( ReqId as abap.char( 10 ) )          as ReqId,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt
}
union all select from ZI_CMSM_Debt
{
  key DebtUuid                                  as SourceUuid,
  key cast( 'TD' as abap.char( 4 ) )            as SourceTab,
      cast( DebtId as abap.char( 10 ) )         as SourceId,
      cast( SysId as abap.char( 8 ) )           as SysId,
      cast( ObjType as abap.char( 10 ) )        as ObjType,
      cast( DevObj as abap.char( 80 ) )         as DevObj,
      SapModule,
      // 비released 사용 내역(1333자)은 목록 칸에 안 맞아서 설계서 개발 ID를 보여준다
      cast( DevId as abap.char( 120 ) )         as Description,
      // 기술부채의 담당자는 업무담당자
      cast( BizOwner as abap.char( 12 ) )       as OwnerId,
      cast( '' as abap.char( 40 ) )             as ObjCreator,
      cast( '' as abap.char( 10 ) )             as ReqId,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt
}
