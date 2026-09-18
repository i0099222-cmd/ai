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
define view entity ZI_AtcExemption
  as select from ztatcexempt
{
      @EndUserText.label: 'Exemption Request UUID'
  key exemptuuid        as ExemptUuid,

      @EndUserText.label: 'Exemption Request ID'
      exemptid          as ExemptId,

      @EndUserText.label: 'Check Variant'
      checkvariant      as CheckVariant,

      @EndUserText.label: 'Check Group'
      checkgroup        as CheckGroup,

      @EndUserText.label: 'Object Scope'
      scopetype         as ScopeType,

      @EndUserText.label: 'Package'
      devclass          as Devclass,

      @EndUserText.label: 'Include Subpackages'
      inclsubpkg        as InclSubPkg,

      @EndUserText.label: 'Object Type'
      objecttype        as ObjectType,

      @EndUserText.label: 'Object Name'
      objectname        as ObjectName,

      @EndUserText.label: 'Check Class'
      checkclass        as CheckClass,

      @EndUserText.label: 'Check Message Code'
      checkcode         as CheckCode,

      @EndUserText.label: 'Check Scope'
      rulescope         as RuleScope,

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

      @EndUserText.label: 'Standard Exemption ID'
      extexemptid       as ExtExemptId,

      @EndUserText.label: 'Pre-Registered'
      preregflag        as PreRegFlag,

      // --- ZSCM00010 (CBO common history structure) ---
      // managed 런타임이 자동으로 채운다.
      @EndUserText.label: 'Created By'
      @Semantics.user.createdBy: true
      createdby         as CreatedBy,

      @EndUserText.label: 'Created At'
      @Semantics.systemDateTime.createdAt: true
      createdat         as CreatedAt,

      // TODO 확인 필요: ZSCM00010 의 변경자/변경일시 필드명.
      //   changedby / changedat 로 가정했다. 다르면 이 두 줄과
      //   ZR_AtcExemption, BDEF mapping 만 고치면 된다.
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
