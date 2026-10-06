@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'ATC Exemption Request - Interface'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
// 재사용 계층. 테이블을 있는 그대로 노출하고 BO 구조(composition)는 갖지 않는다.
// ZR_AtcExemption(BO 루트)과 ZI_AtcActiveExemption 이 이 뷰를 재사용한다.
// 대상(패키지/오브젝트)은 요청서가 아니라 아이템(ztatcexempti)에 있다.
define view entity ZI_AtcExemption
  as select from ztatcexempt
{
      @EndUserText.label: 'Exemption Request UUID'
  key exemptuuid        as ExemptUuid,

      @EndUserText.label: 'Title'
      title             as Title,

      @EndUserText.label: 'Check Variant'
      checkvariant      as CheckVariant,

      @EndUserText.label: 'Check Group'
      checkgroup        as CheckGroup,

      @EndUserText.label: 'Check Class'
      checkclass        as CheckClass,

      @EndUserText.label: 'Reason Code'
      reasoncode        as ReasonCode,

      @EndUserText.label: 'Justification'
      reasontext        as ReasonText,

      @EndUserText.label: 'Valid From'
      validfrom         as ValidFrom,

      @EndUserText.label: 'Valid To'
      validto           as ValidTo,

      @EndUserText.label: 'Status'
      exemptstat        as ExemptStatus,

      @EndUserText.label: 'Requester'
      requester         as Requester,

      @EndUserText.label: 'Approver'
      approver          as Approver,

      @EndUserText.label: 'Approved At'
      approvedat        as ApprovedAt,

      // --- ZSCM00010 (CBO common history structure) ---
      // managed 런타임이 자동으로 채운다.
      @EndUserText.label: 'Created By'
      @Semantics.user.createdBy: true
      createdby         as CreatedBy,

      @EndUserText.label: 'Created At'
      @Semantics.systemDateTime.createdAt: true
      createdat         as CreatedAt,

      @EndUserText.label: 'Changed By'
      @Semantics.user.lastChangedBy: true
      changedby         as LastChangedBy,

      @EndUserText.label: 'Changed At'
      @Semantics.systemDateTime.lastChangedAt: true
      changedat         as LastChangedAt,

      @EndUserText.label: 'Local Last Changed At'
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      loclastchgat      as LocalLastChangedAt
}
