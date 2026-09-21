@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Selectable ATC Exemption Reasons'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #A,
  sizeCategory: #S,
  dataClass: #CUSTOMIZING
}
// 사유 코드의 값 목록은 표준이 SATC_CI_REASONS 로 들고 있다. 우리 도메인에
// 고정값을 복사해 두지 않고 이 뷰로 읽는 이유는, 복사해 두면 표준이 값을
// 늘렸을 때 우리만 모르는 상태가 되기 때문이다.
//
// not_selectable 인 값은 뺀다. QGOV(Quality Governance)가 그렇고, 넣어서
// 신청하면 표준이 거부한다. 고를 수 없는 값을 화면에 보여줄 이유가 없다.
//
// require_comment 는 걸러내지 않는다. 우리는 사유 서술을 항상 보내고
// (set_reason 의 i_comment), 최소 20자를 강제하므로 언제나 충족된다.
define view entity ZI_AtcReasonVH
  as select from satc_ci_reasons
{
      @EndUserText.label: 'Reason Code'
  key reasoncode      as ReasonCode,

      @EndUserText.label: 'Comment Required'
      require_comment as RequireComment
}
where not_selectable <> 'X'
