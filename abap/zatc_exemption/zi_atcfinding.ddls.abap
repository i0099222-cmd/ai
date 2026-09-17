@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC 위반 현황 (면제 여부 포함)'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #A,
  sizeCategory: #M,
  dataClass: #MIXED
}
// 조회 앱의 데이터 소스. ATC 결과를 **라이브로** 읽는다.
// 스냅샷 테이블을 두지 않는다 - 추세 리포팅이 요건에 없으므로 중간 적재 계층과
// 배치, 보관 정책을 만들 이유가 없다.
//
// TODO 확인 필요: SATC_API_FINDINGS 의 실제 필드명과 API State.
//   아래 필드명은 가정이다. zcl_atc_finding_reader 의 SELECT 와 같은 가정을 쓴다.
//
// 면제 판정에 소스 라인이 들어가지 않는 것이 요건의 기술적 실체다.
// 그래서 코드를 수정해 라인이 밀려도 OBJ/PKG 예외는 그대로 유지된다.
//
// 알려진 제약: 하위 패키지 포함(InclSubPkg) 은 CDS 조인으로 패키지 계층을 전개할 수
//   없어 여기서는 패키지 직접 일치만 판정한다. Phase 1 은 화면에서 InclSubPkg 를
//   읽기 전용으로 잠가 판정 로직과 어긋나지 않게 한다.
define view entity ZI_AtcFinding
  as select from satc_api_findings as Finding

  // 컨트롤 테이블에 활성으로 등록된 체크만 앱의 대상이다.
  // inner join 이므로 요건 "네이밍 건만" 이 여기서 한 번 더 걸러진다.
  inner join ztatccfg as Cfg
    on  Cfg.checkid   = Finding.checkid
    and Cfg.activeflg = 'X'
    and ( Cfg.messageid = Finding.messageid or Cfg.messageid = '' )

  left outer join ZI_AtcActiveExemption as PkgExempt
    on  PkgExempt.ScopeType  = 'PKG'
    and PkgExempt.Devclass   = Finding.devclass
    and ( PkgExempt.CheckId   = Finding.checkid   or PkgExempt.CheckId   = '' )
    and ( PkgExempt.MessageId = Finding.messageid or PkgExempt.MessageId = '' )

  left outer join ZI_AtcActiveExemption as ObjExempt
    on  ObjExempt.ScopeType  = 'OBJ'
    and ObjExempt.Devclass   = Finding.devclass
    and ObjExempt.ObjectType = Finding.objecttype
    and ObjExempt.ObjectName = Finding.objectname
    and ( ObjExempt.CheckId   = Finding.checkid   or ObjExempt.CheckId   = '' )
    and ( ObjExempt.MessageId = Finding.messageid or ObjExempt.MessageId = '' )

{
  // 스냅샷 테이블이 없으므로 finding 의 자연키가 그대로 엔터티 키가 된다.
  key Finding.devclass      as Devclass,
  key Finding.objecttype    as ObjectType,
  key Finding.objectname    as ObjectName,
  key Finding.subobject     as SubObject,
  key Finding.lineno        as LineNo,
  key Finding.checkid       as CheckId,
  key Finding.messageid     as MessageId,

      Finding.findingkey    as FindingKey,
      Cfg.checkgroup        as CheckGroup,
      Finding.priority      as Priority,
      Finding.msgtext       as MessageText,

      Finding.contactperson as ContactPerson,
      Finding.responsible   as Responsible,

      // 면제 근거가 된 신청번호. 패키지 예외가 더 넓으므로 먼저 본다.
      case
        when PkgExempt.ExemptId is not initial then PkgExempt.ExemptId
        when ObjExempt.ExemptId is not initial then ObjExempt.ExemptId
        else cast( '' as abap.char( 12 ) )
      end                   as ExemptId,

      // 어느 범위의 예외로 면제되었는지
      case
        when PkgExempt.ExemptId is not initial then cast( 'PKG' as abap.char( 3 ) )
        when ObjExempt.ExemptId is not initial then cast( 'OBJ' as abap.char( 3 ) )
        else cast( '' as abap.char( 3 ) )
      end                   as ExemptScopeType,

      // E 면제 / O 미처리. 조회 화면의 기본 필터축이다.
      case
        when PkgExempt.ExemptId is not initial
          or ObjExempt.ExemptId is not initial then cast( 'E' as abap.char( 1 ) )
        else cast( 'O' as abap.char( 1 ) )
      end                   as ExemptionStatus,

      case
        when PkgExempt.ExemptId is not initial then PkgExempt.ValidTo
        when ObjExempt.ExemptId is not initial then ObjExempt.ValidTo
        else cast( '00000000' as abap.dats )
      end                   as ExemptValidTo
}
