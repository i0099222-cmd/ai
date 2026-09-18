@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'ATC Findings with Exemption Status - Interface'
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
// 뷰의 필드명은 우리 도메인 용어와 다르다. 여기서 한 번만 맞춘다.
//   messagetitle   -> 메시지 텍스트 MessageText
//   packagename    -> 패키지        Devclass  (SSTRING -> CHAR30 캐스트)
//   moduleid       -> 체크 클래스   CheckClass (SATC_AC_CHM.ci_id 조인)
//   priority       -> 우선순위      Priority   (ENUMC3 -> INT1 캐스트)
//   module_msg_key -> 체크 코드     CheckCode  (CHAR25 -> CHAR10 캐스트)
//
// 면제 판정에 소스 라인이 들어가지 않는 것이 요건의 기술적 실체다.
// 그래서 코드를 수정해도 OBJ/PCKG 예외는 그대로 유지된다.
//
// 표준 뷰가 이미 예외 상태(ExemptionKind / Validity / Approval)를 들고 있으므로
// 그대로 노출한다. 우리 대장(ZI_AtcActiveExemption)과 나란히 두면 두 값의 차이가
// 곧 정합성 문제다 - CBO 는 승인인데 표준에 반영이 안 된 건을 여기서 찾는다.
//
// 알려진 제약: 하위 패키지 포함(InclSubPkg) 은 CDS 조인으로 패키지 계층을 전개할 수
//   없어 여기서는 패키지 직접 일치만 판정한다. Phase 1 은 화면에서 InclSubPkg 를
//   읽기 전용으로 잠가 판정 로직과 어긋나지 않게 한다.
define view entity ZI_AtcFinding
  as select from satc_api_findings as Finding

  // 컨트롤 테이블에 활성으로 등록된 체크 변형의 결과만 앱의 대상이다.
  // inner join 이라 요건 "네이밍 건만" 이 여기서 걸러지며, 체크 ID 를 뷰에
  // 하드코딩하지 않아도 된다. 무엇이 네이밍 체크인지는 표준의 변형이 안다.
  inner join ztatccfg as Cfg
    on  Cfg.checkvariant = Finding.checkvariant
    and Cfg.activeflg    = 'X'

  // SATC_API_FINDINGS 는 체크를 moduleid(RAW16) 로만 식별한다. 표준 예외 API 가
  // 받는 것은 문자 클래스명(CL_CI_TEST_DB)이므로 체크 모듈 테이블에서 가져온다.
  // 이 조인이 앱에서 유일하게 그 환산을 하는 곳이다.
  //
  // SATC_AC_CHM 의 컬럼은 module_id / module_ix / ci_id 셋뿐이다.
  // 앞의 둘은 GUID 와 인덱스이므로 체크를 사람이 읽는 이름으로 부르는 것은
  // ci_id(Code Inspector 체크 ID = 체크 클래스명) 하나다.
  //
  // left outer 인 이유: 모듈 행이 없다고 finding 이 목록에서 사라지면 안 된다.
  // 그 경우 CheckClass 가 비고, 신청 시 표준 반영이 막히는 것으로 드러난다.
  left outer join satc_ac_chm as Chm
    on Chm.module_id = Finding.moduleid

  left outer join ZI_AtcActiveExemption as PkgExempt
    on  PkgExempt.ScopeType  = 'PCKG'
    and PkgExempt.Devclass   = cast( Finding.packagename as abap.char( 30 ) )
    // 체크까지 맞춰야 "다른 체크의 예외" 를 이 건의 예외로 잘못 읽지 않는다.
    // CHK 스코프는 체크 전체가 대상이므로 코드는 비교하지 않는다.
    and PkgExempt.CheckClass = cast( Chm.ci_id as abap.char( 30 ) )
    and (   PkgExempt.RuleScope = 'CHK'
         or PkgExempt.CheckCode = cast( Finding.module_msg_key as abap.char( 10 ) ) )

  left outer join ZI_AtcActiveExemption as ObjExempt
    on  ObjExempt.ScopeType  = 'OBJ'
    and ObjExempt.Devclass   = cast( Finding.packagename as abap.char( 30 ) )
    and ObjExempt.ObjectType = Finding.objecttype
    and ObjExempt.ObjectName = Finding.objectname
    and ObjExempt.CheckClass = cast( Chm.ci_id as abap.char( 30 ) )
    and (   ObjExempt.RuleScope = 'CHK'
         or ObjExempt.CheckCode = cast( Finding.module_msg_key as abap.char( 10 ) ) )


