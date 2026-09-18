@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC Exemption Request Item - BO'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
// 아이템의 역할은 상위 요청의 ScopeType 에 따라 다르다.
//   FND       : 면제 대상 그 자체 (1:1). Checksum 이 판정에 쓰인다.
//   OBJ, PCKG : 신청 근거(증빙) 스냅샷. 효력은 오브젝트/패키지 전체이며
//               여기 담긴 건에 한정되지 않는다.
// 패키지와 체크 변형은 헤더에만 둔다. 한 요청의 증빙은 모두 같은 변형에서
// 나오고 같은 패키지에 속하므로, 아이템에 또 두면 어긋날 여지만 생긴다.
//
// I 계층을 두지 않는 이유: BO 밖에서 아이템을 재사용하는 곳이 없다. 이름만
// 바꿔 넘기는 뷰를 하나 더 두면 활성화 오브젝트와 유지보수 지점만 늘어난다.
define view entity ZR_AtcExemptionItem
  as select from ztatcexempti
  association to parent ZR_AtcExemption as _Exemption
    on $projection.ExemptUuid = _Exemption.ExemptUuid
{
      @EndUserText.label: 'Exemption Item UUID'
  key itemuuid       as ItemUuid,

      @EndUserText.label: 'Exemption Request UUID'
      exemptuuid     as ExemptUuid,

      @EndUserText.label: 'Item Number'
      itemno         as ItemNo,

      @EndUserText.label: 'Object Type'
      objecttype     as ObjectType,

      @EndUserText.label: 'Object Name'
      objectname     as ObjectName,

      @EndUserText.label: 'Finding Checksum'
      checksum       as Checksum,

      @EndUserText.label: 'Check Class'
      checkclass     as CheckClass,

      @EndUserText.label: 'Check Message Code'
      checkcode      as CheckCode,

      @EndUserText.label: 'Priority'
      priority       as Priority,

      @EndUserText.label: 'Message Text'
      msgtext        as MessageText,

      @EndUserText.label: 'Created By'
      @Semantics.user.createdBy: true
      createdby      as CreatedBy,

      @EndUserText.label: 'Created At'
      @Semantics.systemDateTime.createdAt: true
      createdat      as CreatedAt,

      @EndUserText.label: 'Changed By'
      @Semantics.user.lastChangedBy: true
      changedby      as LastChangedBy,

      @EndUserText.label: 'Local Last Changed At'
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      loclastchgat   as LocalLastChangedAt,

      _Exemption
}
