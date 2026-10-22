@EndUserText.label: 'ATC Exemption Request - own requests only'
@MappingRole: true
// 요청서는 신청자 본인과 그 요청서에 지정된 승인자 본인에게만 보인다.
// 화면(OData)과 CDS 조회에만 걸린다. BO 로직(EML LOCAL MODE)과 테이블을 직접 읽는
// 중복 검사·배치는 영향이 없다. aspect user = 지금 로그인한 사용자 ID.
define role ZP_ATCEXEMPTION {
  grant
    select
      on
        ZP_AtcExemption
          where
               Requester = aspect user
            or Approver  = aspect user;
}
