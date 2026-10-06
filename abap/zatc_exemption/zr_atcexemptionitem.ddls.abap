@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC Exemption Request Target - BO'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
// 요청서의 대상 한 줄 = 표준 예외 1건.
// Object Name 이 비면 패키지(PCKG), 있으면 오브젝트(OBJ) 대상이다.
//
// I 계층을 두지 않는 이유: BO 밖에서는 ZI_AtcActiveExemption 만 아이템을 읽고,
// 그 뷰는 테이블을 직접 조인한다.
define view entity ZR_AtcExemptionItem
  as select from ztatcexempti
  association to parent ZR_AtcExemption as _Exemption
    on $projection.ExemptUuid = _Exemption.ExemptUuid
{
      @EndUserText.label: 'Target UUID'
  key itemuuid       as ItemUuid,

      @EndUserText.label: 'Exemption Request UUID'
      exemptuuid     as ExemptUuid,

      @EndUserText.label: 'No.'
      itemno         as ItemNo,

      @EndUserText.label: 'Object Scope'
      scopetype      as ScopeType,

      @EndUserText.label: 'Package'
      devclass       as Devclass,

      @EndUserText.label: 'Object Type'
      objecttype     as ObjectType,

      @EndUserText.label: 'Object Name'
      objectname     as ObjectName,

      @EndUserText.label: 'Check Class'
      checkclass     as CheckClass,

      @EndUserText.label: 'Check Message Code'
      checkcode      as CheckCode,

      @EndUserText.label: 'Check Scope'
      rulescope      as RuleScope,

      @EndUserText.label: 'Standard Exemption ID'
      extexemptid    as ExtExemptId,

      @EndUserText.label: 'Standard Status'
      stdstatus      as StdStatus,

      // 패키지 대상은 목록에서 눈에 띄게 둔다. 가장 넓고 향후 생성 오브젝트까지
      // 덮는 범위라 무심코 승인되면 안 된다.
      @EndUserText.label: 'Scope Criticality'
      case scopetype
        when 'PCKG' then 2
        else 0
      end            as ScopeCriticality,

      // 표준 반영 색. 3 승인 / 2 승인대기 / 1 반려 / 0 아직 등록 전
      @EndUserText.label: 'Standard Status Criticality'
      case stdstatus
        when 'A' then 3
        when 'P' then 2
        when 'R' then 1
        else 0
      end            as StdCriticality,

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
