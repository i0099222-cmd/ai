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
      checkgroup        as CheckGroup,

      // 적용 범위. FND / OBJ / PKG.
      // 허용 여부는 ztatccfg 컨트롤 테이블이 판정한다. 뷰에서 값을 거르지 않는다.
      scopetype         as ScopeType,

      devclass          as Devclass,
      inclsubpkg        as InclSubPkg,
      objecttype        as ObjectType,
      objectname        as ObjectName,

      // FND 스코프 전용 (Phase 2 대비 선반영)
      subobject         as SubObject,
      lineno            as LineNo,
      findingkey        as FindingKey,

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
        when 'PKG' then 2
        else 0
      end               as ScopeCriticality,

      // --- CBO 공통 이력 구조 ZSCM00010 필드 ---
      // TODO 확인 필요: ZSCM00010 의 실제 필드명.
      //   아래는 ernam(생성자) / aenam(변경자) 가정이다. 다르면 이 두 줄만 고치면 된다.
      @Semantics.user.createdBy: true
      ernam             as CreatedBy,
      @Semantics.user.lastChangedBy: true
      aenam             as LastChangedBy,

      // --- RAP 기술 필드 ---
      // ZSCM00010 의 날짜+시간 분리 필드는 etag 로 쓸 수 없어 별도로 둔다.
      @Semantics.systemDateTime.createdAt: true
      createdat         as CreatedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      lastchangedat     as LastChangedAt,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      loclastchgat      as LocalLastChangedAt,

      _Item,
      _Log
}
