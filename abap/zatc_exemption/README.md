# ATC 예외 관리 앱 (ZATC_EXEMPTION)

ATC 위반 현황을 조회하고, 예외를 **패키지/오브젝트 단위로 신청 · 승인 · 반려**하는
RAP 애플리케이션. 설계 배경과 의사결정은 [`docs/atc-exemption-app-design.md`](../../docs/atc-exemption-app-design.md) 참조.

---

## 언어 방침

시스템 언어가 EN 이므로 **사용자에게 보이는 텍스트는 전부 영어**로 둔다.
- 오브젝트명 / 엔터티명 / 필드명 / 요소명
- `@EndUserText.label` — 테이블, CDS 필드, UI 어노테이션, 액션 파라미터
- 메시지 클래스 텍스트

설계 의도를 적은 **소스 주석은 한국어**로 둔다. 개발자용이고 화면에 나가지 않는다.

## 설계 원칙

| 원칙 | 내용 |
|---|---|
| **관리는 CBO, 실행은 표준** | 신청·승인·이력·권한은 CBO 테이블이 원천. 억제 자체는 표준 ATC 메커니즘에 맡긴다. **커스텀 체크 클래스는 만들지 않는다** |
| **앱은 하나** | 신청자와 승인자를 앱으로 나누지 않고 권한 + instance features 로 구분. 런치패드 타일만 2개 |
| **정책은 설정, 코드는 불변** | 적용범위 허용 여부·대상 체크·유효기간 상한·승인 레벨은 전부 설정 테이블 |
| **표준 우선** | 표준에 있는 기능은 다시 만들지 않는다 |

### 요건이 코드가 아니라 설정으로 지켜지는 방식

```
요건 : "네이밍 예외를 패키지/오브젝트 단위로만 등록"

구현 : ztatccfg 초기 데이터 — 키는 체크 변형이다
         네이밍 전용 변형 1행:  fndactive = 공란  -> 드롭다운에 안 뜨고 validation 이 거부
                               objactive = X
                               pkgactive = X

Phase 2 (기타 체크 확장, 확정됨) : 설정 행만 추가 -> 코드 변경 0
```

`IF scopetype = 'FND'` 같은 하드코딩은 어디에도 없다.

---

## ⚠️ 착수 전 확인 필요 (미검증 가정)

시스템 접근 없이 작성했으므로 아래는 **가정**이다. 활성화 전에 반드시 확인할 것.

### 확인 완료

| 항목 | 결과 | 설계에 반영된 것 |
|---|---|---|
| `ZSCM00010` | `createdby` / `createdat` 등 | 같은 이름의 자체 컬럼 제거 (충돌이었음). include 가 감사 필드를 제공하고 managed 런타임이 채운다 |
| `SATC_API_FINDINGS` 키 | `resultid` + `itemid` + `checkrunindex` | 가정했던 `findingkey` 대체. `subobject` 는 없어서 제거 |
| `SATC_API_FINDINGS` 기타 | `checkvariant` / `priority` / `contactperson` / `responsible` 존재 | 컨트롤 테이블을 변형 기준으로, `maxpriority` 검증 추가 |
| **API State** | **릴리즈됨** | RAP 앱 전체를 **ABAP Cloud(Tier 1)** 로 간다. 클래식 패키지 분리 불필요 |
| **적용범위 코드값** | `FND` / `OBJ` / **`PCKG`** | 가정했던 `PKG` 가 틀렸다. 값과 함께 **필드 길이도 `char(4)`** 로 수정 |
| **표준 예외 API** | `CL_SATC_API=>CREATE_API_FACTORY( )->GET_EXEMPTION_CONTROLLER( )` | **Option B 확정.** 커스텀 체크 클래스(Option C) 폐기 |
| 컨트롤러 메소드 | `create_exemption( )` / `approve_exemptions_by_if( )` | **생성이 되므로 앱의 신청 기능이 유효**하다 |
| `create_exemption` 필수 파라미터 | `i_object_type` / `i_object_name` / `i_check_class` / `i_check_code` / `i_contact_person` | 체크·메시지 필수 → 신청서의 `CheckId`/`MessageId` 도 필수. **오브젝트 필수 → 패키지 스코프도 출발점 오브젝트를 보관** |
| 예외 오브젝트 API | `set_object_scope`(타입 `SATC_CI_OBJ_SCOPE`) / `set_check_scope` / `set_reason` / `set_validity_date` / `set_approver` / `set_notification_type` / `send_to_approver` / `unlock` / `get_exemption_id` | **`set_object_scope` 덕분에 패키지 스코프를 표준 예외 1건으로 넘길 수 있다** → 예외 ID 는 헤더에 1개, 오브젝트별 전개 불필요. 유효기간도 표준에 넘어간다 |
| 알림 유형 | `REJ` 반려 시 / `ALWS` 승인·반려 모두 / `NEVR` 없음 | 조직 정책이므로 `ztatccfg-notiftype` 설정으로 |
| 반려 API | `reject_exemptions_by_id( exemption_id, assessment )` | 철회·만료 시 표준 무효화 경로로 사용 |
| `checksum` | 필드명 동일, 타입 `int4` | 아이템 컬럼을 `char(32)` → `int4` 로 수정 |
| `SATC_CI_OBJ_SCOPE` 고정값 | `FND` / `OBJ` / `PCKG` — 우리 값과 동일 | 변환 없이 그대로 전달 |
| `set_check_scope` 고정값 | `FND` finding 1건 / `MSG` 이 메시지 / `CHK` 이 체크 전체 / `ALL` **모든 체크** | `MSG`·`CHK` 만 허용. **`ALL` 은 validation 이 거부** (아래 참조) |
| `approve_exemption_by_id` | `exemption_id`, `assessment` | 건별 승인. 테이블 조립 불필요 |
| `SATC_CI_EXEMPTION_ID` | `SYSUUID_C32` | `extexemptid` 를 `char(32)` → `sysuuid_c32` 로 |

