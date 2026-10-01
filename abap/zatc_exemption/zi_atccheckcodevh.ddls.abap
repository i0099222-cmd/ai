@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ATC Check Message Code Value Help'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #D,
  sizeCategory: #S,
  dataClass: #CUSTOMIZING
}
@Search.searchable: true
// 신청서의 체크 메시지 코드 값 도움. 오브젝트 신청(MSG)은 어긴 규칙 하나를 고른다.
//
// Phase 1 은 네이밍 체크만 다루므로 규칙 테이블에서 바로 만든다. 네이밍 체크는
// 규칙마다 finding 코드가 있고 그 형식이 N + 오브젝트 유형 + 순번이다
// (zcl_atc_check_naming=>rule_code). 형식을 바꾸면 여기도 같이 바꾼다.
// 규칙 문장이 같이 보여서 코드를 외우지 않고 고를 수 있다.
//
// 다른 체크가 들어오면(Phase 2) 표준 메시지 테이블(SATC_AC_MSG / SATC_AC_MSGT)로
// 넓힌다.
define view entity ZI_AtcCheckCodeVH
  as select from ztatcnaming
{
      @Search.defaultSearchElement: true
      @EndUserText.label: 'Check Message Code'
  key cast( concat( 'N', concat( objtype, cast( seqnr as abap.char( 3 ) ) ) ) as abap.char( 10 ) ) as CheckCode,

      @EndUserText.label: 'Object Type'
      objtype                                                                                    as ObjectType,

      @Search.defaultSearchElement: true
      @EndUserText.label: 'Rule'
      msgtext                                                                                    as RuleText,

      @EndUserText.label: 'Priority'
      priority                                                                                   as Priority
}
where active = 'X'
