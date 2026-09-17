@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '적용범위 값 도움 (설정 기반)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #D,
  sizeCategory: #XS,
  dataClass: #CUSTOMIZING
}
@ObjectModel.resultSet.sizeCategory: #XS
// 화면의 적용범위 드롭다운은 이 뷰가 채운다.
// Phase 1 은 (NAMING, FND) 행을 activeflg 공란으로 두므로 FND 가 목록에 뜨지 않는다.
// 즉 "패키지/오브젝트 단위로만 등록" 이 코드가 아니라 설정으로 지켜진다.
// Phase 2 에서 PERF/SECURITY 행을 추가하면 코드 변경 없이 FND 가 열린다.
define view entity ZI_AtcScopeVH
  as select from ztatcscope
{
  key checkgroup  as CheckGroup,
  key scopetype   as ScopeType,
      apprlevel   as ApprovalLevel,
      maxvalidmon as MaxValidMonths,
      reasonreq   as ReasonRequired,

      case scopetype
        when 'FND' then cast( 'Finding (건 단위)'      as abap.char( 40 ) )
        when 'OBJ' then cast( 'ABAP Object (오브젝트)' as abap.char( 40 ) )
        when 'PKG' then cast( 'Package (패키지 전체)'  as abap.char( 40 ) )
        else            cast( ''                       as abap.char( 40 ) )
      end           as ScopeTypeText
}
where activeflg = 'X'