표준 승인 로직은 결국 `SATC_CI_R_EXEMPTION` 의 `state` / `approver` 를 바꾸는 것이고,
그 경로가 위 컨트롤러다. 우리 앱도 같은 경로를 쓴다.

### `SATC_API_FINDINGS` 필드 매핑

뷰의 필드명이 우리 도메인 용어와 다르다. **`ZI_AtcFinding` 한 곳에서만** 맞춘다.
`zcl_atc_finding_reader` 도 `SATC_*` 를 직접 읽지 않고 이 뷰를 읽는다.

| 뷰 필드 | 우리 이름 | 비고 |
|---|---|---|
| `resultid` + `itemid` + `checkrunindex` | (키) | 런 단위. 예외의 영구 키로는 못 씀 |
| `moduleid` | `CheckClass` | RAW16 체크 GUID. `SATC_AC_CHM.ci_id` 조인으로 클래스명(`CL_CI_TEST_DB`)을 얻는다 |
| `module_msg_key` | `CheckCode` | CHAR25 메시지 키 → CHAR10 캐스트 (`DBREAD`, `UPDATE_SUC`) |
| `messagetitle` | `MessageText` | |
| `packagename` | `Devclass` | **SSTRING(30)**. `ZI_AtcFinding` 에서 CHAR30 캐스트 |
| `contractperson` | `ContactPerson` | ⬜ 철자 확인 필요 |
| `checkvariant` / `objecttype` / `objectname` / `priority` / `responsible` / `checksum` | 동일 | |

### 체크 클래스/코드는 findings 뷰에 없다

`SATC_API_FINDINGS` 는 체크를 `moduleid`(RAW16) 로만 식별한다. 표준
`create_exemption( i_check_class )` 가 받는 것은 문자 클래스명이고, 표준 예외 뷰
`SATC_CI_R_EXEMPTION` 도 `checkclass` / `checkcode` 를 문자로 들고 있다.
그래서 환산이 필요하며, 그 환산은 `ZI_AtcFinding` 의 조인 한 곳에만 있다.

```
SATC_API_FINDINGS.moduleid ─→ SATC_AC_CHM.module_id ─→ .ci_id ─→ CheckClass
SATC_API_FINDINGS.module_msg_key ─── CHAR10 캐스트 ─────────────→ CheckCode
```

`SATC_AC_CHM` 의 컬럼은 `module_id` / `module_ix` / `ci_id` 셋뿐이고, 앞의 둘은
GUID 와 인덱스이므로 클래스명은 `ci_id` 다.

🔴 **남은 가정 1개** — `module_msg_key` 가 곧 체크 코드다. `ZI_AtcFinding` 의
캐스트 한 줄이며, 11자 이상인 메시지 키가 있으면 틀린 가정이다.

사용자는 finding 을 골라 신청하므로 이 값들을 직접 입력할 일이 없고, 목록에는
`MessageText`(`messagetitle`)를 보여준다.

### 표준이 이미 들고 있는 예외 상태

뷰에 `exemptionkind` / `exemptionvalidity` / `exemptionapproval` 이 있다.
**표준 기준의 면제 여부를 finding 이 직접 알려준다**는 뜻이다.

우리 대장(`ZI_AtcActiveExemption`) 기준 판정과 나란히 두면 두 값의 차이가 곧
정합성 문제다. `ZI_AtcFinding` 이 이를 `ExemptionMismatch` 로 계산한다.

```
대장에는 승인된 예외가 있는데  +  표준에는 예외가 없다
  -> 승인 시 표준 반영이 실패한 건
  -> 대장은 면제라고 하는데 실제로는 TR 릴리즈가 계속 막힌다
  -> 조회 화면의 "Not Applied to Standard" 필터로 바로 찾는다
```

