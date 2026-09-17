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

구현 : ztatcscope 초기 데이터
         (NAMING, FND) activeflg = 공란   -> 화면 목록에 안 뜨고 validation 이 거부
         (NAMING, OBJ) activeflg = X
         (NAMING, PKG) activeflg = X

Phase 2 (기타 체크 확장, 확정됨) : 설정 행만 추가 -> 코드 변경 0
```

`IF scopetype = 'FND'` 같은 하드코딩은 어디에도 없다.

---

## ⚠️ 착수 전 확인 필요 (미검증 가정)

시스템 접근 없이 작성했으므로 아래는 **가정**이다. 활성화 전에 반드시 확인할 것.

| # | 가정 | 확인 방법 | 틀리면 |
|---|---|---|---|
| 1 | `ZSCM00010` 의 생성자/변경자 필드명이 `ernam` / `aenam` | ADT 에서 ZSCM00010 열기 | `zi_atcexemption.ddls.abap`, `zi_atcexemptionitem.ddls.abap` 각 2줄 + BDEF mapping 2줄 수정 |
| 2 | `SATC_API_FINDINGS` 필드명 (`findingkey` 포함) | ADT 에서 뷰 열기 | `zcl_atc_finding_reader` 의 SELECT 만 수정 (의존 격리됨) |
| 3 | `SATC_API_FINDINGS` / `TDEVC` 의 API State | ADT → Properties → API State | Cloud 미릴리즈면 리더 클래스를 클래식 패키지로 분리 |
| 4 | 적용범위 코드값 `OBJ` / `PKG` | 표준 scope 필드 → Domain → Value Range | `zif_atc_exemption` 상수 2개 + 설정 데이터 수정 |
| 5 | **표준 예외 생성 API 존재 여부** 🔴 | 표준 Fiori 앱 "Approve ATC Exemptions" 의 OData 서비스 추적 | 없으면 `zcl_atc_exempt_sync` 구현 불가 → 조회/거버넌스 전용으로 후퇴 |

**5번이 가장 중요하다.** 지금 `zcl_atc_exempt_sync` 는 "미구현"을 돌려주는 스텁이다.
그 상태로도 신청·승인·이력·조회는 전부 동작하고 CBO 대장도 채워지지만,
**표준 ATC 억제는 되지 않는다** (TR 릴리즈 차단이 그대로 유지됨).

추적 경로:
```
/IWFND/MAINT_SERVICE 에서 "Approve ATC Exemptions" 의 OData 서비스명 확보
  → ADT 에서 구현 클래스 열기
  → 승인/반려 시 호출하는 클래스·메소드가 곧 zcl_atc_exempt_sync 가 호출할 API
```

---

## 오브젝트 목록

### 테이블 (필드명 언더바 없음, CBO 이력 구조 `ZSCM00010` 포함)

| 테이블 | 용도 | 키 |
|---|---|---|
| `ztatcexempt` | 예외 신청 헤더 (승인 대상) | `exemptuuid` |
| `ztatcexempti` | 신청 아이템 (근거 finding) | `itemuuid` |
| `ztatcexemptlog` | 상태 변경 이력 | `loguuid` |
| `ztatcfinding` | ATC finding 스냅샷 | `findinguuid` |
| `ztatccheck` | 대상 체크 마스터 (설정) | `checkid` + `messageid` |
| `ztatcscope` | 체크그룹 × 적용범위 허용 매트릭스 (설정) | `checkgroup` + `scopetype` |

### CDS

```
ZI_AtcExemption (root)  ─ composition ─► ZI_AtcExemptionItem
                        └ composition ─► ZI_AtcExemptionLog
     └► ZC_AtcExemption / ZC_AtcExemptionItem / ZC_AtcExemptionLog

ZI_AtcActiveExemption   승인 + 유효기간 내 예외만
ZI_AtcFinding           finding × 예외 조인 → 면제 여부 계산
     └► ZC_AtcFinding   (읽기 전용)

