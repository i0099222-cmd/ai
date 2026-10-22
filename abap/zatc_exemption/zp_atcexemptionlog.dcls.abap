@EndUserText.label: 'ATC Exemption History - same rule as its request'
@MappingRole: true
// 이력은 그 요청서(_Exemption)를 볼 수 있는 사람에게만 보인다.
define role ZP_ATCEXEMPTIONLOG {
  grant
    select
      on
        ZP_AtcExemptionLog
          where
               _Exemption.Requester = aspect user
            or _Exemption.Approver  = aspect user;
}