앞서 별도 배치로 만들려던 정합성 점검의 절반이 이 한 컬럼으로 해결된다.

### 남은 가정

| # | 가정 | 확인 방법 | 틀리면 |
|---|---|---|---|
| 1 | `ZSCM00010` 의 **변경자/변경일시** 필드명이 `changedby` / `changedat` | ADT 에서 ZSCM00010 열기 | CDS 2개 × 2줄 + BDEF mapping 2줄 |
| 2 | `contractperson` 의 철자 (`contactperson` 일 가능성) | 뷰 필드 목록 | `ZI_AtcFinding` 1곳 |
| 4 | `module_msg_key` 가 곧 체크 코드인지 | 예외 1건 등록 후 `SATC_CI_R_EXEMPTION` 의 `checkcode` 와 비교 | `ZI_AtcFinding` 캐스트 1줄 |

> 타입 추측이 여러 번 빗나갔다: `checksum`(→`int4`), 적용범위(→`char4`),
> `packagename`(→`SSTRING`). 체크 식별자도 `chkclass`/`chkcode` 가 findings 뷰에
> 있는 줄 알고 한 번 틀렸다 — 그 두 필드는 샘플 프로그램의 **자체 뷰**에 있는
> 것이고, `SATC_API_FINDINGS` 에는 없다.
| 3 | **`approve_exemptions_by_id` 가 있는지** 🔴 (reject 에 `_by_id` 가 있으니 짝이 있을 것) | `controller->` + Ctrl+Space | 있으면 건별 호출로 끝. 없으면 `_by_if` 의 테이블 행 구조를 확인해야 한다 |
| 4 | **`get_exemption_id( )` 의 반환 타입** 🔴 | 시그니처 | `extexemptid` 를 `char(32)` 로 잡았다. `checksum` 처럼 숫자형이면 컬럼을 고쳐야 한다 |
| 5 | 승인된 예외에 `reject_exemptions_by_id` 를 걸면 면제가 풀리는지 | 테스트 1건 | 안 풀리면 `set_validity_date` 를 과거로 당기는 대안 |
| 6 | `set_check_scope` 의 `ALL` / `FND` 의미 | 도메인 설명 텍스트 | 없어도 진행 가능 |

#### 표준 예외 생성 흐름 (확정)

```abap
DATA(lo_exemption) = lo_controller->create_exemption(
  i_object_type    = ...    " 출발점 오브젝트. 패키지 스코프에서도 필수
  i_object_name    = ...
  i_check_class    = ...    " 체크. 비워 둘 수 없다
  i_check_code     = ...    " 메시지. 비워 둘 수 없다
  i_contact_person = ... ).

lo_exemption->set_object_scope( ... ).       " FND / OBJ / PCKG  <- 범위를 여기서 넓힌다
lo_exemption->set_check_scope( ... ).        " 메시지 단위 / 체크 전체
lo_exemption->set_reason( ... ).
lo_exemption->set_validity_date( ... ).
lo_exemption->set_approver( ... ).
lo_exemption->set_notification_type( ... ).  " REJ / ALWS / NEVR
lo_exemption->send_to_approver( ).           " 승인 요청 제출
lo_exemption->unlock( ).
DATA(lv_id) = lo_exemption->get_exemption_id( ).

" 이어서 바로 승인한다
lo_controller->approve_exemptions_by_if( exemptions_for_approval = ... ).
```

생성만으로는 승인 상태가 되지 않는다. `send_to_approver( )` 로 승인 요청까지 간 뒤
`approve_exemptions_by_if( )` 로 승인해야 한다. **두 호출을 한 번에 이어서 한다** —
중간 상태로 남겨두면 표준 Fiori 승인 앱에서 다른 사람이 먼저 결재할 수 있고,
그러면 CBO 대장을 거치지 않은 승인이 생긴다.

#### `ALL` 규칙 범위를 막는 이유

표준 `set_check_scope` 는 `ALL`(모든 체크)을 받지만 이 앱은 거부한다.

```
ScopeType = PCKG  +  RuleScope = ALL
  -> 그 패키지의 ATC 체크가 통째로 꺼진다
  -> 네이밍 예외를 신청했는데 성능·보안 검증까지 같이 사라진다
  -> 요건("네이밍 건만")을 정면으로 깬다
```

`FND` 는 건 단위라 적용범위(`ScopeType`)에서 이미 다루므로 규칙 축에서는 쓰지 않는다.
결과적으로 `RuleScope` 는 `MSG`(이 메시지) 또는 `CHK`(이 체크 전체) 둘뿐이다.

#### 왜 액션이 아니라 저장 시퀀스에서 부르는가

