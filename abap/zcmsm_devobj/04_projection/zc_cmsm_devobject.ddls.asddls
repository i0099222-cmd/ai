@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '통합 오브젝트 조회'
@Metadata.allowExtensions: true
@Search.searchable: true
// 통합 조회 탭 (읽기 전용). 저장된 건만 나온다 (편집 중인 드래프트는 안 나옴).
// 상세 화면: 원본 탭(매핑·VH·OData 서비스·기술부채)의 정보를 연관 경로 필드로 꺼내서 보여준다.
//   한 행에는 원본 연관 하나만 값이 있으니, 아래 숨김 플래그(…Hidden)로 섹션을 숨긴다
//   (섹션 숨김 연결은 앱 annotation.xml — 09_app/annotation.devobject.sample.xml).
define view entity ZC_CMSM_DevObject
  as select from ZI_CMSM_DevObject

  association [0..1] to ZI_CMSM_SourceTabVH as _SourceTab on $projection.SourceTab = _SourceTab.SourceTab
  association [0..1] to ZI_CMSM_ObjTypeVH   as _ObjType   on $projection.ObjType   = _ObjType.Value
  association [0..1] to ZI_CMSM_ModuleVH    as _SapModule on $projection.SapModule = _SapModule.Value
  association [0..1] to ZI_CMSM_SysId       as _Sys       on $projection.SysId     = _Sys.SysId
  association [0..1] to ZI_CMSM_UserVH      as _Owner     on $projection.OwnerId   = _Owner.UserId
  association [0..1] to ZI_CMSM_ReqVH       as _Request   on $projection.ReqId     = _Request.ReqId

  // 원본 탭 (한 행에는 이 중 하나만 연결된다. TOBE·ASIS는 둘 다 _Map)
  association [0..1] to ZI_CMSM_Map         as _Map       on $projection.SourceUuid = _Map.MapUuid
  association [0..1] to ZI_CMSM_Vh          as _Vh        on $projection.SourceUuid = _Vh.VhUuid
  association [0..1] to ZI_CMSM_Sb          as _Sb        on $projection.SourceUuid = _Sb.SbUuid
  association [0..1] to ZI_CMSM_Debt        as _Debt      on $projection.SourceUuid = _Debt.DebtUuid
{
  key SourceUuid,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_SourceTabVH', element: 'SourceTab' } }]
      @ObjectModel.text.element: [ 'SourceTabText' ]
  key SourceTab,
      @EndUserText.label: '등록 구분 내역'
      _SourceTab.Text      as SourceTabText,
      @Search.defaultSearchElement: true
      SourceId,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_SysId', element: 'SysId' } }]
      @ObjectModel.text.element: [ 'SysText' ]
      SysId,
      @EndUserText.label: '시스템 설명'
      _Sys.Description     as SysText,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_ObjTypeVH', element: 'Value' } }]
      @ObjectModel.text.element: [ 'ObjTypeText' ]
      ObjType,
      @EndUserText.label: '오브젝트 유형 내역'
      _ObjType.Text        as ObjTypeText,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      DevObj,
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_ModuleVH', element: 'Value' } }]
      @ObjectModel.text.element: [ 'SapModuleText' ]
      SapModule,
      @EndUserText.label: '모듈 내역'
      _SapModule.Text      as SapModuleText,
      @Search.defaultSearchElement: true
      Description,

      /* 공통 */
      @Consumption.valueHelpDefinition: [{ entity: { name: 'ZI_CMSM_UserVH', element: 'UserId' } }]
      @ObjectModel.text.element: [ 'OwnerName' ]
      OwnerId,
      @EndUserText.label: '담당자 이름'
      _Owner.PersonFullName as OwnerName,
      ObjCreator,
      @ObjectModel.text.element: [ 'ReqTitle' ]
      ReqId,
      @EndUserText.label: '요청 제목'
      _Request.Title       as ReqTitle,

      /* 매핑 (TOBE·ASIS) */
      @ObjectModel.text.element: [ 'MapKindText' ]
      _Map.MapKind                 as MapKind,
      @EndUserText.label: '구분 내역'
      _Map._MapKind.Text           as MapKindText,
      @EndUserText.label: 'As-Is 시스템'
      _Map.SrcSysId                as AsisSysId,
      @ObjectModel.text.element: [ 'AsisTypeText' ]
      _Map.AsisType                as AsisType,
      @EndUserText.label: 'As-Is 유형 내역'
      _Map._AsisType.Text          as AsisTypeText,
      _Map.AsisName                as AsisName,
      @EndUserText.label: 'To-Be 시스템'
      _Map.TgtSysId                as TobeSysId,
      @ObjectModel.text.element: [ 'TobeTypeText' ]
      _Map.TobeType                as TobeType,
      @EndUserText.label: 'To-Be 유형 내역'
      _Map._TobeType.Text          as TobeTypeText,
      _Map.TobeName                as TobeName,
      @ObjectModel.text.element: [ 'UiKindText' ]
      _Map.UiKind                  as UiKind,
      @EndUserText.label: 'UI 종류 내역'
      _Map._UiKind.Text            as UiKindText,
      _Map.FioriAppId              as FioriAppId,
      _Map.SemObjAction            as SemObjAction,
      _Map.ReactApp                as ReactApp,
      _Map.UiUri                   as UiUri,

      /* 테스트 (VH·OData 서비스 — 둘 중 하나만 값이 있다) */
      @EndUserText.label: '테스트 파일명'
      coalesce( _Vh.TestFileName, _Sb.TestFileName ) as TestFileName,
      @EndUserText.label: '올린 사람'
      coalesce( _Vh.TestBy, _Sb.TestBy )             as TestBy,
      @EndUserText.label: '올린 일시'
      coalesce( _Vh.TestAt, _Sb.TestAt )             as TestAt,

      /* 기술부채 (TD) */
      _Debt.DevId                  as DevId,
      @ObjectModel.text.element: [ 'DebtLevelText' ]
      _Debt.DebtLevel              as DebtLevel,
      @EndUserText.label: 'Debt Level 내역'
      _Debt._DebtLevel.Text        as DebtLevelText,
      @ObjectModel.text.element: [ 'ImproveStatusText' ]
      _Debt.ImproveStatus          as ImproveStatus,
      @EndUserText.label: '개선상태 내역'
      _Debt._ImproveStatus.Text    as ImproveStatusText,
      @ObjectModel.text.element: [ 'WrapTypeText' ]
      _Debt.WrapType               as WrapType,
      @EndUserText.label: '래핑 여부 내역'
      _Debt._WrapType.Text         as WrapTypeText,
      _Debt.DebtDesc               as DebtDesc,
      _Debt.DebtReason             as DebtReason,

      /* 관리 정보 */
      CreatedBy,
      CreatedAt,
      LastChangedBy,
      LastChangedAt,

      /* 상세 화면 섹션 숨김 플래그 (X = 숨김) */
      @EndUserText.label: '매핑 섹션 숨김'
      cast( case when SourceTab = 'TOBE' or SourceTab = 'ASIS'
                 then '' else 'X' end as abap_boolean ) as MapHidden,
      @EndUserText.label: 'UI 섹션 숨김'
      cast( case when ( SourceTab = 'TOBE' or SourceTab = 'ASIS' ) and _Map.TobeType = 'TCODE'
                 then '' else 'X' end as abap_boolean ) as UiHidden,
      @EndUserText.label: '테스트 섹션 숨김'
      cast( case when SourceTab = 'VH' or SourceTab = 'SB'
                 then '' else 'X' end as abap_boolean ) as TestHidden,
      @EndUserText.label: '기술부채 섹션 숨김'
      cast( case when SourceTab = 'TD'
                 then '' else 'X' end as abap_boolean ) as DebtHidden
}
