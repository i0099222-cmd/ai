# ATC 예외 관리 앱 (ZATC_EXEMPTION)

ATC 위반 현황을 조회하고, 예외를 **패키지/오브젝트 단위로 신청 · 승인 · 반려**하는
RAP 애플리케이션. 설계 배경과 의사결정은 [`docs/atc-exemption-app-design.md`](../../docs/atc-exemption-app-design.md) 참조.

---

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

표준 승인 로직은 결국 `SATC_CI_R_EXEMPTION` 의 `state` / `approver` 를 바꾸는 것이고,
그 경로가 위 컨트롤러다. 우리 앱도 같은 경로를 쓴다.

### 남은 가정

| # | 가정 | 확인 방법 | 틀리면 |
|---|---|---|---|
| 1 | `ZSCM00010` 의 **변경자/변경일시** 필드명이 `changedby` / `changedat` | ADT 에서 ZSCM00010 열기 | CDS 2개 × 2줄 + BDEF mapping 2줄 |
| 2 | `SATC_API_FINDINGS` 의 `devclass` / `objecttype` / `objectname` / `lineno` / `checkid` / `messageid` / `msgtext` 필드명 | ADT 에서 뷰 열기 | `zcl_atc_finding_reader` 의 SELECT + `ZI_AtcFinding` 두 곳 |
| 3 | **예외 컨트롤러의 메소드 시그니처** 🔴 | ADT 에서 `GET_EXEMPTION_CONTROLLER( )` 의 반환 타입을 열고 메소드 목록 확인 | `zcl_atc_exempt_sync` 의 세 메소드 본문 |
| 4 | `SATC_API_FINDINGS` 에 `checksum` 필드가 있는지 | 뷰 열기 | 리더 SELECT + `ZI_AtcFinding` + 아이템 테이블 |
| 5 | 예외 컨트롤러가 **스코프 파라미터**를 받는지 (건별 생성만 되는지) | 컨트롤러 메소드 시그니처 | 아래 참조 |

#### 5번 — 예외를 신청서 1건당 만드는가, finding 1건당 만드는가

기존 샘플 프로그램은 아이템마다 `exemption_id` 를 들고 있다. 즉 **finding 1건당
표준 예외 1건**을 만들고 있다는 뜻이고, 그건 FND 스코프 신청이다.

우리 요건은 OBJ / PCKG 스코프이므로 **신청서 1건당 표준 예외 1건**이면 된다.
그래서 `extexemptid` 를 헤더에 두었다.

```
[컨트롤러가 스코프를 받는다]  -> 지금 구조 그대로. 헤더에 예외 ID 1개
[건별 생성만 된다]            -> 아이템마다 예외를 만들어야 하고
                                아이템에 exemption_id / 상태 / 실패사유가 필요하다
                                (샘플이 그렇게 되어 있는 이유일 수 있다)
```

3번을 확인할 때 이것도 같이 보면 된다.

3번만 남으면 표준 반영이 완성된다. 지금 `zcl_atc_exempt_sync` 는 팩토리까지 호출해
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

```
ZI_AtcExemption (root)  ─ composition ─► ZI_AtcExemptionItem
                        └ composition ─► ZI_AtcExemptionLog
     └► ZC_AtcExemption / ZC_AtcExemptionItem / ZC_AtcExemptionLog

ZI_AtcActiveExemption   승인 + 유효기간 내 예외만
ZI_AtcFinding           SATC_API_FINDINGS(라이브) ⋈ ztatccfg(활성 변형) × 예외 → 면제 여부
     └► ZC_AtcFinding   (읽기 전용, 키 = finding 자연키)

ZI_AtcScopeVH     ztatccfg 의 허용 플래그를 union 으로 행으로 펼친 값 도움
ZI_AtcVariantVH   활성 체크 변형 목록
ZI_AtcPackageVH   패키지 값 도움
ZD_AtcCreateFromFinding / ZD_AtcReject / ZD_AtcExtend   액션 파라미터
```

### 클래스

| 클래스 | 역할 |
|---|---|
| `zbp_i_atcexemption` | behavior pool. 판정·상태전이·이력 |
| `zcl_atc_config` | 컨트롤 테이블 조회 (세션 버퍼링). 정책값의 단일 창구 |
| `zcl_atc_finding_reader` | ATC 표준 의존 격리. finding 조회 + 영향도 시뮬레이션 |
| `zcl_atc_exempt_sync` | 표준 예외 저장소 반영 **(스텁 — 확인 과제 5)** |
| `zcl_atc_expiry_job` | 만료 전환 + D-30 알림 대상 추출 |
| `zif_atc_exemption` | 상수/타입. 코드값 리터럴의 유일한 위치 |

### 서비스

`ZUI_AtcExemption` (OData V4 UI) → Fiori Elements List Report + Object Page

---

## 별도 생성이 필요한 오브젝트

RAP 소스로 표현되지 않아 ADT/시스템에서 만들어야 하는 것들.

### 1. Draft 테이블 3개
ADT 에서 BDEF 의 draft table 이름에 커서를 두고 quick fix 로 생성.
```
ztatcexempt_d / ztatcexempti_d / ztatcexemptlog_d
```

### 2. 넘버레인지 오브젝트 `ZATCEXEMP`
구간 `01`, `000000000001` ~ `999999999999`

### 3. 메시지 클래스 `ZATC_EXEMPT`

| 번호 | 텍스트 |
|---|---|
| 001 | 적용범위 &1 은(는) 체크그룹 &2 에서 허용되지 않습니다 |
| 002 | 패키지 스코프에는 패키지를 지정해야 합니다 |
| 003 | 패키지 스코프에는 오브젝트를 지정할 수 없습니다 |
| 004 | 오브젝트 스코프에는 오브젝트 타입과 이름이 필요합니다 |
| 005 | Finding 스코프에는 finding 식별자가 필요합니다 |
| 006 | &1 은(는) 고객 네임스페이스 패키지가 아닙니다 |
| 007 | 패키지 &1 이(가) 존재하지 않습니다 |
| 008 | 오브젝트 &1 이(가) 존재하지 않습니다 |
| 009 | 체크 변형 &1 은(는) 예외 관리 대상이 아닙니다 |
| 010 | 유효종료일은 시작일보다 뒤여야 합니다 |
| 011 | 유효기간은 최대 &1 개월까지 허용됩니다 |
| 012 | 사유 코드와 &1 자 이상의 근거를 입력하세요 |
| 013 | 동일 범위의 유효한 예외가 이미 있습니다 (&1) |
| 014 | 본인이 신청한 예외는 승인할 수 없습니다 |
| 015 | 반려 사유를 입력하세요 |
| 016 | 연장일은 현재 유효종료일보다 뒤여야 합니다 |
| 017 | 대상 finding 을 찾을 수 없습니다 |
| 018 | Priority &1 위반은 예외 대상이 아닙니다 (허용: &2 이상) |

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