`create_exemption` 은 DB 를 바꾸고 잠금을 잡는다. RAP 에서 그런 호출은 저장
시퀀스 안에서만 해야 한다.

```
[액션에서 호출]  승인 버튼 -> 표준 예외 생성 -> 사용자가 초안을 버림
                 -> CBO 기록은 없는데 표준 예외만 남는다  X

[저장에서 호출]  승인 버튼 -> CBO 상태만 변경
                 -> 저장 시퀀스에서 표준 예외 생성
                 -> 저장이 실패하면 둘 다 안 된다             O
```

기존 샘플은 같은 이유로 BGPF 를 썼지만, 우리는 백그라운드 처리가 필요 없으므로
RAP 의 **`with additional save`** (saver 클래스의 `save_modified`) 로 충분하다.

ADT 에서 finding 을 우클릭해 "All Objects of Package" 를 고르는 것과 같은 순서다.
**그래서 패키지 스코프에서도 헤더에 오브젝트를 보관한다.** 효력은 패키지 전체이고,
그 오브젝트는 어디서 시작했는지의 기록이다.

`set_object_scope( )` 가 있으므로 **오브젝트마다 예외를 전개할 필요가 없다.**
예외 ID 는 신청서(헤더)에 1개면 되고, 아이템에 상태·실패사유를 둘 이유도 없다. 지금 `zcl_atc_exempt_sync` 는 팩토리까지 호출해
컨트롤러를 얻어 두고, 그 위에서 무엇을 부를지만 비워 둔 상태다.

### 왜 "승인 시" 에 표준 예외를 만드는가

```
[상신 시 생성]  표준 저장소에 승인대기 예외가 생긴다
                 -> 표준 Fiori 승인 앱에서 누군가 먼저 승인할 수 있다
                 -> CBO 대장을 거치지 않은 결재가 생긴다  X

[승인 시 생성]  이 앱에서 결재가 끝난 뒤 승인 상태로 만들어 넣는다
                 -> 표준 저장소에는 이미 결정된 예외만 존재한다
                 -> 결재 창구가 이 앱 하나로 유지된다      O
```

## 오브젝트 목록

### 테이블 4개 (필드명 언더바 없음, CBO 이력 구조 `ZSCM00010` 포함)

| 테이블 | 분류 | Delivery Class | 용도 | 키 |
|---|---|---|---|---|
| `ztatcexempt` | 업무 데이터 | `A` | 예외 신청 헤더 (승인 대상) | `exemptuuid` |
| `ztatcexempti` | 업무 데이터 | `A` | 신청 아이템 (근거 finding) | `itemuuid` |
| `ztatcexemptlog` | 업무 데이터 | `A` | 상태 변경 이력 | `loguuid` |
| `ztatccfg` | **컨트롤** | `C` | 앱 동작 규칙 (대상 변형 + 허용 범위) | `checkvariant` |

### 헤더와 아이템의 역할 구분

겹쳐 보이는 필드가 4개(`objecttype` / `objectname` / `checkid` / `messageid`) 있는데,
같은 값이 들어갈 때가 있어도 뜻이 다르다.

```
헤더  = 무엇을 면제할 것인가 (적용 범위)
아이템 = 무엇이 발견되었는가 (증빙)

OBJ  스코프 : 두 값이 같다
PCKG 스코프 : 헤더의 오브젝트는 비어 있고, 아이템에는 여러 오브젝트가 들어간다
```

헤더의 오브젝트를 아이템에서 유도하지 않는 이유는, 아이템이 신청 시점의 스냅샷이라
나중에 지워지거나 갱신돼도 예외의 적용 범위는 흔들리면 안 되기 때문이다.

패키지(`devclass`)와 체크 변형(`checkvariant`)은 **헤더에만** 둔다. 한 신청서의
증빙은 모두 같은 변형에서 나오고 같은 패키지에 속하므로, 아이템에 또 두면 두 값이
어긋날 여지만 생긴다.

`ztatccfg` 는 업무 데이터가 아니라 **컨트롤 테이블**이다. 답하는 질문은 네 개다.

```
① 이 변형의 결과가 앱 관리 대상인가?  -> activeflg                        (요건: 네이밍 건만)
② 어떤 적용범위를 허용하는가?         -> fndactive / objactive / pkgactive  (요건: 패키지/오브젝트만)
③ 유효기간 상한은?                   -> maxvalidmon
④ 어느 Priority 까지 허용하는가?      -> maxpriority
```

**체크 마스터가 아니다.** 체크의 실체(체크 클래스, 메시지 코드, 체크 제목)는 표준이
갖고 있고 finding 에 실려 온다. 이 테이블은 그 위에 우리 정책만 얹는다.

