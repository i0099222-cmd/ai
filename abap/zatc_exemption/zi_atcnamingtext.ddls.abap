@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ATC Naming Rule Text per Object Type'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #CUSTOMIZING
}
// 오브젝트 유형마다 네이밍 규칙 문장 하나.
//
// SATC_API_FINDINGS-messagetitle 은 SATC_AC_MSGT 의 코드별 제목이라, 규칙마다
// 문장이 다른 우리 네이밍 체크에는 '...' 만 온다(제목 '&1' 의 자리표시자가 바뀐 것).
// 그래서 조회 앱은 문장을 규칙 테이블에서 직접 가져온다.
//
// 유형마다 한 줄로 줄이는 이유: 한 유형에 규칙이 여러 줄이면 조인이 finding 을
// 불린다. 지금 규칙은 유형마다 문장이 같다(Please check naming rule (DOMAIN)).
// 유형 안에서 규칙마다 문장을 다르게 쓰기 시작하면 여기서는 그중 하나만 보인다 -
// 어느 규칙을 어겼는지는 ADT 결과에서 봐야 한다.
define view entity ZI_AtcNamingText
  as select from ztatcnaming
{
  key objtype        as ObjectType,
      max( msgtext ) as RuleText
}
where active = 'X'
group by objtype