ZI_AtcScopeVH / ZI_AtcCheckVH / ZI_AtcPackageVH   값 도움
ZD_AtcCreateFromFinding / ZD_AtcReject / ZD_AtcExtend   액션 파라미터
```

### 클래스

| 클래스 | 역할 |
|---|---|
| `zbp_i_atcexemption` | behavior pool. 판정·상태전이·이력 |
| `zcl_atc_config` | 설정 조회 (세션 버퍼링). 정책값의 단일 창구 |
| `zcl_atc_finding_reader` | ATC 표준 의존 격리. finding 조회 + 영향도 시뮬레이션 |
| `zcl_atc_exempt_sync` | 표준 예외 저장소 반영 **(스텁 — 확인 과제 5)** |
| `zcl_atc_snapshot_job` | finding 스냅샷 적재 + 보관 정책 |
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
| 009 | 체크 &1 은(는) 예외 관리 대상이 아닙니다 |
| 010 | 유효종료일은 시작일보다 뒤여야 합니다 |
| 011 | 유효기간은 최대 &1 개월까지 허용됩니다 |
| 012 | 사유 코드와 &1 자 이상의 근거를 입력하세요 |
| 013 | 동일 범위의 유효한 예외가 이미 있습니다 (&1) |
| 014 | 본인이 신청한 예외는 승인할 수 없습니다 |
| 015 | 반려 사유를 입력하세요 |
| 016 | 연장일은 현재 유효종료일보다 뒤여야 합니다 |
| 017 | 대상 finding 을 찾을 수 없습니다 |

### 4. 권한 오브젝트 `Z_ATCEXEM`

```
필드 : CHECKGRP / DEVCLASS / SCOPETYPE / ACTVT
ACTVT: 01 생성 / 02 변경 / 03 조회 / 43 승인
```

> 🔴 **필드 4개를 지금 모두 만들 것.** Phase 1 에서 값이 비어 있어도 상관없다.
> 운영 후에 권한 오브젝트 필드를 추가하면 PFCG 역할을 전수 재작업해야 하고
> 보안팀 재승인과 감사 이슈가 따라온다. 이 프로젝트에서 나중으로 미뤘을 때
> 비용이 가장 비대칭적으로 큰 항목이다.

### 5. 배치 잡 2개
`zcl_atc_snapshot_job` / `zcl_atc_expiry_job` 을 일 1회 스케줄.

### 6. 런치패드 타일 2개 (앱은 1개)

| 타일 | 필터 프리셋 | 배치 역할 |
|---|---|---|
| ATC 예외 신청 | Requester = 본인, 상태 = 초안/반려 | 개발자 |
| ATC 예외 승인 | 상태 = 승인대기 | 승인자 |

---

## 설정 초기 데이터

### `ztatcscope` — Phase 1

| checkgroup | scopetype | activeflg | apprlevel | maxvalidmon | reasonreq |
|---|---|---|---|---|---|
| NAMING | FND | (공란) | | | |
| NAMING | OBJ | X | 1 (팀리더) | 12 | X |
| NAMING | PKG | X | 2 (아키텍트) | 12 | X |

### `ztatcscope` — Phase 2 추가 예시 (코드 변경 없음)

| checkgroup | scopetype | activeflg | apprlevel | maxvalidmon | reasonreq |
|---|---|---|---|---|---|
| PERF | FND | X | 1 | 6 | X |
| PERF | OBJ | X | 2 | 6 | X |
| PERF | PKG | (공란) | | | |
| SECURITY | FND | X | 3 (보안담당) | 3 | X |
| SECURITY | OBJ | (공란) | | | |
| SECURITY | PKG | (공란) | | | |

> 보안 체크를 `PKG` 로 열면 그 패키지의 보안 검증이 통째로 꺼진다.
> 체크마다 허용 범위가 정반대여야 하는 이유이며, 매트릭스가 2차원인 이유다.

### `ztatccheck` — Phase 1
네이밍 체크의 체크 ID / 메시지 ID 를 SCI 변형 화면에서 확보해 등록.
`checkgroup = NAMING`, `activeflg = X`, `maxpriority` 는 정책에 맞게.

---

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
그래서 코드를 고쳐 라인이 밀려도 OBJ/PKG 예외는 유지된다.

### 패키지 승인의 파급 효과

패키지 스코프 승인은 신청서에 없던 위반과 **향후 생성될 오브젝트까지** 면제한다.
통제 장치:

- 유효기간 필수 + 설정 기반 상한
- `PKG` 는 더 높은 승인 레벨 요구 (`apprlevel`)
- `simulateImpact` 액션으로 승인 전 면제 건수 확인
- 상신 시 영향 건수를 근거 텍스트에 자동 기입 → **표준 승인 앱에서 결재해도 승인자가 읽을 수 있다**
- 목록에서 `PKG` 행을 경고색으로 표시 (`ScopeCriticality`)
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
- `ztatccheck` 에 체크 행 추가
- `ztatcscope` 에 체크그룹 × 범위 행 추가 (`FND` 활성화 포함)
- 권한 역할에 `CHECKGRP` 값 추가

이미 선반영된 것:
- `subobject` / `lineno` / `findingkey` 컬럼
- 권한 오브젝트 4개 필드
- 아이템 의미의 스코프별 분기 (`FND` = 대상 / `OBJ`·`PKG` = 증빙)
- 설정 기반 동적 범위 목록

Phase 2 에서 실측이 필요한 것:
- 스냅샷 데이터량 (수만~수십만 건). 인덱스 `devclass + checkgroup + snapshotdate`, 보관 정책