키를 **체크 변형**으로 잡은 이유: "무엇을 대상으로 볼지" 는 표준이 이미 체크 변형으로
묶어놓았다. 체크 단위로 키를 잡으면 Phase 2 에서 수백 행을 손으로 등록해야 하고
체크가 추가될 때마다 이 테이블을 손봐야 한다. 변형 단위면 Phase 1 은 **1행**,
Phase 2 도 3~4행이면 끝나고 체크 추가는 변형 관리로 흡수된다.

**가동 전에 초기 데이터를 넣어야 한다. 비어 있으면 모든 신청이 거부된다.**

ATC finding 은 별도 테이블에 적재하지 않고 `SATC_API_FINDINGS` 에서 **라이브로 읽는다.**
추세 리포팅이 요건에 없어 스냅샷 계층과 적재 배치, 보관 정책을 두지 않았다.

### CDS

전체 16개다. **I 계층은 BO 밖에서 재사용되는 것에만 둔다.** 이름만 바꿔 넘기는
뷰는 활성화 오브젝트와 유지보수 지점만 늘리고, 구분되는 내용이 없어 오류도
걸러내지 못한다.

```
ztatcexempt                     ztatcexempti        ztatcexemptlog
     │                               │                    │
     ▼  I  헤더만 I 계층을 둔다       │  아이템·이력은 BO   │  밖에서 쓰는 곳이
ZI_AtcExemption                  │  없으므로 R 이 테이블을 직접 읽는다
     │                               │                    │
     ├──► ZI_AtcActiveExemption   승인 + 유효기간 내 예외만 (만료배치·finding 조인이 사용)
     │                               │                    │
     ▼  R  BO 루트 + behavior definition                   │
ZR_AtcExemption ─ composition ─► ZR_AtcExemptionItem ◄─────┘
                └ composition ─► ZR_AtcExemptionLog
     │
     ▼  P  서비스 노출 + UI 어노테이션(ddlx)
ZP_AtcExemption      ZP_AtcExemptionItem      ZP_AtcExemptionLog
```

읽기 전용 뷰는 R 계층이 필요 없어 I → P 2계층이다.

```
SATC_API_FINDINGS ⋈ SATC_AC_CHM(체크 클래스) ⋈ ztatccfg(활성 변형)
                  ⋈ ZI_AtcActiveExemption ×2 (PCKG / OBJ)
     ▼  I
ZI_AtcFinding      표준 스키마를 아는 유일한 오브젝트. 면제 여부 계산
     ▼  P
ZP_AtcFinding      키 = ATC 결과의 키 (ResultId/ItemId/CheckRunIndex)

ZI_AtcScopeVH     ztatccfg 의 허용 플래그를 union 으로 행으로 펼친 값 도움
ZI_AtcVariantVH   활성 체크 변형 목록
ZI_AtcPackageVH   패키지 값 도움
ZD_AtcCreateFromFinding / ZD_AtcReject / ZD_AtcExtend   액션 파라미터(추상 엔터티)
```

| 분류 | 개수 |
|---|---|
| 트랜잭션 BO (I 1 + R 3 + P 3) | 7 |
| 조회 (ZI/ZP_AtcFinding + ZI_AtcActiveExemption) | 3 |
| 값 도움 | 3 |
| 액션 파라미터 (추상 엔터티, 뷰 아님) | 3 |

**필드 레이블은 테이블을 직접 읽는 뷰에 둔다.** 헤더는 `ZI_AtcExemption`,
아이템·이력은 `ZR_*` 다. 위 계층은 그대로 물려받으므로 한 곳만 고치면 되고,
P 의 ddlx 는 화면 배치(위치·중요도·facet)만 담당한다.

### 클래스

| 클래스 | 역할 |
|---|---|
| `zbp_r_atcexemption` | behavior pool. 판정·상태전이·이력 |
| `zcl_atc_config` | 컨트롤 테이블 조회 (세션 버퍼링). 정책값의 단일 창구 |
| `zcl_atc_finding_reader` | ATC 표준 의존 격리. finding 조회 + 영향도 시뮬레이션 |
| `zcl_atc_exempt_sync` | 표준 예외 저장소 반영 **(스텁 — 확인 과제 5)** |
| `zcl_atc_expiry_job` | 만료 전환 + D-30 알림 대상 추출 |
| `zif_atc_exemption` | 상수/타입. 코드값 리터럴의 유일한 위치 |

### 서비스

`ZUI_AtcExemption` (OData V4 UI) → Fiori Elements List Report + Object Page.
P 계층(`ZP_*`)만 노출하고 값 도움은 I 계층을 그대로 쓴다.

---

## 별도 생성이 필요한 오브젝트

RAP 소스로 표현되지 않아 ADT/시스템에서 만들어야 하는 것들.

### 1. Draft 테이블 3개
ADT 에서 `ZR_AtcExemption` BDEF 의 draft table 이름에 커서를 두고 quick fix 로 생성.
```
ztatcexempt_d / ztatcexempti_d / ztatcexemptlog_d
```

