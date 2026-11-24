@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '등록된 개발 오브젝트'
@Search.searchable: true
// 딕셔너리의 '오브젝트 UNION 뷰': 모든 탭의 오브젝트를 한 목록으로.
// 등록 구분(SourceTab)
//   TOBE : 매핑의 To-Be 오브젝트      ASIS : 매핑의 As-Is 오브젝트 (신규 매핑은 없음)
//   VH   : Value Help                 SB   : OData 서비스        TD : 기술부채의 개발 오브젝트
//   소스 줄 (검색 칸에 소스 이름을 넣으면 그 소스를 가진 등록 건이 나오게 — 1단계만):
//   TS   : To-Be 소스 — To-Be CDS 가 바로 쓰는 테이블·CDS (To-Be 가 테이블이면 그 테이블을 바로 쓰는 Z CDS)
//   VA   : VH 소스 — VH CDS 가 바로 쓰는 테이블·CDS (VH 상세 '데이터 소스 (자동)' 쪽)
//   소스 줄: 개발 오브젝트·유형·등록번호·담당자 = 주인(To-Be·VH) 것, 설명(Description) = 소스 이름,
//            등록 UUID = 주인 UUID (행을 누르면 주인 상세로)
//   검색 칸(DevObj·Description·SourceId)은 계산식 없이 실제 테이블 칸이어야 한다 — 검색이 HANA CONTAINS(퍼지)라
//   식(concat·substring 등)에 걸리면 덤프(SQL code 7 'contains predicates on expression')
//   1단계 소스는 사용처 인덱스 래퍼 ZI_CMSM_DdlUse (12_wrapper, Standard ABAP·C1 릴리즈) — select from·join·연관 다 포함
// 매핑 한 건은 TOBE·ASIS 두 줄 (등록번호 MP-nnnn이 같아서 짝을 알 수 있다), 기술부채는 부채마다 한 줄.
// 키 = 등록 UUID + 등록 구분 + 개발 오브젝트 + 설명 (소스 줄은 한 건에 여러 줄 — 설명 = 소스 이름으로 갈린다)
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
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @EndUserText.label: '개발 오브젝트'
  key cast( TobeName as abap.char( 80 ) )       as DevObj,
      @Search.defaultSearchElement: true
      @EndUserText.label: '설명'
  key cast( Description as abap.char( 120 ) )   as Description,
      @EndUserText.label: '등록번호'
      cast( MapId as abap.char( 10 ) )          as SourceId,
      @EndUserText.label: '시스템'
      cast( TgtSysId as abap.char( 8 ) )        as SysId,
      @EndUserText.label: '오브젝트 유형'
      cast( TobeType as abap.char( 10 ) )       as ObjType,
      @EndUserText.label: '모듈'
      SapModule,
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
  key cast( AsisName as abap.char( 80 ) )       as DevObj,
  key cast( Description as abap.char( 120 ) )   as Description,
      cast( MapId as abap.char( 10 ) )          as SourceId,
      cast( SrcSysId as abap.char( 8 ) )        as SysId,
      cast( AsisType as abap.char( 10 ) )       as ObjType,
      SapModule,
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
  key cast( VhName as abap.char( 80 ) )         as DevObj,
  key cast( Description as abap.char( 120 ) )   as Description,
      cast( VhId as abap.char( 10 ) )           as SourceId,
      cast( SysId as abap.char( 8 ) )           as SysId,
      cast( 'VH' as abap.char( 10 ) )           as ObjType,
      SapModule,
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
  key cast( SrvbName as abap.char( 80 ) )       as DevObj,
  key cast( Description as abap.char( 120 ) )   as Description,
      cast( SbId as abap.char( 10 ) )           as SourceId,
      cast( SysId as abap.char( 8 ) )           as SysId,
      cast( 'SRVB' as abap.char( 10 ) )         as ObjType,
      SapModule,
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
  key cast( DevObj as abap.char( 80 ) )         as DevObj,
      // 비released 사용 내역(1333자)은 목록 칸에 안 맞아서 설계서 개발 ID를 보여준다
  key cast( DevId as abap.char( 120 ) )         as Description,
      cast( DebtId as abap.char( 10 ) )         as SourceId,
      cast( SysId as abap.char( 8 ) )           as SysId,
      cast( ObjType as abap.char( 10 ) )        as ObjType,
      SapModule,
      // 기술부채의 담당자는 업무담당자
      cast( BizOwner as abap.char( 12 ) )       as OwnerId,
      cast( '' as abap.char( 40 ) )             as ObjCreator,
      cast( '' as abap.char( 10 ) )             as ReqId,
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt
}
// ── 소스 줄 ──
// TS: To-Be CDS 가 바로 쓰는 오브젝트
union all select from ZI_CMSM_Map    as M
  inner join          ZI_CMSM_DdlUse as U on U.DdlName = M.TobeName
{
  key M.MapUuid                                 as SourceUuid,
  key cast( 'TS' as abap.char( 4 ) )            as SourceTab,
  key cast( M.TobeName as abap.char( 80 ) )     as DevObj,
  key cast( U.UsedName as abap.char( 120 ) )    as Description,   // 소스 이름 (실제 칸 — 검색 CONTAINS)
      cast( M.MapId as abap.char( 10 ) )        as SourceId,
      cast( M.TgtSysId as abap.char( 8 ) )      as SysId,
      cast( M.TobeType as abap.char( 10 ) )     as ObjType,
      M.SapModule,
      cast( M.OwnerId as abap.char( 12 ) )      as OwnerId,
      cast( M.ObjCreator as abap.char( 40 ) )   as ObjCreator,
      cast( M.ReqId as abap.char( 10 ) )        as ReqId,
      M.CreatedBy,
      M.CreatedAt,
      M.LastChangedBy,
      M.LastChangedAt
}
// TS: To-Be 가 테이블이면 그 테이블을 바로 쓰는 Z CDS (매핑 상세 'To-Be 데이터 소스'의 '읽는 CDS'와 같은 쪽)
union all select from ZI_CMSM_Map    as M
  inner join          ZI_CMSM_DdlUse as U on U.UsedName = M.TobeName
{
  key M.MapUuid                                 as SourceUuid,
  key cast( 'TS' as abap.char( 4 ) )            as SourceTab,
  key cast( M.TobeName as abap.char( 80 ) )     as DevObj,
  key cast( U.DdlName as abap.char( 120 ) )     as Description,   // 소스 이름 (실제 칸 — 검색 CONTAINS)
      cast( M.MapId as abap.char( 10 ) )        as SourceId,
      cast( M.TgtSysId as abap.char( 8 ) )      as SysId,
      cast( M.TobeType as abap.char( 10 ) )     as ObjType,
      M.SapModule,
      cast( M.OwnerId as abap.char( 12 ) )      as OwnerId,
      cast( M.ObjCreator as abap.char( 40 ) )   as ObjCreator,
      cast( M.ReqId as abap.char( 10 ) )        as ReqId,
      M.CreatedBy,
      M.CreatedAt,
      M.LastChangedBy,
      M.LastChangedAt
}
where
      U.ObjType  = 'TABLE'      // To-Be(= 쓰이는 쪽)가 테이블인지는 TADIR 기준 (매핑 To-Be 유형 코드값과 상관없게)
  and U.DdlName  like 'Z%'
// VA: VH CDS 가 바로 쓰는 오브젝트 (VH 상세 '데이터 소스 (자동)' 쪽)
union all select from ZI_CMSM_Vh     as V
  inner join          ZI_CMSM_DdlUse as U on U.DdlName = V.VhName
{
  key V.VhUuid                                  as SourceUuid,
  key cast( 'VA' as abap.char( 4 ) )            as SourceTab,
  key cast( V.VhName as abap.char( 80 ) )       as DevObj,
  key cast( U.UsedName as abap.char( 120 ) )    as Description,   // 소스 이름 (실제 칸 — 검색 CONTAINS)
      cast( V.VhId as abap.char( 10 ) )         as SourceId,
      cast( V.SysId as abap.char( 8 ) )         as SysId,
      cast( 'VH' as abap.char( 10 ) )           as ObjType,
      V.SapModule,
      cast( V.OwnerId as abap.char( 12 ) )      as OwnerId,
      cast( V.ObjCreator as abap.char( 40 ) )   as ObjCreator,
      cast( V.ReqId as abap.char( 10 ) )        as ReqId,
      V.CreatedBy,
      V.CreatedAt,
      V.LastChangedBy,
      V.LastChangedAt
}
