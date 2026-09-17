@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC 예외 신청 헤더'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
define root view entity ZI_AtcExemption
  as select from ztatcexempt
  composition [0..*] of ZI_AtcExemptionItem as _Item
  composition [0..*] of ZI_AtcExemptionLog  as _Log
{
  key exemptuuid        as ExemptUuid,

      exemptid          as ExemptId,

      // 이 신청에 어떤 정책이 적용되는지를 결정하는 키
      checkvariant      as CheckVariant,
      // ztatccfg 에서 파생. 권한 판정에 쓴다.
      checkgroup        as CheckGroup,

      // 적용 범위. FND / OBJ / PKG.
      // 허용 여부는 ztatccfg 컨트롤 테이블이 판정한다. 뷰에서 값을 거르지 않는다.
      scopetype         as ScopeType,

      devclass          as Devclass,
      inclsubpkg        as InclSubPkg,
      objecttype        as ObjectType,
      objectname        as ObjectName,

      // FND 스코프 전용 (Phase 2 대비 선반영)
      lineno            as LineNo,
      resultid          as ResultId,
      itemid            as ItemId,
      checkrunindex     as CheckRunIndex,

      checkid           as CheckId,
      messageid         as MessageId,
      rulescope         as RuleScope,

      reasoncode        as ReasonCode,
      reasontext        as ReasonText,

      validfrom         as ValidFrom,
      validto           as ValidTo,

      exemptstat        as ExemptStatus,

      requester         as Requester,
      approver          as Approver,
      approvedat        as ApprovedAt,

      extexemptid       as ExtExemptId,
      preregflag        as PreRegFlag,

      // 상태 색. 3 승인(녹) / 2 승인대기(황) / 1 반려·철회·만료(적)
      case exemptstat
        when '30' then 3
        when '20' then 2
        when '40' then 1
        when '50' then 1
        when '60' then 1
        else 0
      end               as StatusCriticality,

      // 적용범위 색. 패키지 스코프는 목록에서 눈에 띄게 둔다.
      // 가장 넓고 향후 생성 오브젝트까지 덮는 범위라 무심코 승인되면 안 된다.
      case scopetype
        when 'PCKG' then 2
        else 0
      end               as ScopeCriticality,

      // --- CBO 공통 이력 구조 ZSCM00010 필드 ---
      // 이 네 필드는 managed 런타임이 자동으로 채운다 (직접 설정하지 않는다).
      @Semantics.user.createdBy: true
      createdby         as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      createdat         as CreatedAt,
      // TODO 확인 필요: ZSCM00010 의 변경자/변경일시 필드명.
      //   changedby / changedat 로 가정했다. lastchangedby / lastchangedat 등
      //   다른 이름이면 이 두 줄과 BDEF mapping 두 줄만 고치면 된다.
      @Semantics.user.lastChangedBy: true
      changedby         as LastChangedBy,
      @Semantics.systemDateTime.lastChangedAt: true
      changedat         as LastChangedAt,

      // RAP OCC. include 와 겹치지 않는 자체 필드.
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      loclastchgat      as LocalLastChangedAt,

      _Item,
      _Log
}