### 2. 넘버레인지 오브젝트 `ZATCEXEMP`
구간 `01`, `000000000001` ~ `999999999999`

### 3. 메시지 클래스 `ZATC_EXEMPT`

시스템 언어가 EN 이므로 텍스트는 영어로 등록한다.

| 번호 | 텍스트 |
|---|---|
| 001 | Object scope &1 is not allowed for check variant &2 |
| 002 | Package is required for package scope |
| 003 | Package scope also requires an origin object |
| 004 | Object scope requires object type and object name |
| 005 | Finding scope requires object type and object name |
| 006 | &1 is not a customer namespace package |
| 007 | Package &1 does not exist |
| 008 | Object &1 does not exist |
| 009 | Check variant &1 is not managed by this application |
| 010 | Valid-to date must be later than valid-from date |
| 011 | Validity period must not exceed &1 months |
| 012 | Enter a reason code and a justification of at least &1 characters |
| 013 | A valid exemption for the same scope already exists (&1) |
| 014 | You cannot approve your own exemption request |
| 015 | Enter a rejection reason |
| 016 | New valid-to date must be later than the current one |
| 017 | Finding not found |
| 018 | Priority &1 findings cannot be exempted (allowed from &2) |
| 019 | Check scope &1 is not allowed (use message or check) |
| 020 | Action not allowed for status &1 |

### 4. 권한 오브젝트 `Z_ATCEXEM`

```
필드 : CHECKGRP / DEVCLASS / SCOPETYPE / ACTVT
ACTVT: 01 생성 / 02 변경 / 03 조회 / 43 승인
```

> 🔴 **필드 4개를 지금 모두 만들 것.** Phase 1 에서 값이 비어 있어도 상관없다.
> 운영 후에 권한 오브젝트 필드를 추가하면 PFCG 역할을 전수 재작업해야 하고
> 보안팀 재승인과 감사 이슈가 따라온다. 이 프로젝트에서 나중으로 미뤘을 때
> 비용이 가장 비대칭적으로 큰 항목이다.

### 5. 배치 잡 1개
`zcl_atc_expiry_job` 의 `run( )` 을 일 1회 스케줄 (만료 전환 + D-30 알림 대상 추출).

### 6. 런치패드 타일 2개 (앱은 1개)

| 타일 | 필터 프리셋 | 배치 역할 |
|---|---|---|
| ATC 예외 신청 | Requester = 본인, 상태 = 초안/반려 | 개발자 |
| ATC 예외 승인 | 상태 = 승인대기 | 승인자 |

---

## 컨트롤 테이블 초기 데이터 (`ztatccfg`)

### Phase 1 — 네이밍 전용 변형 1행

| checkvariant | checkgroup | activeflg | fndactive | objactive | pkgactive | maxvalidmon | reasonreq | maxpriority |
|---|---|---|---|---|---|---|---|---|
| `Z_NAMING_ONLY` | NAMING | X | (공란) | X | X | 12 | X | 2 |

전제: **네이밍 체크만 담은 전용 체크 변형**이 있어야 한다. 없으면 SCI 에서 하나
만들고 그 이름을 여기 등록한다. 어떤 체크가 네이밍인지는 변형이 알고 있으므로
우리 테이블에 체크를 열거하지 않는다.

`fndactive` 가 공란이므로 화면 드롭다운에 Finding 이 나타나지 않고,
OData 로 직접 밀어넣어도 `validateScope` 가 거부한다.

`maxpriority = 2` 는 Prio 1 위반을 예외 대상에서 제외한다는 뜻이다
(Priority 는 1 이 가장 심각하다).

### Phase 2 추가 예시 — 코드 변경 없음

| checkvariant | checkgroup | activeflg | fndactive | objactive | pkgactive | maxvalidmon |
|---|---|---|---|---|---|---|
| `Z_PERFORMANCE` | PERF | X | X | X | (공란) | 6 |
| `Z_SECURITY` | SECURITY | X | X | (공란) | (공란) | 3 |

> 성능·보안 체크는 라인별 판단이 본질이라 `FND` 를 열어야 한다.
> 반대로 보안 체크를 `PCKG` 로 열면 그 패키지의 보안 검증이 통째로 꺼진다.
> 체크마다 허용 범위가 정반대여야 하는 이유이며, 허용 플래그를 변형 단위로 둔 이유다.

### 승인 권한은 여기 없다

컨트롤 테이블에 승인 레벨 컬럼을 두지 않는다. 권한 오브젝트 `Z_ATCEXEM` 의
`SCOPETYPE` 필드가 이미 "누가 어느 범위를 승인할 수 있는지" 를 표현하므로
같은 것을 두 군데서 관리하게 된다.

