@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Object Scope Value Help'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #D,
  sizeCategory: #XS,
  dataClass: #CUSTOMIZING
}
@ObjectModel.resultSet.sizeCategory: #XS
// 화면의 적용범위 드롭다운을 채운다.
// 컨트롤 테이블은 허용 여부를 컬럼(fndactive/objactive/pkgactive)으로 들고 있으므로
// union 으로 행으로 펼친다.
//
// Phase 1 네이밍 변형은 fndactive 가 공란이라 FND 행이 나오지 않는다.
// 즉 "패키지/오브젝트 단위로만 등록" 이 코드가 아니라 데이터로 지켜진다.
define view entity ZI_AtcScopeVH
  as select from ztatccfg
{
  key checkvariant                       as CheckVariant,
  key cast( 'FND' as abap.char( 4 ) )    as ScopeType,
      checkgroup                         as CheckGroup,
      cast( 'Finding' as abap.char( 40 ) ) as ScopeTypeText
}
where activeflg = 'X' and fndactive = 'X'

union select from ztatccfg
{
  key checkvariant                       as CheckVariant,
  key cast( 'OBJ' as abap.char( 4 ) )    as ScopeType,
      checkgroup                         as CheckGroup,
      cast( 'ABAP Object' as abap.char( 40 ) ) as ScopeTypeText
}
where activeflg = 'X' and objactive = 'X'

union select from ztatccfg
{
  key checkvariant                       as CheckVariant,
  key cast( 'PCKG' as abap.char( 4 ) )    as ScopeType,
      checkgroup                         as CheckGroup,
      cast( 'All Objects of Package' as abap.char( 40 ) ) as ScopeTypeText
}
where activeflg = 'X' and pkgactive = 'X'
