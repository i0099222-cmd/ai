// ATC 예외 신청/승인 BO.
//
// 앱은 하나이고 BO 도 하나다. 신청자와 승인자는 별도 앱이 아니라
// 권한 + instance features 로 구분한다. 같은 신청서를 신청자는 작성하고
// 승인자는 읽고 결재하므로 화면을 나눌 이유가 없다.
managed implementation in class zbp_r_atcexemption unique;
strict ( 2 );
with draft;
// 표준 예외 생성은 DB 를 바꾸고 잠금을 잡는다. RAP 에서 그런 호출은 저장
// 시퀀스 안에서만 해야 하므로, 액션이 아니라 additional save 에서 수행한다.
with additional save;

define behavior for ZR_AtcExemption alias Exemption
persistent table ztatcexempt
draft table ztatcexempt_d
lock master
total etag LastChangedAt
authorization master ( instance, global )
etag master LocalLastChangedAt
{
  field ( numbering : managed, readonly ) ExemptUuid;

  // 상태와 결재 정보는 액션으로만 바뀐다. 화면에서 직접 못 고친다.
  field ( readonly ) ScopeText,
                     CheckGroup,
                     ExemptStatus,
                     Requester,
                     Approver,
                     ApprovedAt,
                     ExtExemptId,
                     // derivePreReg 가 증빙 유무로 판정한다. 손으로 못 바꾼다.
                     PreRegFlag,
                     CreatedBy,
                     CreatedAt,
                     LastChangedBy,
                     LastChangedAt,
                     LocalLastChangedAt;

  // Phase 1 은 하위 패키지 포함을 잠근다.
  // ZI_AtcFinding 의 면제 판정이 하위 패키지를 전개하지 못하므로,
  // 열어 두면 화면 표시와 실제 판정이 어긋난다. 필드는 Phase 2 대비로 남긴다.
  field ( readonly ) InclSubPkg;

  // CheckClass 는 언제나 필수다. 표준 예외가 체크 단위다.
  //
  // CheckCode 는 범위에 따라 다르다. OBJ 는 어긴 규칙 하나만 덮으므로 필수이고,
  // PCKG 는 체크 전체(CHK)를 덮어 코드를 보지 않는다. 화면에서 범위에 따라
  // 필수 표시를 바꾸려면 side effects 가 있어야 하는데 릴리스를 탄다. 그래서
  // 정적으로는 선택 입력으로 두고 OBJ 의 필수 여부는 validateScope 가 막는다.
  field ( mandatory ) CheckVariant, ScopeType, CheckClass, ValidTo;

  // 규칙 범위는 적용범위에서 정해진다(deriveRuleScope). 사용자가 CHK/MSG 차이를
  // 알 필요가 없게 고르지 못하게 한다.
  field ( readonly ) RuleScope;

  create;
  update;
  // 초안만 삭제할 수 있다. 승인/반려 건의 삭제 금지는 behavior pool 에서 막는다.
  delete;

  draft action Edit;
  draft action Activate optimized;
  draft action Discard;
  draft action Resume;
  draft determine action Prepare
  {
    validation validateScope;
    validation validateVariant;
    validation validateRuleScope;
    validation validateValidity;
    validation validateReason;
    validation validateOverlap;
  }

  // Prepare 와 같은 검증을 활성 인스턴스에 저장 전에 돌린다.
  // 조회 화면의 requestExemption 이 신청서를 활성으로 만든 뒤 이것으로
  // "이대로 저장하면 통과하는가" 를 먼저 묻는다. 검증은 원래 저장 단계에서만
  // 돌아서, 묻지 않으면 저장에서 실패할 건에도 성공 메시지를 띄우게 된다.
  determine action checkRequest
  {
    validation validateScope;
    validation validateVariant;
    validation validateRuleScope;
    validation validateValidity;
    validation validateReason;
    validation validateOverlap;
  }

  // --- 신청자 액션 ---
  action ( features : instance ) submit   result [1] $self;
  action ( features : instance ) withdraw result [1] $self;

  // --- 승인자 액션 ---
  action ( features : instance, authorization : instance ) approve result [1] $self;
  action ( features : instance, authorization : instance ) reject
    parameter ZD_AtcReject result [1] $self;


  // 유효기간 연장. 재승인을 거치도록 승인대기로 되돌린다.
  action ( features : instance ) extendValidity
    parameter ZD_AtcExtend result [1] $self;

  // 이 예외가 현재 몇 건을 덮는지 계산해 메시지로 알린다.
  // 패키지 스코프 승인 전 승인자가 파급 효과를 확인하는 수단이다.
  action ( features : instance ) simulateImpact result [1] $self;

  // 위반 목록에서 선택한 finding 으로 신청서를 만든다.
  // 패키지/오브젝트 값만 프리필하고 라인 정보는 증빙으로만 넘긴다.
  static factory action createFromFinding
    parameter ZD_AtcCreateFromFinding [1] result [1] $self;

  // 위반이 없는 패키지나 오브젝트 여러 개를 한 번에 선등록한다. 대상마다 신청서 1건을 만들어 바로 상신한다.
  // Create 는 화면 하나가 신청서 1건이라 여러 대상을 받을 수 없어서 따로 둔다.
  static action preRegister deep parameter ZD_AtcPreRegister;

  determination setInitialValues on modify { create; }
  determination deriveCheckGroup on modify { field CheckVariant; }
  determination deriveRuleScope  on modify { create; field ScopeType; }
  determination derivePackage    on modify { field ObjectType, ObjectName; }

  // 선등록 여부는 사용자가 고르는 값이 아니라 등록 시점의 사실이다.
  // 증빙 아이템이 모두 붙은 뒤에 판정해야 하므로 on save 이고,
  // 등록 시점의 사실이므로 create 에서만 정한다.
  determination derivePreReg     on save { create; }

  // 같은 필드에 걸리는 검증은 한 메소드로 묶었다. 나눠 두면 같은 인스턴스를
  // 여러 번 읽을 뿐이고, 트리거가 다른 것만 따로 두면 바뀐 필드에 걸린 검증만 돈다.
  validation validateScope       on save { field ScopeType, CheckVariant, Devclass, ObjectType, ObjectName, CheckCode; create; update; }
  validation validateVariant     on save { field CheckVariant; create; update; }
  validation validateRuleScope   on save { field RuleScope; create; update; }
  validation validateValidity    on save { field ValidFrom, ValidTo; create; update; }
  validation validateReason      on save { field ReasonCode, ReasonText; create; update; }
  // 유일하게 다른 레코드를 DB 조회한다. 무거워서 따로 둔다.
  validation validateOverlap     on save { create; update; }

  mapping for ztatcexempt
  {
    ExemptUuid         = exemptuuid;
    CheckVariant       = checkvariant;
    CheckGroup         = checkgroup;
    ScopeType          = scopetype;
    Devclass           = devclass;
    InclSubPkg         = inclsubpkg;
    ObjectType         = objecttype;
    ObjectName         = objectname;
    CheckClass            = checkclass;
    CheckCode          = checkcode;
    RuleScope          = rulescope;
    ReasonCode         = reasoncode;
    ReasonText         = reasontext;
    ValidFrom          = validfrom;
    ValidTo            = validto;
    ExemptStatus       = exemptstat;
    Requester          = requester;
    Approver           = approver;
    ApprovedAt         = approvedat;
    ExtExemptId        = extexemptid;
    PreRegFlag         = preregflag;
    CreatedBy          = createdby;
    CreatedAt          = createdat;
    LastChangedBy      = changedby;
    LastChangedAt      = changedat;
    LocalLastChangedAt = loclastchgat;
  }

  association _Item { create; with draft; }
  // _Log 에도 create 가 필요하다. 이력을 쓰는 주체는 사용자가 아니라 behavior
  // pool 이지만, EML 의 CREATE BY \_Log 는 이 선언이 있어야 성립한다.
  // 사용자가 이력을 만들지 못하게 막는 것은 projection(ZP_AtcExemptionLog)이
  // create 를 노출하지 않는 것으로 이미 되어 있다.
  association _Log  { create; with draft; }
}

