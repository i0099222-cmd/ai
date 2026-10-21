@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ATC Exemption Approver Value Help'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #C,
  sizeCategory: #S,
  dataClass: #MASTER
}
@Search.searchable: true
// 요청서 Approver 의 값 도움. 표준 ATC 승인자 목록(SATC_CI_APPROVER)에 있는 사람만 나온다.
// 표준 예외에 승인자로 넣을 수 있는 사람이 이들뿐이라서다. 이름은 사용자 주소 데이터에서 붙인다.
// 신청자 본인도 나온다. 본인을 고를 수 있는지는 저장 검증이 policy-selfapprove 로 정한다.
define view entity ZI_AtcApproverVH
  as select distinct from satc_ci_approver as Appr

    left outer join usr21 as Usr
      on Usr.bname = Appr.approver

    left outer join adrp as Name
      on Name.persnumber = Usr.persnumber
{
      @Search.defaultSearchElement: true
      @EndUserText.label: 'Approver'
  key Appr.approver  as Approver,

      @Search.defaultSearchElement: true
      @EndUserText.label: 'Name'
      Name.name_text as ApproverName
}