```
팀리더 역할     : SCOPETYPE = OBJ,      ACTVT = 43
아키텍트 역할   : SCOPETYPE = OBJ, PCKG, ACTVT = 43
보안담당 역할   : CHECKGRP  = SECURITY, ACTVT = 43
```

`checkgroup` 을 별도로 둔 이유는 변형명이 버전과 함께 바뀔 수 있기 때문이다
(`Z_NAMING_V1` → `V2`). 권한 역할에는 더 안정적인 분류값을 쓴다.

## Action 구성

8개이며 상태 전이가 각각 달라 합칠 것이 없다. 공통으로 지키는 두 가지가 있다.

**① 상태가 맞지 않으면 거부한다 (조용히 건너뛰지 않는다)**

```
features 가 버튼을 비활성화하지만, OData 직접 호출이나 오래된 화면 상태로
들어올 수 있다. 그냥 건너뛰면 액션이 성공한 것처럼 끝나서 사용자는
왜 아무 일도 없었는지 알 수 없다. -> 메시지 020 으로 거부한다.
```

**② `result` 에는 성공한 건만 담는다**

```
keys 로 다시 읽으면 거부된 건까지 성공한 것처럼 돌려주게 된다.
-> 실제로 변경된 목록(lt_update)으로 다시 읽는다.
```

| Action | 허용 상태 | 추가 검증 |
|---|---|---|
| `submit` | 초안 | 상신 시 영향 건수를 근거 텍스트에 자동 기입 |
| `withdraw` | 승인대기 | |
| `approve` | 승인대기 | 자기승인 금지 (014) |
| `reject` | 승인대기 | 반려 사유 필수 (015) |
| `revoke` | 승인 | 표준 무효화는 saver 에서 |
| `extendValidity` | 승인 | 연장일이 현재보다 뒤여야 함 (016). 승인대기로 되돌려 재승인 |
| `simulateImpact` | (제한 없음) | 승인 판단 근거라 누구나 확인 가능 |
| `createFromFinding` | (static factory) | 대상 finding 없으면 거부 (017) |

## Determination 구성

셋 다 트리거가 달라 합칠 것이 없다. 합치면 바뀌지 않은 필드 때문에 TADIR 조회가
헛도는 쪽이 오히려 손해다.

| Determination | 트리거 | 하는 일 |
|---|---|---|
| `setInitialValues` | create | 상태 = 초안, 신청자, 유효시작일, 규칙범위 기본값 |
| `deriveCheckGroup` | CheckVariant | 컨트롤 테이블에서 체크그룹 파생 |
| `derivePackage` | ObjectType, ObjectName | TADIR 에서 패키지 파생 |
| `derivePreReg` | create (on save) | 증빙 아이템이 없으면 선등록(`PreRegFlag`)으로 판정 |

파생값(`CheckGroup` / `Devclass`)을 CDS 조인으로 계산하지 않고 **저장**하는 이유:
승인된 예외의 범위가 나중에 마스터 데이터를 따라 조용히 바뀌면 안 된다.
오브젝트가 다른 패키지로 옮겨졌다고 승인된 패키지 예외의 적용 대상이 바뀌면
결재를 거치지 않은 범위 변경이 된다. 신청 시점 값으로 고정한다.

**신청번호는 determination 이 아니라 저장 시점(saver)에서 매긴다.**
draft 생성 때 매기면 사용자가 [Create] 후 취소할 때마다 번호가 버려져 구멍이 생긴다.
사용자에게 보이는 번호라 구멍이 눈에 띈다.

## Validation 구성

같은 필드에 걸리는 검증은 한 메소드로 묶었다. 나눠 두면 같은 인스턴스를 여러 번
읽을 뿐이고, **트리거가 다른 것만 따로 두어야** 바뀐 필드에 걸린 검증만 돈다.

| Validation | 트리거 필드 | 검증 내용 | 메시지 |
|---|---|---|---|
| `validateScope` | ScopeType, CheckVariant, Devclass, ObjectType, ObjectName | ① 이 변형에서 그 범위를 쓸 수 있는가 ② 범위별 필수 필드 ③ 대상 실재 + 고객 네임스페이스 | 001~008 |
| `validateVariant` | CheckVariant | ① 관리 대상 변형인가 ② 증빙의 Priority 가 상한 이내인가 | 009, 018 |
| `validateRuleScope` | RuleScope | `MSG` / `CHK` 만 허용 (`ALL` 차단) | 019 |
| `validateValidity` | ValidFrom, ValidTo | 기간 유효성 + 설정된 개월 상한 | 010, 011 |
| `validateReason` | ReasonCode, ReasonText | 사유 코드 + 근거 최소 길이 | 012 |
| `validateOverlap` | (항상) | 동일 범위의 유효 예외 중복 | 013 |

`validateScope` 는 앞 단계가 실패하면 뒤를 보지 않는다. 범위가 틀렸는데 필드 조합
메시지까지 같이 나오면 무엇을 고쳐야 할지 흐려진다.

