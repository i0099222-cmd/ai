// ATC 예외 요청/승인 BO.
//
// 요청서(헤더) 한 건에 대상(아이템)이 여러 줄 붙는다. 대상 한 줄 = 표준 예외 1건.
// 사유·유효기간·체크·상태는 요청서 단위이고, 상신·승인·반려·철회도 요청서 단위로
// 한 번에 한다. 대상 하나라도 표준 반영에 실패하면 그 요청서의 처리 전체를 실패로 본다.
//
// 신청자와 승인자는 별도 앱이 아니라 권한 + instance features 로 구분한다.
managed implementation in class zbp_r_atcexemption unique;
strict ( 2 );
with draft;
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
  field ( readonly ) ExemptStatus,
                     Requester,
                     Approver,
                     ApprovedAt,
                     CreatedBy,
                     CreatedAt,
                     LastChangedBy,
                     LastChangedAt,
                     LocalLastChangedAt;

  field ( mandatory ) Title, CheckVariant, CheckClass, ValidTo;

  create;
  update;
  // 초안만 삭제할 수 있다. instance features 가 막는다.
  delete ( features : instance );

  // 초안만 고칠 수 있다. 상신 뒤에 대상이 바뀌면 표준에 만든 예외와 어긋난다.
  draft action ( features : instance ) Edit;
  draft action Activate optimized;
  draft action Discard;
  draft action Resume;
  draft determine action Prepare
  {
    validation validateValidity;
    validation validateReason;
    validation ExemptionItem~validateTarget;
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

  // 이 요청이 현재 몇 건을 덮는지 계산해 메시지로 알린다.
  action ( features : instance ) simulateImpact result [1] $self;

  determination setInitialValues on modify { create; }
  // 변형의 체크가 하나면 체크 클래스를 채우고, 대상 줄에 내려 준다(값 도움 필터용).
  determination deriveCheckClass on modify { field CheckVariant, CheckClass; }

  validation validateValidity on save { field ValidFrom, ValidTo; create; update; }
  validation validateReason   on save { field ReasonCode, ReasonText; create; update; }

  mapping for ztatcexempt
  {
    ExemptUuid         = exemptuuid;
    Title              = title;
    CheckVariant       = checkvariant;
    CheckClass         = checkclass;
    ReasonCode         = reasoncode;
    ReasonText         = reasontext;
    ValidFrom          = validfrom;
    ValidTo            = validto;
    ExemptStatus       = exemptstat;
    Requester          = requester;
    Approver           = approver;
    ApprovedAt         = approvedat;
    CreatedBy          = createdby;
    CreatedAt          = createdat;
    LastChangedBy      = changedby;
    LastChangedAt      = changedat;
    LocalLastChangedAt = loclastchgat;
  }

  association _Item { create; with draft; }
  // _Log 에도 create 가 필요하다. 이력을 쓰는 주체는 behavior pool 이지만
  // EML 의 CREATE BY \_Log 는 이 선언이 있어야 성립한다.
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

  // 범위·규칙 범위·체크 클래스는 파생값이고, 표준 ID/상태는 액션이 쓴다.
  field ( readonly ) ExemptUuid, ItemNo, ScopeType, RuleScope, CheckClass,
                     ExtExemptId, StdStatus,
                     CreatedBy, CreatedAt, LastChangedBy, LocalLastChangedAt;

  field ( mandatory ) Devclass;

  update;
  delete;

  // 새 줄은 범위가 비어 있다. 오브젝트(유형/이름)를 넣으면 OBJ, 패키지만 넣으면 PCKG.
  // 규칙 범위는 PCKG 면 CHK, OBJ 면 코드가 있을 때 MSG 이고 비우면 CHK.
  // 오브젝트 유형과 이름이 다 있으면 패키지는 TADIR 에서 온다.
  determination deriveTarget on modify { create; field Devclass, ObjectType, ObjectName, CheckCode; }

  // 대상 한 줄 검증. 같은 요청서 안 중복과 다른 요청서와의 중복도 여기서 본다.
  validation validateTarget on save { create; update; field Devclass, ObjectType, ObjectName, CheckCode; }

  association _Exemption { with draft; }

  mapping for ztatcexempti
  {
    ItemUuid           = itemuuid;
    ExemptUuid         = exemptuuid;
    ItemNo             = itemno;
    ScopeType          = scopetype;
    Devclass           = devclass;
    ObjectType         = objecttype;
    ObjectName         = objectname;
    CheckClass         = checkclass;
    CheckCode          = checkcode;
    RuleScope          = rulescope;
    ExtExemptId        = extexemptid;
    StdStatus          = stdstatus;
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