{
  // 스냅샷 테이블이 없으므로 SATC_API_FINDINGS 의 키를 그대로 엔터티 키로 쓴다.
  // 한 오브젝트에 같은 체크·메시지 위반이 여러 건일 수 있어, 오브젝트 단위
  // 필드만으로는 키가 성립하지 않는다.
  key Finding.resultid           as ResultId,
  key Finding.itemid             as ItemId,
  key Finding.checkrunindex      as CheckRunIndex,

      Finding.checkvariant       as CheckVariant,
      // packagename 은 SSTRING 이라 우리 DEVCLASS(CHAR30)와 타입이 다르다.
      // 경계에서 한 번만 맞춘다.
      cast( Finding.packagename as abap.char( 30 ) ) as Devclass,
      Finding.objecttype         as ObjectType,
      Finding.objectname         as ObjectName,
      // 표준 예외 API 의 i_check_class / i_check_code 로 그대로 넘어가는 값.
      // ABAP 클래스명은 30자가 최대이므로 대장 컬럼과 같은 CHAR30 으로 고정한다.
      // ci_id 의 실제 타입이 무엇이든 조인과 저장이 같은 타입으로 맞는다.
      cast( Chm.ci_id as abap.char( 30 ) ) as CheckClass,
      // 🔴 가정: module_msg_key 가 곧 체크 코드다.
      //   표준 예외 뷰의 checkcode 값(DBREAD, UPDATE_SUC)이 메시지 키의 성격이고
      //   타입만 CHAR25 로 넓다. 11자 이상인 키가 있으면 이 캐스트가 잘라내므로
      //   그때는 가정이 틀린 것이다.
      cast( Finding.module_msg_key as abap.char( 10 ) ) as CheckCode,

      // 코드가 바뀌어도 유지되는 finding 식별자
      Finding.checksum           as Checksum,

      Cfg.checkgroup             as CheckGroup,
      // priority 의 DDIC 타입은 ENUMC3 다. 그 타입을 우리 쪽으로 퍼뜨리지 않고
      // 여기서 INT1 로 바꾼다. ATC 우선순위는 1/2/3 이라 값 손실이 없고,
      // ztatccfg-maxpriority(INT1) 와의 숫자 비교가 그대로 성립한다.
      // 열거 타입이라 이 캐스트가 활성화에서 거부되면 abap.numc( 3 ) 으로
      // 바꾸고 maxpriority / ty_finding-priority 도 같은 타입으로 맞춘다.
      cast( Finding.priority as abap.int1 ) as Priority,
      Finding.messagetitle       as MessageText,

      // TODO 확인 필요: contractperson 의 철자 (contactperson 일 가능성)
      Finding.contractperson     as ContactPerson,
      Finding.responsible        as Responsible,

      // --- 표준이 들고 있는 예외 상태 ---
      Finding.exemptionkind      as StdExemptionKind,
      Finding.exemptionvalidity  as StdExemptionValidity,
      Finding.exemptionapproval  as StdExemptionApproval,

      // --- CBO 대장 기준 면제 여부 ---
      // 신청번호를 두지 않으므로, 어느 예외가 덮고 있는지는 범위로 말한다.
      // 패키지 예외가 더 넓으므로 먼저 본다.
      case
        when PkgExempt.ExemptUuid is not initial then cast( 'PCKG' as abap.char( 4 ) )
        when ObjExempt.ExemptUuid is not initial then cast( 'OBJ' as abap.char( 4 ) )
        else cast( '' as abap.char( 4 ) )
      end                        as ExemptScopeType,

      // E 면제 / O 미처리. 조회 화면의 기본 필터축이다.
      case
        when PkgExempt.ExemptUuid is not initial
          or ObjExempt.ExemptUuid is not initial then cast( 'E' as abap.char( 1 ) )
        else cast( 'O' as abap.char( 1 ) )
      end                        as ExemptionStatus,

      case
        when PkgExempt.ExemptUuid is not initial then PkgExempt.ValidTo
        when ObjExempt.ExemptUuid is not initial then ObjExempt.ValidTo
        else cast( '00000000' as abap.dats )
      end                        as ExemptValidTo,

      // 대장과 표준의 불일치. 정합성 점검이 찾는 것이 이 값이다.
      //   X : 대장에는 승인된 예외가 있는데 표준에는 예외가 없다
      //       -> 승인 시 표준 반영이 실패했다는 뜻. 실제로는 여전히 차단된다.
      case
        when ( PkgExempt.ExemptUuid is not initial or ObjExempt.ExemptUuid is not initial )
         and Finding.exemptionkind is initial
        then cast( 'X' as abap.char( 1 ) )
        else cast( '' as abap.char( 1 ) )
      end                        as ExemptionMismatch
}
