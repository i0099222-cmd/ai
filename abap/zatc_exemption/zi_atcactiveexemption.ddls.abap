@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Currently Valid ATC Exemptions'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
// 승인 상태이고 오늘이 유효기간 안인 요청서의 대상만 남긴다. 한 행 = 대상 한 줄.
// finding 의 면제 여부는 저장하지 않고 이 뷰와 조인해 매번 계산한다.
// 상태를 finding 에 직접 기록하면 유효기간 만료를 반영할 방법이 없어진다.
define view entity ZI_AtcActiveExemption
  as select from ztatcexempti    as Item
    inner join   ZI_AtcExemption as Hdr on Hdr.ExemptUuid = Item.exemptuuid
{
      @EndUserText.label: 'Target UUID'
  key Item.itemuuid   as ItemUuid,

      @EndUserText.label: 'Exemption Request UUID'
      Hdr.ExemptUuid,

      @EndUserText.label: 'Object Scope'
      Item.scopetype  as ScopeType,

      @EndUserText.label: 'Package'
      Item.devclass   as Devclass,

      @EndUserText.label: 'Object Type'
      Item.objecttype as ObjectType,

      @EndUserText.label: 'Object Name'
      Item.objectname as ObjectName,

      @EndUserText.label: 'Check Class'
      Hdr.CheckClass,

      @EndUserText.label: 'Check Message Code'
      Item.checkcode  as CheckCode,

      // CHK 스코프는 체크 전체가 대상이라 코드를 비교하면 안 된다.
      // 조인 조건에서 이 값을 보고 코드 비교 여부를 정한다.
      @EndUserText.label: 'Check Scope'
      Item.rulescope  as RuleScope,

      @EndUserText.label: 'Valid From'
      Hdr.ValidFrom,

      @EndUserText.label: 'Valid To'
      Hdr.ValidTo,

      @EndUserText.label: 'Approver'
      Hdr.Approver
}
where Hdr.ExemptStatus = '30'
  and Hdr.ValidFrom   <= $session.system_date
  and Hdr.ValidTo     >= $session.system_date