define behavior for ZR_AtcExemptionItem alias ExemptionItem
persistent table ztatcexempti
draft table ztatcexempti_d
lock dependent by _Exemption
authorization dependent by _Exemption
etag master LocalLastChangedAt
{
  field ( numbering : managed, readonly ) ItemUuid;
  field ( readonly ) ExemptUuid, ItemNo, CreatedBy, LastChangedBy, CreatedAt, LocalLastChangedAt;

  update;
  delete;

  association _Exemption { with draft; }

  mapping for ztatcexempti
  {
    ItemUuid           = itemuuid;
    ExemptUuid         = exemptuuid;
    ItemNo             = itemno;
    ObjectType         = objecttype;
    ObjectName         = objectname;
    Checksum           = checksum;
    CheckClass            = checkclass;
    CheckCode          = checkcode;
    Priority           = priority;
    MessageText        = msgtext;
    CreatedBy          = createdby;
    CreatedAt          = createdat;
    LastChangedBy      = changedby;
    LocalLastChangedAt = loclastchgat;
  }
}

// 이력은 시스템이 쓰고 사용자는 읽기만 한다. create/update/delete 를 열지 않는다.
define behavior for ZR_AtcExemptionLog alias ExemptionLog
persistent table ztatcexemptlog
draft table ztatcexemptlog_d
lock dependent by _Exemption
authorization dependent by _Exemption
{
  field ( numbering : managed, readonly ) LogUuid;
  field ( readonly ) ExemptUuid, SeqNr, ActionCode, FromStatus, ToStatus,
                     CommentText, ActionBy, ActionAt;

  association _Exemption { with draft; }

  mapping for ztatcexemptlog
  {
    LogUuid     = loguuid;
    ExemptUuid  = exemptuuid;
    SeqNr       = seqnr;
    ActionCode  = actioncode;
    FromStatus  = fromstat;
    ToStatus    = tostat;
    CommentText = commenttxt;
    ActionBy    = actionby;
    ActionAt    = actionat;
  }
}
