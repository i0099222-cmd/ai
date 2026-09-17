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
//   FND      : 면제 대상 그 자체 (1:1). FindingKey / LineNo 가 판정에 쓰인다.
//   OBJ, PKG : 신청 근거(증빙) 스냅샷. 효력은 오브젝트/패키지 전체이며
//              여기 담긴 건에 한정되지 않는다.
define view entity ZI_AtcExemptionItem
  as select from ztatcexempti
  association to parent ZI_AtcExemption as _Exemption
    on $projection.ExemptUuid = _Exemption.ExemptUuid
{
  key itemuuid       as ItemUuid,

      exemptuuid     as ExemptUuid,
      itemno         as ItemNo,

      devclass       as Devclass,
      objecttype     as ObjectType,
      objectname     as ObjectName,
      subobject      as SubObject,
      lineno         as LineNo,
      findingkey     as FindingKey,
      checkvariant   as CheckVariant,
      checkid        as CheckId,
      messageid      as MessageId,
      priority       as Priority,
      msgtext        as MessageText,

      // TODO 확인 필요: ZSCM00010 필드명 (헤더와 동일)
      @Semantics.user.createdBy: true
      ernam          as CreatedBy,
      @Semantics.user.lastChangedBy: true
      aenam          as LastChangedBy,

      @Semantics.systemDateTime.createdAt: true
      createdat      as CreatedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      lastchangedat  as LocalLastChangedAt,

      _Exemption
}
