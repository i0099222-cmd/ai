@EndUserText.label: 'ATC Exemption Target - same rule as its request'
@MappingRole: true
// 대상 줄은 그 요청서(_Exemption)를 볼 수 있는 사람에게만 보인다.
define role ZP_ATCEXEMPTIONITEM {
  grant
    select
      on
        ZP_AtcExemptionItem
          where
               _Exemption.Requester = aspect user
            or _Exemption.Approver  = aspect user;
}
