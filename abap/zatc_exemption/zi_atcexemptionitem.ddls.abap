@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC 예외 신청 아이템 (finding)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
// 아이템의 역할은 상위 헤더의 ScopeType 에 따라 다르다.
//   FND       : 면제 대상 그 자체 (1:1). Checksum 이 판정에 쓰인다.
//   OBJ, PCKG : 신청 근거(증빙) 스냅샷. 효력은 오브젝트/패키지 전체이며
//               여기 담긴 건에 한정되지 않는다.
//
// 패키지와 체크 변형은 헤더에만 둔다. 한 신청서의 증빙은 모두 같은 변형에서
// 나오고 같은 패키지에 속하므로, 아이템에 또 두면 어긋날 여지만 생긴다.
define view entity ZI_AtcExemptionItem
  as select from ztatcexempti
  association to parent ZI_AtcExemption as _Exemption
    on $projection.ExemptUuid = _Exemption.ExemptUuid
{
  key itemuuid       as ItemUuid,

      exemptuuid     as ExemptUuid,
      itemno         as ItemNo,

      objecttype     as ObjectType,
      objectname     as ObjectName,
      lineno         as LineNo,
      checksum       as Checksum,
      checkid        as CheckId,
      messageid      as MessageId,
      priority       as Priority,
      msgtext        as MessageText,

      // ZSCM00010 필드 (헤더와 동일한 TODO 가 변경자/변경일시에 적용된다)
      @Semantics.user.createdBy: true
      createdby      as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      createdat      as CreatedAt,
      @Semantics.user.lastChangedBy: true
      changedby      as LastChangedBy,

      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      loclastchgat   as LocalLastChangedAt,

      _Exemption
}