`validateOverlap` 만 다른 레코드를 DB 조회한다. 무거워서 따로 둔다.

## 동작 요약

### 상태 전이

```
        [신규 / createFromFinding]
                 │
                 ▼
          초안(10) ──[Delete]──► (삭제, 초안만 가능)
                 │
             [Submit]  ← 이 시점에 영향 건수를 근거 텍스트에 자동 기입
                 ▼
          승인대기(20)
           │     │      │
    [Withdraw] [Approve] [Reject]
           │     │      │
           ▼     ▼      ▼
       초안(10) 승인(30) 반려(40)
                 │
         [Revoke]│[ExtendValidity → 20 재승인]
                 ▼
          철회(50) / 만료(60)
```

### 면제 판정

`ZI_AtcFinding` 이 finding 과 `ZI_AtcActiveExemption` 을 조인해 **매번 계산**한다.
상태를 finding 에 저장하지 않는다 — 저장하면 유효기간 만료를 반영할 방법이 없다.

**판정 조건에 소스 라인이 들어가지 않는 것이 요건의 기술적 실체다.**
그래서 코드를 고쳐 라인이 밀려도 OBJ/PCKG 예외는 유지된다.

### 패키지 승인의 파급 효과

패키지 스코프 승인은 신청서에 없던 위반과 **향후 생성될 오브젝트까지** 면제한다.
통제 장치:

- 유효기간 필수 + 설정 기반 상한
- `PCKG` 승인은 더 높은 권한 요구 (권한 오브젝트의 `SCOPETYPE`)
- `simulateImpact` 액션으로 승인 전 면제 건수 확인
- 상신 시 영향 건수를 근거 텍스트에 자동 기입 → **표준 승인 앱에서 결재해도 승인자가 읽을 수 있다**
- 목록에서 `PCKG` 행을 경고색으로 표시 (`ScopeCriticality`)
- 자기승인 금지

---

## 알려진 제약

| 제약 | 내용 | 대응 |
|---|---|---|
| 하위 패키지 포함 | CDS 조인으로 패키지 계층을 전개할 수 없어 면제 판정은 직접 패키지 일치만 본다 | Phase 1 은 `InclSubPkg` 를 읽기 전용으로 잠금. 필요해지면 전개 테이블 추가 |
| ADT 직접 신청 | 개발자가 ADT 에서 `FND` 로 신청하는 경로는 막을 수 없다 | `zcl_atc_exempt_sync~sync_from_standard` 로 CBO 대장에 끌어와 반려/관리 |
| 이중 관리 | CBO 와 표준 저장소 양쪽에 예외가 존재 | `extexemptid` 로 연결 + 정합성 배치. **없으면 반년 뒤 대장과 실제가 어긋난다** |
| 표준 승인 앱 | 이중 승인 창구가 되면 대장 신뢰도가 무너진다 | 표준 앱 권한을 회수해 이 앱을 단일 창구로 운영 권장 |
| 승인 레벨 | 권한 오브젝트 필드로 둘지 역할 매핑으로 둘지 미확정 | 조직 결정 후 `is_approver` 보완 |

---

## Phase 2 (기타 ATC 체크 확장 — 확정)

코드 변경 없이 되는 것:
- `ztatccfg` 에 체크 변형 행 추가 (허용 플래그로 `FND` 활성화 포함)
- 새 체크가 늘어나도 변형에 담기면 되므로 이 테이블은 손대지 않는다
- 권한 역할에 `CHECKGRP` 값 추가

이미 선반영된 것:
- `lineno` / `resultid` / `itemid` / `checkrunindex` 컬럼
- 권한 오브젝트 4개 필드
- 아이템 의미의 스코프별 분기 (`FND` = 대상 / `OBJ`·`PCKG` = 증빙)
- 설정 기반 동적 범위 목록

Phase 2 착수 전 풀어야 할 것:
- **FND 스코프의 영구 식별자.** `resultid` + `itemid` + `checkrunindex` 는 ATC 실행
  단위라 런마다 바뀐다. 이대로 FND 예외를 만들면 다음 실행에서 매칭이 끊긴다.
  코드 변경·재실행에도 유지되는 식별자가 표준에 있는지 확인해야 한다.
  (OBJ / PCKG 스코프는 애초에 이 값을 쓰지 않으므로 Phase 1 에는 영향 없다)

Phase 2 에서 실측이 필요한 것:
- 라이브 조회 성능. 대상 체크가 늘어 건수가 커지면 그때 스냅샷 계층을 도입한다.
  지금 미리 만들지 않은 이유는 추세 리포팅이 요건에 없고, 네이밍만으로는 수천 건
  수준이어서 라이브로 충분하기 때문이다. 추가는 나중에도 어렵지 않다.
