// ATC 예외 신청/승인 BO.
//
// 앱은 하나이고 BO 도 하나다. 신청자와 승인자는 별도 앱이 아니라
// 권한 + instance features 로 구분한다. 같은 신청서를 신청자는 작성하고
// 승인자는 읽고 결재하므로 화면을 나눌 이유가 없다.
managed implementation in class zbp_i_atcexemption unique;
strict ( 2 );
with draft;
// 표준 예외 생성은 DB 를 바꾸고 잠금을 잡는다. RAP 에서 그런 호출은 저장
// 시퀀스 안에서만 해야 하므로, 액션이 아니라 additional save 에서 수행한다.
with additional save;

define behavior for ZI_AtcExemption alias Exemption
persistent table ztatcexempt
draft table ztatcexempt_d
lock master
total etag LastChangedAt
authorization master ( instance, global )
etag master LocalLastChangedAt
{
  field ( numbering : managed, readonly ) ExemptUuid;

  // 상태와 결재 정보는 액션으로만 바뀐다. 화면에서 직접 못 고친다.
  field ( readonly ) ExemptId,
                     CheckGroup,
                     ExemptStatus,
                     Requester,
                     Approver,
                     ApprovedAt,
                     ExtExemptId,
                     CreatedBy,
                     CreatedAt,
                     LastChangedBy,
                     LastChangedAt,
                     LocalLastChangedAt;

  // Phase 1 은 하위 패키지 포함을 잠근다.
  // ZI_AtcFinding 의 면제 판정이 하위 패키지를 전개하지 못하므로,
  // 열어 두면 화면 표시와 실제 판정이 어긋난다. 필드는 Phase 2 대비로 남긴다.
  field ( readonly ) InclSubPkg;

  // CheckId / MessageId 가 필수인 이유: 표준 create_exemption 이
  // i_check_class 와 i_check_code 를 필수로 요구한다. 비워 두면 표준에 반영할 수 없다.
  field ( mandatory ) CheckVariant, ScopeType, RuleScope, CheckId, MessageId, ValidTo;

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
    validation validateScopeFields;
    validation validateObject;
    validation validateVariant;
    validation validateRuleScope;
    validation validatePriority;
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
  action ( features : instance, authorization : instance ) revoke result [1] $self;

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

  determination setInitialValues on modify { create; }
  determination deriveCheckGroup on modify { field CheckVariant; }
  determination derivePackage    on modify { field ObjectType, ObjectName; }

  validation validateScope       on save { field ScopeType, CheckVariant; create; update; }
  validation validateScopeFields on save { field ScopeType, Devclass, ObjectType, ObjectName; create; update; }
  validation validateObject      on save { field Devclass, ObjectType, ObjectName; create; update; }
  validation validateVariant     on save { field CheckVariant; create; update; }
  validation validateRuleScope   on save { field RuleScope; create; update; }
  validation validatePriority    on save { field CheckVariant; create; update; }
  validation validateValidity    on save { field ValidFrom, ValidTo; create; update; }
  validation validateReason      on save { field ReasonCode, ReasonText; create; update; }
  validation validateOverlap     on save { create; update; }

  mapping for ztatcexempt
  {
    ExemptUuid         = exemptuuid;
    ExemptId           = exemptid;
    CheckVariant       = checkvariant;
    CheckGroup         = checkgroup;
    ScopeType          = scopetype;
    Devclass           = devclass;
    InclSubPkg         = inclsubpkg;
    ObjectType         = objecttype;
    ObjectName         = objectname;
    CheckId            = checkid;
    MessageId          = messageid;
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
  association _Log  { with draft; }
}

define behavior for ZI_AtcExemptionItem alias ExemptionItem
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
    LineNo             = lineno;
    Checksum           = checksum;
    CheckId            = checkid;
    MessageId          = messageid;
    Priority           = priority;
    MessageText        = msgtext;
    CreatedBy          = createdby;
    CreatedAt          = createdat;
    LastChangedBy      = changedby;
    LocalLastChangedAt = loclastchgat;
  }
}

// 이력은 시스템이 쓰고 사용자는 읽기만 한다. create/update/delete 를 열지 않는다.
define behavior for ZI_AtcExemptionLog alias ExemptionLog
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
