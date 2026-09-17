# ATC 예외처리 관리 앱 — 개발 설계서

| 항목 | 내용 |
|---|---|
| 대상 시스템 | SAP S/4HANA Private Cloud Edition (PCE), RAP |
| Phase 1 범위 | 네이밍 규칙(Naming Convention) ATC 체크의 예외 조회 / 등록 / 승인 |
| Phase 2 계획 | 성능·보안·클라우드 준비도 등 **기타 ATC 체크로 확장 (확정)** |
| 문서 상태 | 초안 — "미확정 확인 과제"(11장) 3건 해소 후 상세 스펙 확정 |
| 최종 갱신 | 2026-09-17 |

> **읽는 순서 안내**
> - ATC를 처음 접한다면 → 1장부터
> - 설계만 보려면 → 4장(아키텍처)부터
> - 개발 착수 전 필독 → 9장(확장성 원칙), 11장(확인 과제)

---

## 1. ATC 체크 프로세스 이해

### 1.1 등장 요소

| 개념 | 설명 |
|---|---|
| **Code Inspector (SCI)** | 실제 검사 로직. 체크 1개 = 클래스 1개 (`CL_CI_TEST_*` 계열) |
| **Check Variant (체크 변형)** | "어떤 체크를 켤지"의 묶음. 네이밍 전용 변형을 별도 운영하는 것이 정석 |
| **ATC (ABAP Test Cockpit)** | SCI 위의 운영 프레임워크. 실행 스케줄 / 결과 저장 / **예외(Exemption) 승인 워크플로** 담당 |

검사는 SCI가, **결과·예외 관리는 ATC**가 담당한다. 본 앱이 다루는 데이터는 대부분 ATC 영역에 있다.

### 1.2 ATC 실행 경로 4가지

| 경로 | 설명 | 결과 저장 |
|---|---|---|
| ① 개발자 로컬 (ADT) | Eclipse에서 오브젝트 우클릭 → Run As → ABAP Test Cockpit | 중앙 저장 안 됨(기본) |
| ② 중앙 대량 실행 (Run Series) | t-code `ATC` 에서 스케줄. 대상은 Object Set(패키지 / 소프트웨어 컴포넌트 / 사용자 / TR) | **중앙 DB에 Run 단위 적재** ← 본 앱의 주 데이터 소스 |
| ③ 전송요청(TR) 릴리즈 게이트 | TR 릴리즈 시 자동 체크. Priority 1/2 발생 시 릴리즈 차단 | — |
| ④ CI/CD | ADT REST API 기반 파이프라인 호출 | — |

경로 ③이 개발자가 예외를 신청하게 되는 실질적 원인이다.

### 1.3 Finding(위반건) 생명주기

```
ATC 실행
   |
   v
Finding 생성
   키: (오브젝트 타입, 오브젝트명, 서브오브젝트/인클루드, 체크 클래스/체크ID,
        메시지ID, 소스 위치, Priority 1~3)
   |
   +-- 그대로 두면 -> 계속 리포팅 + TR 릴리즈 차단(Prio 1/2)
   |
   +-- 억제(suppress) 수단 3가지
       |
       +-- (a) Pseudo comment / Pragma : 소스에 "#EC ... / ##... 삽입
       |        코드를 수정해야 함. 승인 개념 없음. 이력 추적 취약
       |
       +-- (b) Exemption (예외)  : ATC 표준 승인 워크플로   <-- 본 앱의 대상
       |        요청자 -> 사유코드 + 근거 -> 승인자 지정 -> 승인/반려 -> 유효기간
       |
       +-- (c) Baseline          : 특정 시점 이전 기존 위반 전체를 일괄 억제
                legacy 대량 건 처리용. 신규 위반만 보이게 만드는 장치
```

**세 수단의 용도는 서로 다르다.**

| 상황 | 권장 수단 |
|---|---|
| legacy 기존 네이밍 위반 수천 건 | **(c) Baseline** — 앱으로 등록하려 하면 안 됨 |
| 정책적으로 계속 허용할 영역 (외부 생성 오브젝트, IF 호환 등) | **(b) Exemption** ← 본 앱의 영역 |
| 개별 코드 라인의 일회성 예외 | (a) Pseudo comment (개발자 재량) |

### 1.4 표준 Exemption 프로세스 (As-Is)

```
개발자                                 승인자                       ATC
  | ADT에서 finding 우클릭
  | -> Request Exemption
  |    - 사유 코드
  |    - 근거 텍스트
  |    - 승인자 지정
  |    - Apply exemption to (적용 범위)
  |    - 유효기간
  |------------- 요청 --------------->|
  |                                   | 예외 승인 화면에서 검토
  |                                   | 승인 / 반려
  |                                   |------ 승인 ------------->| 다음 실행부터
  |<------------ 결과 ----------------|                          | 해당 finding 억제
```

### 1.5 "어느 시스템으로 보내는가" — 오해 방지

```
[X] SAP 본사 / SAP 지원포털 / SAP 클라우드로 전송     -> 아니다
[O] 자사 ABAP 시스템 내부의 ATC 예외 저장소에 INSERT  -> 이것이 전부
```

- "보낸다"가 아니라 **"내 시스템 DB에 승인대기 상태로 저장된다"**. 네트워크 외부로 나가는 것은 없다.
- 저장 위치
  - 일반 구성: ATC를 실행한 시스템(통상 DEV)의 예외 저장소
  - 중앙 ATC 시스템 운영 시: 중앙 시스템의 예외 저장소
- 로컬 ADT 실행의 **결과(finding)는 중앙 저장되지 않지만, 예외 요청은 DB에 영구 저장**된다. 그래서 로컬 실행에서도 신청이 가능하다.
- 승인자에게 자동 메일/알림은 **표준 제공 아님**. 승인자가 직접 화면을 열어야 한다 → 실무에서 신청이 방치되는 주 원인이며, 본 앱이 개선할 지점.
- 승인 후 finding은 **삭제되지 않고 "면제(Exempted)"로 분류**된다 → "예외로 덮인 건이 몇 건인가" 조회가 가능하며, 이것이 조회 앱의 데이터 근거가 된다.

### 1.6 표준 Exemption 의 적용 범위 (핵심)

ADT `Request Exemption` → **`Apply exemption to`** 선택 목록이 본 프로젝트 요건의 핵심이다.

| 코드값 | ADT 표기 | 의미 |
|---|---|---|
| `FND` | `Finding` | 그 위반 한 건만 |
| (OBJ 류) | `ABAP Object` | 해당 오브젝트 전체 |
| (PKG 류) | `All Objects of Package` | 해당 패키지 전체 **+ 향후 생성 오브젝트 포함** |

추가로 **"어느 규칙에 적용할지"의 두 번째 축**이 별도 필드로 존재한다.

| 축 | 값 | 의미 |
|---|---|---|
| 축 1 — 적용 대상 | `FND` / OBJ / PKG | 어느 코드에 적용 |
| 축 2 — 적용 규칙 | Message / Check | 메시지 1개만 / 체크의 모든 메시지 |

> ⚠️ **`OBJ`·`PCKG` 코드값은 패턴 추정이다.** 정확한 값은 해당 필드의 Data Element → Domain → Value Range(고정값 목록)에서 확인해야 한다. 코드에는 리터럴 대신 **상수 또는 설정 테이블 값**을 사용한다.

### 1.7 리스크 순서 — 통념과 반대임에 주의

```
FND (건 단위)   : 그 한 건만          -> 가장 좁음, 가장 안전
OBJ (오브젝트)  : 오브젝트 전체        -> 중간
PKG (패키지)    : 패키지 전체 + 미래   -> 가장 넓음, 가장 위험  (!)
```

따라서 **"패키지/오브젝트 단위만 허용"은 리스크 통제 목적이 아니다.** 신청 건수 절감·일괄 정리를 위한 효율 목적이며, 오히려 가장 위험한 `PCKG`를 여는 결정이다. → 6.5장의 통제 장치가 필수다.

### 1.8 네이밍 체크의 특수성

- 네이밍 규칙(접두어·패턴)은 **Check Variant 속성**에 설정된다. 즉 규칙은 시스템/변형 단위 **전역**이며, **"패키지 A만 예외" 같은 설정 항목이 표준에 없다.**
- 따라서 패키지 단위 예외는 Exemption 또는 커스텀 체크 클래스로만 해결 가능하다(4장).
- 네이밍 위반은 **오브젝트 이름 자체가 원인**이므로 오브젝트당 finding이 통상 1건이다. → `FND`와 `OBJ`가 사실상 동일하며, **네이밍에 한해 `FND` 수요는 거의 없다.**

---

## 2. 요구사항 정의

| # | 요건 | 설계 해석 |
|---|---|---|
| R1 | ATC 예외 데이터 **조회** | finding + 예외 현황 조인 조회 앱 |
| R2 | 예외를 **패키지/오브젝트 단위로만** 등록 | 적용 범위를 OBJ / PKG 로 제한. `FND`는 Phase 1 비활성 |
| R3 | 승인 / 거부 / 이력 | 상태 기반 워크플로 + 감사 필드 + 이력 |
| R4 | 대상은 **네이밍 체크만** | 대상 체크를 설정으로 한정 |
| R5 | (확정) **기타 ATC 체크로 확장** | 모든 정책을 설정 테이블 기반으로 설계 |

### 2.1 R2 의 정확한 의미

"등록"이란 **예외 테이블에 레코드 1줄을 INSERT** 하는 것이다. "패키지/오브젝트 단위로만"이란 그 레코드의 **대상 주소 정밀도를 패키지명 또는 패키지명+오브젝트명까지로 제한**하고, 소스 라인/위치는 판정 키로 쓰지 않는다는 뜻이다.

```
[라인 단위 - Phase 1 비활성]
  DEVCLASS=ZFI_LEGACY / OBJECT=ZOLD_POSTING_HELPER / LINE=12
  -> 주석 3줄 추가되면 라인이 15로 밀려 매칭 실패 -> 예외가 풀림

[오브젝트 단위 - 허용]
  DEVCLASS=ZFI_LEGACY / OBJECT_TYPE=CLAS / OBJECT_NAME=ZOLD_POSTING_HELPER
  -> 코드를 수정해도 예외 유지

[패키지 단위 - 허용]
  DEVCLASS=ZFI_LEGACY
  -> 패키지 내 모든 오브젝트 + 향후 생성 오브젝트까지 면제
```

### 2.2 패키지 단위 승인의 파급 효과 (필수 인지 사항)

패키지 `ZFI_LEGACY` 예시:

| 오브젝트 | OBJ 단위 승인 | PKG 단위 승인 |
|---|---|---|
| ① `CLAS ZOLD_POSTING_HELPER` (신청 대상) | 면제 | 면제 |
| ② `CLAS ZOLD_TAX_CALC` | 에러 유지 (별도 신청 필요) | **면제 (신청 안 했는데 풀림)** |
| ③ `PROG ZOLD_REPORT01` | 에러 유지 | **면제** |
| ④ `CLAS ZCL_FI_NEW_POST` (위반 없음) | — | — |
| ⑤ 향후 생성 `ZOLD_XYZ` | 에러 발생 → 또 신청 | **면제 (자동)** ⚠️ |

> 클릭한 finding(①)은 **신청서 작성용 입력값**일 뿐이다. 승인되는 것은 ①이 아니라 **"ZFI_LEGACY는 면제"라는 정책**이다. 이 구분을 놓치면 승인자가 무심코 규칙 전체를 무력화한다.

### 2.3 승인/거부의 단위

```
finding(에러) 여러 건  ----->  예외 신청서 1장  ----->  승인 1회
     N : 1 관계                 (적용범위 = OBJ 또는 PKG)
```

승인/거부는 **신청서(레코드) 단위**로 한다. 패키지마다 승인 버튼을 누르는 것이 아니다.

---

## 3. 표준 기능과 본 앱의 역할 구분

표준 ATC가 이미 OBJ / PKG 범위 예외를 지원하므로, 본 앱은 **새 예외 메커니즘을 만드는 것이 아니라** 표준 예외의 **관리 콘솔 + 거버넌스 레이어**다.

| 표준이 못 하는 것 | 본 앱이 제공하는 가치 |
|---|---|
| 사전 등록 불가 (finding 발생 후에만 신청 가능) | 패키지 예외 사전 선언 |
| 일괄 등록 불가 (ADT에서 한 건씩) | 다건 일괄 등록 |
| 현황 가시성 없음 | 조회 / 대시보드 (R1) |
| ADT(Eclipse) 필수 | Fiori 웹 앱으로 승인·관리 |
| 만료 관리 없음 → 조용히 풀려 갑자기 TR 차단 | 만료 D-30 알림 + 자동 만료 처리 |
| 영향도 미표시 | 승인 전 면제 건수 시뮬레이션 |
| 알림 없음 → 신청 방치 | 승인 대기 알림 |

### 3.1 단일 승인 창구 원칙

```
ADT에서 낸 신청    ---+
                      +--> 동일한 표준 예외 저장소 <--> [본 앱] 이 전건 조회/승인
본 앱에서 낸 신청  ---+
```

개발자가 ADT에서 `FND` 범위로 신청해도, **승인 콘솔이 본 앱이면 "허용되지 않은 범위는 반려" 정책을 적용**할 수 있다. 앱에서만 막고 ADT를 열어두면 R2가 우회 가능해지므로, **본 앱을 승인 단일 창구로 운영**하는 것이 전제다.

---

## 4. 아키텍처 옵션 및 권장안

Z 테이블에 예외를 등록하는 것만으로는 **표준 ATC가 해당 finding을 억제하지 않는다.** 실제 억제 방식을 결정해야 한다.

### Option A — 리포팅 전용 (표준 미간섭)

```
ATC 실행 -> finding 그대로 존재
             +-> [조회 앱] 이 예외 테이블과 조인해 "예외등록됨"으로 분류/표시
```
- 장점: 표준 미변경, 최소 개발, 리스크 최저
- 단점: **TR 릴리즈 차단은 그대로 발생** (개발자 고통 미해결)
- 적합: 목적이 거버넌스 현황 관리·보고인 경우

### Option B — 표준 Exemption 자동 생성 ★ 권장

```
[앱] 패키지/오브젝트 단위 예외 등록 + 승인
       |
       v (예외 생성 API)
표준 ATC 예외 저장소
       |
       v
ADT / TR 릴리즈 게이트 / CI-CD 전부에서 일관되게 억제
```
- 장점: 표준 메커니즘 그대로 사용. 커스텀 체크 클래스 불필요
- 전제: **예외 생성 API 존재 여부 확인 필요** (11장 ①)
- 단점: 신규 오브젝트는 "ATC 실행 → 반영"의 시간 지연 존재

### Option C — 커스텀 체크 클래스

```
표준 네이밍 체크를 변형에서 제외
       |
       v
ZCL_CI_TEST_NAMING (CL_CI_TEST_* 상속)
  -> 위반 판정 전 예외 테이블 조회 -> 등록된 패키지/오브젝트면 report 생략
```
- 장점: 등록 즉시 반영, TR 게이트까지 완전 제어, API 의존 없음
- 단점: 표준 체크 로직을 커스텀이 대체 → 표준 개선/노트 수혜 상실, 유지보수 책임 이전
- **PCE 주의**: `CL_CI_TEST_*` 는 ABAP Cloud(Tier 1)에서 사용 불가. 체크 클래스는 **클래식 ABAP 패키지(Tier 3)** 에 두고, RAP 앱과는 read 전용 래퍼 API로 연결하는 2-패키지 구성이 필요

### Option D — Baseline 병행 (A/B/C 무엇을 택하든 전제)

legacy 대량 위반은 **Baseline**으로 일괄 처리하고, 앱은 Baseline 이후의 정책적 예외만 관리한다. legacy 수천 건을 앱으로 등록하는 것은 낭비다.

### 권장 로드맵

```
Phase 1 : Option A (조회) + Option D (Baseline 정리)   -> 즉시 효과, 리스크 최소
Phase 2 : 확인 과제 (11장 ①) 결과에 따라
            예외 생성 API 있음 -> Option B  (권장)
            없음               -> Option C
```

---

## 5. 데이터 모델

### 5.1 전체 구조

```
[설정]
  ZATC_CHK_CFG    대상 체크 마스터 (체크ID -> 체크그룹 매핑)
  ZATC_SCOPE_CFG  체크그룹 x 적용범위 허용 매트릭스

[신청]
  ZATC_EXEMPT_H   예외 신청 헤더  (승인 대상)
        | 1
        | N
  ZATC_EXEMPT_I   예외 신청 아이템 (finding)
  ZATC_EXEMPT_LOG 상태 변경 이력

[결과]
  ZATC_FINDING    ATC finding 스냅샷 (조회 성능 / 추세 분석용)
```

### 5.2 `ZATC_SCOPE_CFG` — 체크그룹 × 적용범위 허용 매트릭스 ★ 설계 핵심

체크 종류마다 허용해야 할 범위가 **정반대**다. 이 매트릭스 하나로 Phase 1 요건과 Phase 2 확장이 동시에 만족된다.

| CHECK_GROUP | SCOPE | ACTIVE | 승인 레벨 | 최대 유효기간 | 사유 필수 |
|---|---|---|---|---|---|
| `NAMING` | `FND` | ✗ | — | — | — |
| `NAMING` | `OBJ` | ✓ | 팀리더 | 12개월 | Y |
| `NAMING` | `PCKG` | ✓ | **아키텍트** | 12개월 | Y |
| `PERF` | `FND` | ✓ | 팀리더 | 6개월 | Y |
| `PERF` | `OBJ` | ✓ | 아키텍트 | 6개월 | Y |
| `PERF` | `PCKG` | ✗ | — | — | — |
| `SECURITY` | `FND` | ✓ | **보안담당** | 3개월 | Y |
| `SECURITY` | `OBJ` | ✗ | — | — | — |
| `SECURITY` | `PCKG` | ✗ | — | — | — |

- **Phase 1**: `NAMING` 3행만 등록, `FND` = `✗` → R2("패키지/오브젝트 단위만") 충족
- **Phase 2**: `PERF` / `SECURITY` 행 추가 → **코드 변경 0**
- 화면의 범위 선택 옵션은 이 테이블을 읽어 **동적 생성**한다

> 보안 체크를 `PCKG` 로 열면 해당 패키지의 보안 검증이 전부 꺼진다. 체크별 차등이 필수인 이유다.

### 5.3 `ZATC_CHK_CFG` — 대상 체크 마스터

| 필드 | 설명 |
|---|---|
| `CHECK_ID` | 체크 클래스 / 체크 ID |
| `MESSAGE_ID` | 메시지 ID (공란 = 체크 전체) |
| `CHECK_GROUP` | `NAMING` / `PERF` / `SECURITY` / `CLOUD` … |
| `ACTIVE` | 앱 취급 대상 여부 |
| `MAX_PRIORITY` | 예외 허용 가능한 최대 Priority (예: Prio 1은 예외 금지) |
| `DESCRIPTION` | 설명 |

Phase 1 은 `NAMING` 행만 `ACTIVE = ✓`. 이로써 R4("네이밍만")가 하드코딩 없이 충족된다.

### 5.4 `ZATC_EXEMPT_H` — 예외 신청 헤더

| 필드 | 타입(예) | 비고 |
|---|---|---|
| `EXEMPT_UUID` | `SYSUUID_X16` | Key |
| `EXEMPT_ID` | `CHAR12` | 넘버레인지 기반 표시용 번호 |
| `CHECK_GROUP` | `CHAR10` | 설정 테이블 참조 |
| `SCOPE_TYPE` | `CHAR3` | `FND` / OBJ / PKG — **설정으로 허용 여부 판정** |
| `DEVCLASS` | `DEVCLASS` | 대상 패키지 (OBJ 스코프 시 TADIR에서 파생) |
| `INCL_SUBPACKAGES` | `ABAP_BOOLEAN` | 하위 패키지 포함 여부 |
| `OBJECT_TYPE` | `TROBJTYPE` | OBJ / FND 스코프 시 필수 |
| `OBJECT_NAME` | `SOBJ_NAME` | OBJ / FND 스코프 시 필수 |
| `SUB_OBJECT` | `CHAR40` | 인클루드명 — **FND 대비 선반영** |
| `LINE_NO` | `INT4` | 소스 라인 — **FND 대비 선반영** |
| `FINDING_KEY` | `CHAR60` | 표준 finding 식별자 — **FND 대비 선반영** (11장 ④) |
| `CHECK_ID` / `MESSAGE_ID` | | 대상 규칙. 공란 = 체크 전체 |
| `RULE_SCOPE` | `CHAR10` | 축 2: Message / Check |
| `REASON_CODE` | `CHAR4` | 사유 코드 (고정값) |
| `REASON_TEXT` | `STRING` | 근거. 필수 + 최소 길이 검증 |
| `VALID_FROM` / `VALID_TO` | `DATS` | **`VALID_TO` 필수, 상한은 설정값** |
| `STATUS` | `CHAR2` | `10` 초안 / `20` 승인대기 / `30` 승인 / `40` 거부 / `50` 철회 / `60` 만료 |
| `REQUESTER` / `APPROVER` | `UNAME` | |
| `APPROVED_AT` | `TIMESTAMPL` | |
| `EXT_EXEMPTION_ID` | `CHAR32` | **표준 예외 저장소에 생성된 ID** — 철회/연장 시 역추적에 필수 |
| `CREATED_BY/AT`, `CHANGED_BY/AT` | | 감사 |
| `LOCAL_LAST_CHANGED_AT` | `TIMESTAMPL` | OCC (etag) |

#### `SUB_OBJECT` / `LINE_NO` / `FINDING_KEY` 를 지금 넣어야 하는 이유

Phase 2 에서 `FND` 를 활성화할 때 이 3개 컬럼이 없으면 **운영 데이터가 있는 상태에서 테이블 구조 변경 + CDS/BDEF/서비스 전면 수정 + 마이그레이션 + 전 구간 재테스트**가 발생한다. 지금 넣는 비용은 사실상 0이며, 값이 없으면 공란으로 남는다.

### 5.5 `ZATC_EXEMPT_I` — 신청 아이템 ★ 의미 주의

**아이템의 역할은 적용범위에 따라 달라진다.** 이를 명시하지 않으면 "아이템에 담긴 건만 면제"로 구현되어 R2가 동작하지 않는다.

| SCOPE | 아이템의 역할 | 위치 정보 |
|---|---|---|
| `FND` | **면제 대상 그 자체** (1:1) | `LINE_NO` / `FINDING_KEY` **필수** |
| `OBJ` | 신청 근거(증빙) 스냅샷. 효력은 오브젝트 전체 | 참고용 |
| `PCKG` | 신청 근거(증빙) 스냅샷. 효력은 패키지 전체 + 향후 오브젝트 | 참고용 |

```
예) 패키지 신청서
  Header : SCOPE=PCKG, DEVCLASS=ZFI_LEGACY, VALID_TO=2027-12-31
  Item   : ZOLD_POSTING_HELPER / ZOLD_TAX_CALC / ZOLD_REPORT01  (증빙 3건)

  -> 승인 후 효력 : ZFI_LEGACY 전체 (증빙 3건 + 향후 생성 오브젝트 전부)
  -> Item 은 "승인 당시 상황"의 기록으로만 남는다
```

**이 분기 판정을 Phase 1부터 로직에 반영**해야 한다. Phase 2에서 끼워 넣으면 기존 데이터와 섞여 판정 버그가 발생한다.

### 5.6 `ZATC_EXEMPT_LOG` — 상태 이력

`EXEMPT_UUID` + `LOG_SEQ` / 변경일시 / 변경자 / from-status / to-status / 코멘트.
감사 대응 시 "누가 언제 무엇을 승인했는지"의 유일한 근거다.

### 5.7 `ZATC_FINDING` — finding 스냅샷

ATC Run 결과를 배치로 적재한다.

| 필드 | 설명 |
|---|---|
| `SNAPSHOT_DATE` / `RUN_ID` | 스냅샷 시점, ATC 런 |
| `DEVCLASS` / `OBJECT_TYPE` / `OBJECT_NAME` / `SUB_OBJECT` / `LINE_NO` | 위치 |
| `FINDING_KEY` | 표준 finding 식별자 |
| `CHECK_ID` / `MESSAGE_ID` / `CHECK_GROUP` | 규칙 |
| `PRIORITY` / `MESSAGE_TEXT` | |
| `CONTACTPERSON` / `RESPONSIBLE` | 담당자 (My Findings 필터용) |

**스냅샷을 두는 이유**
1. ATC 내부 테이블 직접 조회 의존 최소화 (업그레이드 내구성)
2. 대량 건 UI 성능 확보
3. 추세 분석(월별 위반 감소) 리포팅 가능

**Phase 2 대비 필수 설계**

```
데이터량  네이밍만 : 수천 건
          전체 체크 : 수만 ~ 수십만 건  (성능/클라우드준비도가 특히 많음)
```

- 인덱스: `DEVCLASS + CHECK_GROUP + SNAPSHOT_DATE`
- 보관 정책: 스냅샷일자 기준 N일 경과 건 삭제 배치 (보관기간은 설정값)
- 조회 화면: **필수 필터 강제** (패키지 또는 체크그룹 미지정 시 조회 차단)
- 집계는 CDS 레벨에서 처리. ABAP 루프 집계 금지

### 5.8 CDS 계층

```
ZI_ATC_EXEMPT (interface, root) --- composition ---> ZI_ATC_EXEMPT_I
                                                --> ZI_ATC_EXEMPT_LOG
      |
      +-- ZC_ATC_EXEMPT (projection, UI annotation) --> Service Definition / Binding

ZI_ATC_FINDING --- association ---> ZI_ATC_EXEMPT   (범위 매칭)
      +-- ZC_ATC_FINDING (읽기전용, "예외적용여부" 계산 필드 포함)

Value Help : ZI_ATC_VH_PACKAGE / ZI_ATC_VH_OBJTYPE / ZI_ATC_VH_REASON
             ZI_ATC_VH_SCOPE (설정 테이블 기반 동적 목록)
```

### 5.9 면제 판정 로직

finding 상태는 **저장하지 않고 조회 시 계산**한다. (상태를 finding에 직접 기록하면 만료 처리가 불가능해진다)

```
각 finding 에 대해:

  finding = { DEVCLASS, OBJECT_TYPE, OBJECT_NAME, SUB_OBJECT, LINE_NO,
              FINDING_KEY, CHECK_ID, MESSAGE_ID }

  예외 헤더 중 STATUS = 30(승인) AND 오늘이 VALID_FROM ~ VALID_TO 범위 내 인 것을 대상으로

    SCOPE_TYPE = PKG :  DEVCLASS 일치 (INCL_SUBPACKAGES 시 하위 포함)
                        AND 규칙(CHECK_ID / MESSAGE_ID) 일치
    SCOPE_TYPE = OBJ :  DEVCLASS + OBJECT_TYPE + OBJECT_NAME 일치
                        AND 규칙 일치
    SCOPE_TYPE = FND :  위 조건 + FINDING_KEY (또는 SUB_OBJECT + LINE_NO) 일치
                        <- Phase 2

  매칭되면 -> 면제(Exempted), 근거 신청번호 표시
  매칭 없음 -> 미처리 (에러 유지, TR 릴리즈 차단)
```

`PCKG` / `OBJ` 판정에는 **라인 정보가 들어가지 않는다.** 이것이 R2 의 기술적 실체이며, 코드 수정에 강건한 이유다.

---

## 6. RAP BO 동작 설계

```abap
managed implementation in class ZBP_I_ATC_EXEMPT unique;
strict ( 2 );
with draft;
```

### 6.1 Determination

| 이름 | 트리거 | 내용 |
|---|---|---|
| `setInitialValues` | on modify create | `EXEMPT_ID`(넘버레인지), `STATUS=10`, `REQUESTER=sy-uname`, `VALID_FROM` |
| `derivePackage` | on modify, field `OBJECT_NAME` | TADIR 에서 오브젝트의 패키지 파생 → `DEVCLASS` |
| `deriveCheckGroup` | on modify, field `CHECK_ID` | `ZATC_CHK_CFG` 에서 `CHECK_GROUP` 파생 |

### 6.2 Validation

| 이름 | 검증 내용 |
|---|---|
| `validateScopeAllowed` | `ZATC_SCOPE_CFG` 에서 (`CHECK_GROUP`, `SCOPE_TYPE`) 의 `ACTIVE` 조회. 비활성이면 거부 → **R2 강제 지점** |
| `validateScopeFields` | `PCKG`면 오브젝트 필드 공란, `OBJ`면 오브젝트 필드 필수, `FND`면 위치 정보까지 필수 |
| `validatePackage` | TDEVC 존재 + 고객 네임스페이스(Z/Y//XXX/) 여부 |
| `validateObject` | TADIR 존재 + 지원 오브젝트 타입 |
| `validateCheck` | `ZATC_CHK_CFG` 에 `ACTIVE` 로 등록된 체크인지. `MAX_PRIORITY` 초과 시 거부 |
| `validateValidity` | `VALID_TO > VALID_FROM`, 설정된 최대 유효기간 초과 금지 |
| `validateOverlap` | 동일 범위·규칙의 유효한 승인 예외 중복 금지 |
| `validateReason` | 설정상 사유 필수면 `REASON_CODE` + `REASON_TEXT` 최소 길이 검증 |

> `IF scope_type = 'FND'` 같은 **하드코딩 금지.** 반드시 설정 테이블을 조회한다.

### 6.3 Action

| 액션 | 상태 전이 | 권한 |
|---|---|---|
| `submit` | 10 → 20 (승인자 지정 필수) | 신청자 |
| `withdraw` | 20 → 10 (상신 철회, 레코드 유지) | 신청자 |
| `approve` | 20 → 30 (`APPROVED_AT` 기록, Option B 시 표준 예외 생성 후 `EXT_EXEMPTION_ID` 저장) | **설정된 승인 레벨** |
| `reject` | 20 → 40 (거부 사유 필수) | 승인자 |
| `revoke` | 30 → 50 (승인된 예외 무효화. Option B 시 표준 예외도 삭제/무효화) | 승인자 / 관리자 |
| `extendValidity` | 유효기간 연장 → 재승인 경유 | 신청자 → 승인자 |
| `simulateImpact` (static/factory) | 해당 범위가 현재 몇 건의 finding 을 면제하는지 계산 | 승인자 |

**제약**
- `delete` 는 `STATUS = 10`(초안)에서만 허용. **승인/거부된 건은 삭제 금지** (감사 근거 소실)
- 자기승인 금지: `REQUESTER = APPROVER` 차단
- `withdraw` 와 `delete` 의 구분을 명확히 문서화 (철회 = 상태 되돌림, 삭제 = 레코드 소멸)

### 6.4 그 외

- `AUTHORIZATION MASTER ( instance )`
- `etag master LOCAL_LAST_CHANGED_AT`, draft + total etag
- `field ( readonly ) STATUS, REQUESTER, APPROVED_AT, EXT_EXEMPTION_ID, ...`

### 6.5 패키지 단위 예외의 통제 장치 (필수)

| 장치 | 내용 |
|---|---|
| 유효기간 필수 + 상한 | 설정값 기반. 무기한 금지 |
| 승인 권한 차등 | `OBJ` = 팀리더 / `PCKG` = **아키텍트 전용** (설정 테이블) |
| 영향도 강제 노출 | 승인 화면에 면제 건수 + "향후 생성 오브젝트 포함" 경고 |
| 신규 오브젝트 알림 | 패키지 예외 하에 새 위반 오브젝트 발생 시 월간 리포트 통보 |
| 만료 D-30 알림 | 조용히 풀려 갑자기 TR 차단되는 사고 방지 |
| 자기승인 금지 | 신청자 = 승인자 불가 |
| Prio 제한 | `MAX_PRIORITY` 초과 건은 예외 신청 자체를 차단 |

---

## 7. 앱 / 화면 구성

| 앱 | 타입 | 내용 |
|---|---|---|
| ① 예외 등록/승인 | Fiori Elements List Report + Object Page (OData V4) | 등록·상신·승인·거부·철회·연장. 필터: 체크그룹/패키지/범위/상태/만료임박 |
| ② 위반 현황 조회 | List Report (읽기전용) / ALP | finding 목록 + 면제·미처리 분류. 체크그룹별·패키지별 집계, 추세 |
| ③ 만료 처리 | 배치 잡 | 만료 D-30 알림 + 유효기간 경과 건 `STATUS=60` 전환 |
| ④ finding 적재 | 배치 잡 | ATC Run 결과 → `ZATC_FINDING` 스냅샷 |

### 7.1 연계 흐름

```
[② 위반 현황]  finding 선택 -> [예외 신청] 버튼
                                    |
                                    v  패키지/오브젝트 값만 프리필 (위치 정보는 증빙으로만 보관)
[① 등록 화면]  적용범위 선택 (설정 기반 동적 목록) + 사유 + 유효기간 + 승인자
                                    |
                                    v  [상신]
[① 승인 화면]  영향도 시뮬레이션 표시 -> [승인] / [거부]
                                    |
                                    v
                         예외 레코드 STATUS=30 저장
                         (Option B: 표준 예외 생성 + EXT_EXEMPTION_ID 기록)
                                    |
                                    v
                         다음 ATC 실행 시 면제 반영
```

### 7.2 승인 화면 필수 요소 — 영향도

```
+-- 예외 신청 승인 -------------------------------------------+
| 신청번호 EX-000123        신청자 LEE_DEV                    |
| 체크그룹 NAMING                                             |
| 적용범위 (!) 패키지  ZFI_LEGACY                             |
| 대상규칙 네이밍 - 접두어 위반                                |
| 사유     [레거시이관] 2019년 이관, 개명 시 IF 영향           |
| 유효기간 ~ 2027-12-31                                       |
|                                                             |
| +-- 영향도 시뮬레이션 -----------------------------------+   |
| | 승인 시 면제되는 현재 위반 : 3건                       |   |
| |   - CLAS ZOLD_POSTING_HELPER                           |   |
| |   - CLAS ZOLD_TAX_CALC        <- 신청서에 없던 건       |   |
| |   - PROG ZOLD_REPORT01        <- 신청서에 없던 건       |   |
| | (!) 이 패키지에 향후 생성되는 오브젝트도 자동 면제됨    |   |
| +--------------------------------------------------------+   |
|                                        [승인]  [거부]       |
+-------------------------------------------------------------+
```

이 영향도 표시가 **패키지 단위 승인의 유일한 안전장치**다. 없으면 승인자는 자신이 무엇을 승인하는지 알 수 없다.

### 7.3 조회 화면 표기

```
[ ATC 위반 현황 ]
+------------------------------------------------------------------------+
| 체크그룹  패키지      오브젝트                  상태         근거번호  |
| NAMING    ZFI_LEGACY  CLAS ZOLD_POSTING_HELPER  면제(패키지)  EX-000123|
| NAMING    ZFI_LEGACY  CLAS ZOLD_TAX_CALC        면제(패키지)  EX-000123|
| NAMING    ZFI_LEGACY  PROG ZOLD_REPORT01        면제(패키지)  EX-000123|
| NAMING    ZSD_ORDER   CLAS ZORDER_HELPER        미처리        -        |
+------------------------------------------------------------------------+
```

상태는 **조인 계산 결과**다. 예외가 만료되면 다음 조회 시 자동으로 "미처리"로 돌아온다.

---

## 8. 권한 설계 🔴 Phase 1 필수

### 8.1 권한 오브젝트 — 필드를 지금 모두 확보해야 한다

```
[하면 안 되는 설계]
  Z_ATCEXEM : DEVCLASS + ACTVT
      |
      v  Phase 2 에서 체크그룹별 승인자 분리 필요
  권한 오브젝트에 필드 추가 -> PFCG 역할 전수 재작업
  -> 운영 중 전 사용자 권한 재부여 + 보안팀 재승인 + 감사 이슈

[해야 하는 설계]
  Z_ATCEXEM : CHECK_GROUP + DEVCLASS + SCOPE_TYPE + ACTVT
      |
      v  Phase 2
  역할에 값만 추가 -> 끝
```

**권한 오브젝트 필드는 나중에 추가하는 비용이 비대칭적으로 크다.** 값이 비어 있어도 되므로 필드는 처음부터 모두 정의한다.

### 8.2 역할 구성

| 역할 | 권한 |
|---|---|
| 신청자 (개발자) | 본인 신청서 CRUD, `submit` / `withdraw`. finding 조회는 본인 담당분 |
| 승인자 — 팀리더 | `OBJ` 범위 승인/거부. 담당 패키지 범위 |
| 승인자 — 아키텍트 | `PCKG` 범위 포함 전체 승인/거부 |
| 승인자 — 보안담당 | Phase 2, `SECURITY` 체크그룹 전용 |
| 조회자 | 전체 현황 읽기 전용 |
| 관리자 | 설정 테이블 유지보수, `revoke` |

### 8.3 finding 읽기 경로 2개 분리

| 경로 | 필터 | 용도 |
|---|---|---|
| 경로 1 (개발자) | `CONTACTPERSON = sy-uname OR RESPONSIBLE = sy-uname` | My Findings |
| 경로 2 (승인자/조회) | **담당자 필터 없음** + 권한 오브젝트로 통제 | 승인 화면, 영향도 시뮬레이션, 대시보드 |

경로 2가 없으면 다음이 모두 불가능하다.
- 승인자는 **타인의** finding 을 봐야 하므로 승인 자체가 불가
- 패키지 영향도 시뮬레이션은 담당자와 무관하게 패키지 전체를 읽어야 함
- 전사 추세 대시보드

---

## 9. 확장성 설계 원칙 (Phase 2 확정에 따른 필수 준수 사항)

### 9.1 하드코딩 금지 목록

```
X  IF scope_type = 'FND'                  ->  ZATC_SCOPE_CFG 조회
X  IF check_id = <네이밍 체크 클래스>       ->  ZATC_CHK_CFG 조회
X  유효기간 12개월 상수                     ->  설정값
X  승인자 = 아키텍트 역할 고정              ->  체크그룹별 승인 레벨 매핑
X  메시지 텍스트 하드코딩                   ->  표준에서 동적 취득
X  범위 선택 드롭다운 값 고정               ->  설정 기반 동적 생성
X  권한 체크에 DEVCLASS 만 사용             ->  CHECK_GROUP / SCOPE_TYPE 포함
X  스냅샷 보관기간 상수                     ->  설정값
```

### 9.2 Phase 1 선반영 필수 항목

| 항목 | Phase 1 투입 | Phase 2 에 미루면 |
|---|---|---|
| 설정 테이블 2개 + 동적 화면 | 1~2일 | 2~3주 (전 로직 리팩터링) |
| `SUB_OBJECT` / `LINE_NO` / `FINDING_KEY` 컬럼 | 10분 | 1주 (구조변경 + 마이그레이션 + 재테스트) |
| 권한 오브젝트 필드 | 30분 | **수주 + 보안팀 재승인 + 감사 이슈** 🔴 |
| 인덱스 / 보관 정책 | 반나절 | 성능 장애 발생 후 긴급 대응 |
| 아이템 의미 분기 (5.5) | 설계 시 반영 | 판정 버그 + 데이터 정합성 문제 |

**합계 2~3일의 추가 투입으로 Phase 2의 한 달치 재작업을 회피한다.**

### 9.3 요건 해석 정리

> **"네이밍은 패키지/오브젝트 단위만"은 앱 전체의 규칙이 아니라 `NAMING` 체크그룹의 설정값이다.**

이렇게 해석하면 R2(현재 요건)와 R5(확장 계획)가 충돌하지 않고, 설정 테이블 2개로 양쪽을 모두 만족한다.

`FND` 를 Phase 1에서 제외하는 근거는 **"정책적 차단"이 아니라 "네이밍 체크에서는 불필요"** 다. 네이밍 위반은 오브젝트당 1건이라 `FND` 와 `OBJ` 가 사실상 동일하다. 반면 성능·보안 체크는 라인 단위 판단이 본질이므로 **Phase 2 에서 `FND` 는 필수**가 된다.

---

## 10. 시스템 배치 및 전송 전략

```
ATC 실행 / TR 릴리즈 게이트 위치 = DEV 시스템
예외 데이터가 효력을 가져야 하는 곳 = DEV (또는 중앙 ATC 시스템)
Fiori 앱 사용 희망 위치           = 통상 운영/포털
```

**결정 사항**
- 예외 등록 앱은 **DEV 시스템 또는 중앙 ATC 시스템에서 운영**한다. 체크 시점에 데이터가 읽혀야 한다.
- Z 테이블 데이터는 **전송(transport) 대상이 아니다** (애플리케이션 데이터). 커스터마이징 테이블로 만들어 전송하는 방식은 승인 워크플로와 충돌하므로 비권장.
- 중앙 ATC 시스템을 별도 운영한다면 **예외 데이터의 단일 소유 시스템을 하나로 확정**해야 한다.
- 설정 테이블(`ZATC_CHK_CFG` / `ZATC_SCOPE_CFG`)은 성격상 커스터마이징이므로 전송 대상으로 둘지 별도 판단이 필요하다.

### 10.1 PCE 언어버전(Tier) 고려

| 구성요소 | 언어버전 |
|---|---|
| RAP 앱 (CDS / BDEF / 서비스) | ABAP Cloud (Tier 1) 선호 — 단, 참조하는 표준 오브젝트의 릴리즈 상태에 종속 |
| Option C 커스텀 체크 클래스 | **클래식 ABAP (Tier 3) 필수** — `CL_CI_TEST_*` 는 Cloud 미허용 |
| 두 계층 연결 | Z 테이블 read 전용 래퍼 API |

참조하는 ATC 표준 오브젝트가 Cloud 릴리즈되지 않았다면 전체를 클래식으로 가야 한다. **이 결정을 Phase 1 착수 전에 확정해야 한다** (나중 변경 시 전면 재작업).

---

## 11. 미확정 확인 과제 🔴 착수 전 필수

### ① 예외 **생성** API 존재 여부 — 최우선

```
ADT 검색 : SATC_API*            (FINDINGS 외에 EXEMPTION 관련 오브젝트)
          CL_SATC_*API*         (예외 생성/승인 메소드 보유 클래스)
          SATC*EXEMPT*          (예외 저장 테이블/뷰)
```

| 결과 | 설계 영향 |
|---|---|
| 있음 | **Option B 확정.** 앱 승인 시 표준 예외 자동 생성. 가장 깔끔 |
| 없음 | **Option C 선회.** 커스텀 체크 클래스 + Tier 3 패키지 구성. 설계 변경 큼 |

### ② 표준 오브젝트 API State (PCE 필수)

```
ADT 에서 SATC_API_FINDINGS / SATC_AC_RESULTH 열기
  -> Properties -> API State

  "Released for Cloud Development"                -> ABAP Cloud 사용 가능
  "Not Released" / "Use System-Internally Only"   -> 클래식 ABAP 에서만 가능
```

→ RAP 앱을 ABAP Cloud 로 갈지 클래식으로 갈지 결정된다.

### ③ Domain 고정값 확인

```
scope 필드 -> Navigate/Go to Definition -> Data Element -> Domain -> Value Range

확인 항목
  - 전체 코드값 목록 (FND 외에 무엇이 있는지, OBJ/PKG 의 실제 코드값)
  - 각 코드의 설명 텍스트
  - 축 2(Message / Check) 필드의 코드값도 함께 확인
```

### ④ 표준 finding 식별 방식 (`FINDING_KEY`)

```
ADT 에서 FND 범위로 예외 1건 신청 -> 예외 저장소 레코드 확인
  -> 위치를 어떤 필드에 어떤 형태로 저장하는가?
     단순 라인 번호? 해시/체크섬? 코드 문맥 문자열?
```

라인 번호만 보관하면 Phase 2 에서 "FND 예외가 자꾸 풀린다"는 버그로 돌아온다. `SATC_API_FINDINGS` 조회 시 이 필드를 함께 취득해 보관한다.

### ⑤ ATC 설정 현황 파악

- t-code `ATC` : 승인 필수 여부 / 자기승인 허용 / 유효기간 강제 / 기본 승인자
- TR 릴리즈 게이트에 걸린 체크 변형과 차단 Priority
- Baseline 적용 여부 및 적용 시점

### ⑥ 네이밍 체크 식별자

SCI 변형 화면에서 네이밍 체크의 **정확한 체크 클래스명 + 메시지 ID 목록**을 확보하여 `ZATC_CHK_CFG` 초기 데이터로 등록한다.

### ⑦ 조직 결정 사항

- 앱 운영 시스템 (DEV / 중앙 ATC)
- 승인자 체계 (패키지 오너 기반 / 아키텍트 단일 창구)
- legacy 처리 방침 (Baseline 적용 시점 합의)
- `FND` 제외 근거를 "범위 한정(추후 확장)"으로 문서화할지 확인

---

## 12. 기존 프로토타입 분석

참고용 프로토타입에서 확인된 사항이다.

### 12.1 구조

| 요소 | 내용 | 평가 |
|---|---|---|
| 테이블 | Exemption Request **Header** / Request **Finding Item** | ✅ 재사용 — 신청서와 finding 분리 구조가 이미 올바름 |
| 뷰 `req_finding` | `SATC_API_FINDINGS` 기반 | ✅ 재사용 — 이름에 `API` 가 붙은 쪽이 외부 소비를 전제한 인터페이스일 가능성이 높음 |
| 뷰 `my_findings` | `SATC_AC_RESULTH` 기반 | 🔧 축소 — 런 정보(실행일시/변형) 조인용으로만 사용 |
| 필터 | `CONTACTPERSON = sy-uname OR RESPONSIBLE = sy-uname` | 🔧 경로 1 로 유지 + 경로 2 신규 추가 (8.3) |
| 버튼 | Pull My Finding / Submit / Withdraw / Approve / Reject / Delete | ✅ 재사용 + 보완 |

### 12.2 버튼 의미

| 버튼 | 동작 | 주체 | 허용 상태 |
|---|---|---|---|
| Pull My Finding | ATC 결과에서 담당 위반 건을 앱 테이블로 적재 | 개발자 | 항상 |
| Submit | 상신. 10 → 20 | 신청자 | 초안 |
| Withdraw | 상신 철회. 20 → 10 (레코드 유지) | 신청자 | 승인대기 |
| Approve | 승인. 20 → 30 | 승인자 | 승인대기 |
| Reject | 거부. 20 → 40 (사유 필수) | 승인자 | 승인대기 |
| Delete | 레코드 삭제 | 신청자 | **초안만 허용** |

```
        [Pull My Finding]
               |
               v
        +--- 초안(10) ---+
        |                |
   [Delete]         [Submit]
        |                |
        v                v
     (삭제)        승인대기(20)
                   |     |      |
            [Withdraw][Approve][Reject]
                   |     |      |
                   v     v      v
                초안(10) 승인(30) 거부(40)
                         |        |
                         |    (수정 후 재상신)
                         v
                  면제 효력 발생
                         |
                  [Revoke] / 만료
                         v
                  철회(50) / 만료(60)
```

### 12.3 개선·보완 사항

| # | 항목 | 내용 | 우선도 |
|---|---|---|---|
| 1 | 데이터 소스 이원화 | `SATC_API_FINDINGS` 로 단일화. 두 소스가 어긋나면 "화면엔 보이는데 신청 안 되는 건" 발생 | 🔴 |
| 2 | 적용범위 필드 없음 | `SCOPE_TYPE` + 설정 매트릭스 신규 | 🔴 |
| 3 | 아이템 의미 미정의 | 범위별 역할 분기 명시 (5.5). 미정의 시 "아이템에 담긴 건만 면제"로 구현되어 R2 미동작 | 🔴 |
| 4 | 체크 필터 없음 | 네이밍만 대상으로 하려면 체크 마스터 필터 필수 | 🔴 |
| 5 | 승인자/조회 읽기 경로 없음 | sy-uname 필터만 있어 승인 자체가 불가 | 🔴 |
| 6 | 권한 오브젝트 | 필드 확장 반영 (8.1) | 🔴 |
| 7 | `Revoke` 없음 | 승인된 예외 무효화 수단 부재 | 🟡 |
| 8 | 유효기간 / `Extend` 없음 | 영구 백도어화 방지 | 🟡 |
| 9 | 영향도 시뮬레이션 없음 | 패키지 승인 시 승인자가 파급 효과를 모름 | 🟡 |
| 10 | 만료 배치 없음 | 만료 전환 + D-30 알림 | 🟡 |
| 11 | Delete 상태 제약 / 자기승인 금지 | 감사·통제 기본기 | 🟡 |
| 12 | `EXT_EXEMPTION_ID` 없음 | Option B 시 표준 예외 역추적 불가 | 🟡 |
| 13 | `Approve` 의 실제 동작 확인 | 상태만 바꾸는가, 표준 저장소에 쓰는가 → 11장 ① 의 답이 여기 있을 수 있음 | 🔴 |

---

## 13. 개발 오브젝트 목록 (Option B 가정)

```
DB Table
  ZATC_CHK_CFG        대상 체크 마스터
  ZATC_SCOPE_CFG      체크그룹 x 적용범위 허용 매트릭스
  ZATC_REASON         사유 코드
  ZATC_EXEMPT_H       예외 신청 헤더
  ZATC_EXEMPT_I       예외 신청 아이템
  ZATC_EXEMPT_LOG     상태 이력
  ZATC_FINDING        finding 스냅샷

CDS
  ZI_ATC_EXEMPT / ZI_ATC_EXEMPT_I / ZI_ATC_EXEMPT_LOG
  ZI_ATC_FINDING
  ZC_ATC_EXEMPT / ZC_ATC_EXEMPT_I / ZC_ATC_EXEMPT_LOG / ZC_ATC_FINDING
  ZI_ATC_VH_PACKAGE / ZI_ATC_VH_OBJTYPE / ZI_ATC_VH_REASON / ZI_ATC_VH_SCOPE

Behavior Definition
  ZI_ATC_EXEMPT (base) / ZC_ATC_EXEMPT (projection)

Class
  ZBP_I_ATC_EXEMPT        behavior pool
  ZCL_ATC_FINDING_READER  ATC 결과 read 어댑터 (ATC 의존을 이 클래스로 격리)
  ZCL_ATC_EXEMPT_SYNC     승인 -> 표준 예외 생성/삭제
  ZCL_ATC_SNAPSHOT_JOB    finding 스냅샷 적재 배치
  ZCL_ATC_EXPIRY_JOB      만료 전환 + D-30 알림 배치
  ZCL_ATC_IMPACT_SIM      영향도 시뮬레이션
  ZCL_ATC_SCOPE_CFG       설정 조회 (캐싱)

Service
  ZUI_ATC_EXEMPT_O4  + Service Binding
  ZUI_ATC_FINDING_O4 + Service Binding

Authorization
  권한 오브젝트 Z_ATCEXEM (CHECK_GROUP + DEVCLASS + SCOPE_TYPE + ACTVT)
  역할 : 신청자 / 승인자(팀리더) / 승인자(아키텍트) / 조회자 / 관리자

Number Range
  EXEMPT_ID 용 넘버레인지 오브젝트

[Option C 선택 시 추가]
  ZCL_CI_TEST_NAMING        클래식 ABAP 패키지 (Tier 3)
  ZCL_ATC_EXEMPT_READ_API   Cloud <-> Classic read 래퍼
```

`ZCL_ATC_FINDING_READER` 로 ATC 의존을 한 클래스에 격리하는 것이 중요하다. 업그레이드 시 수정 범위가 이 클래스로 한정된다.

---

## 14. 리스크 및 통제

| 리스크 | 통제 |
|---|---|
| **패키지 단위 예외가 향후 신규 위반까지 덮음** (최대 리스크) | 유효기간 상한, 영향도 노출, 승인권한 차등, 월간 "면제 건수" 리포트 |
| ATC 내부 테이블 직접 조회 의존 | `ZCL_ATC_FINDING_READER` 로 격리. 업그레이드 시 단일 수정점 |
| Option C 선택 시 표준 개선 미수혜 | 표준 체크와 커스텀 체크를 병렬 실행해 결과 정기 비교 |
| PCE 언어버전 혼용 | 패키지 분리 + 래퍼 API. **Phase 1 착수 전 확정** |
| legacy 대량건을 앱으로 등록 시도 | Baseline 선적용을 프로세스 규정으로 명문화 |
| ADT 직접 신청으로 R2 우회 | 본 앱을 **승인 단일 창구**로 운영 (3.1) |
| Phase 2 데이터량 폭증 | 인덱스 / 보관 정책 / 필수 필터 강제 (5.7) |
| 승인 지연 방치 | 승인 대기 알림 + 대시보드 노출 |

---

## 15. Phase 계획

### Phase 1 — 네이밍, 조회 + 등록/승인 기반

1. 확인 과제 (11장) 해소, 아키텍처 옵션 확정
2. Baseline 적용으로 legacy 위반 정리 (Option D)
3. 설정 테이블 2개 + 초기 데이터(`NAMING` 3행, `FND` 비활성)
4. 테이블 7개, CDS, BDEF, behavior pool
5. finding 스냅샷 배치 + 조회 앱 ②
6. 등록/승인 앱 ① (`OBJ` / `PCKG`), 영향도 시뮬레이션
7. 권한 오브젝트 + 역할 (확장 필드 포함)
8. 만료 배치 + 알림
9. Option B 확정 시: 표준 예외 자동 생성 연계

### Phase 2 — 기타 ATC 체크 확장

1. `ZATC_CHK_CFG` / `ZATC_SCOPE_CFG` 에 체크그룹 행 추가 → **코드 변경 없음**
2. `FND` 범위 활성화 (컬럼·판정 로직은 Phase 1에서 선반영 완료)
3. 체크그룹별 승인 역할 매핑 (권한 오브젝트 값 추가)
4. 대량 데이터 대응 검증 (인덱스 / 보관 정책 실측)

---

## 16. 용어집

| 용어 | 설명 |
|---|---|
| ATC | ABAP Test Cockpit. 정적 코드 검사 운영 프레임워크 |
| SCI | Code Inspector. 실제 검사 로직 |
| Check Variant | 실행할 체크의 묶음 |
| Finding | 검사에서 발견된 위반 1건 |
| Exemption | 예외(면제). 승인을 거쳐 finding 을 억제하는 표준 수단 |
| Baseline | 특정 시점 이전 기존 위반을 일괄 억제하는 장치 |
| Pseudo comment / Pragma | 소스에 삽입해 특정 체크를 억제하는 주석/지시자 |
| Scope (FND/OBJ/PKG) | 예외 적용 범위. Finding / ABAP Object / All Objects of Package |
| Object Set | ATC Run Series 의 검사 대상 정의 |
| PCE | S/4HANA Private Cloud Edition |
| Tier 1 / Tier 3 | ABAP Cloud 개발 / 클래식 ABAP 개발 계층 |
| OCC | Optimistic Concurrency Control (RAP etag) |

---

## 17. 결정 요약

| # | 결정 사항 |
|---|---|
| 1 | 본 앱은 새 예외 메커니즘이 아니라 **표준 ATC 예외의 관리 콘솔 + 거버넌스 레이어**다 |
| 2 | "패키지/오브젝트 단위만"은 앱의 규칙이 아니라 **`NAMING` 체크그룹의 설정값**이다 |
| 3 | 적용범위 허용 여부는 **체크그룹 × 범위 2차원 설정 매트릭스**로 제어한다 (하드코딩 금지) |
| 4 | `SUB_OBJECT` / `LINE_NO` / `FINDING_KEY` 컬럼과 **권한 오브젝트 확장 필드는 Phase 1에서 선반영**한다 |
| 5 | 아이템은 `FND` 에서만 면제 대상이고, `OBJ` / `PCKG` 에서는 **증빙 스냅샷**이다 |
| 6 | finding 의 면제 상태는 저장하지 않고 **조회 시 조인 계산**한다 |
| 7 | legacy 대량 위반은 앱이 아니라 **Baseline** 으로 처리한다 |
| 8 | 본 앱을 **승인 단일 창구**로 운영해 ADT 직접 신청 우회를 통제한다 |
| 9 | 아키텍처(Option B vs C)와 언어버전(Tier)은 **11장 확인 과제 해소 후 착수 전 확정**한다 |

---

# 18. 구현 확정 사항 (코드 반영)

> **이 장은 앞선 장과 어긋나는 부분을 대체한다.** 논의를 거쳐 확정된 내용이며,
> 실제 구현은 [`abap/zatc_exemption/`](../abap/zatc_exemption/) 에 있다.
> 모듈 단위 설치 절차와 미검증 가정은 [`abap/zatc_exemption/README.md`](../abap/zatc_exemption/README.md) 참조.

## 18.1 뒤집힌 결정

| 항목 | 이전 장 서술 | **확정** | 근거 |
|---|---|---|---|
| 앱 개수 | 신청용 / 승인용 2개 (7장) | **1개** | BO 가 하나여서 분리 이득이 없고 서비스·어노테이션만 이중 관리가 된다. 신청자와 승인자가 실무에서 겹친다. 역할 구분은 권한 + instance features 로 하고, 런치패드 타일만 2개로 나눈다 |
| 승인 기능 | 표준 Fiori 앱에 위임 검토 | **앱에 포함** | CBO 로 관리하는 목적이 결재 이력을 자사 대장에 남기는 것이므로, 승인이 앱 밖에 있으면 대장의 절반이 빈다 |
| 신청 기능 | 포함 여부 논의 | **앱에 포함** | 요건 "패키지/오브젝트 단위로만 등록"은 **신청 단계에서만** 강제할 수 있다. 승인만 하는 앱은 잘못된 범위를 사후 반려만 할 수 있다 |
| Option C 커스텀 체크 클래스 | A/B/C/D 비교 (4장) | **폐기** | 표준 네이밍 체크를 대체하면 표준 개선·노트 수혜를 잃고 유지보수 책임만 넘어온다. API 가 없으면 C 로 우회하지 않고 조회 전용(A)으로 후퇴한다 |
| 데이터 원천 | 표준 저장소 중심을 한때 권고 | **CBO 가 원천** | 관리 목적이 CBO 이므로 Z 테이블이 원천이고 표준 저장소는 실행용 반영 대상이다 |
| 적용범위 제어 | 검증 로직에서 판정 | **컨트롤 테이블 1개, 키는 체크 변형** | 무엇을 대상으로 볼지는 표준의 체크 변형이 이미 묶어놓았다. 변형 단위면 Phase 1 은 1행, Phase 2 도 3~4행이고 체크 추가가 변형 관리로 흡수된다 |
| 테이블 개수 | 7개 (5장) | **4개** | finding 스냅샷은 추세 리포팅이 요건에 없어 제거하고 라이브 조회로, 설정 2개는 1개로 통합 |
| 승인 레벨 | 설정 테이블의 `apprlevel` | **권한 오브젝트** | `Z_ATCEXEM` 에 `SCOPETYPE` 필드가 있어 PFCG 역할로 표현된다. 설정에 두면 이중 관리 |

## 18.2 관통 원칙 — 관리는 CBO, 실행은 표준

```
      관리 계층 (CBO, 자사 통제)              실행 계층 (표준, 미변경)
  ┌──────────────────────────────┐      ┌──────────────────────────────┐
  │ ztatcexempt   신청/승인 원천   │      │ 표준 ATC 예외 저장소          │
  │ ztatcexemptlog 결재 이력      │ ───► │                              │
  │ ztatccfg      동작 규칙(변형별)  │ 승인 │ 표준 ATC 가 억제              │
  │ Z_ATCEXEM     자사 권한 체계   │  시  │ (ADT / TR게이트 / CI-CD)     │
  └──────────────────────────────┘      └──────────────────────────────┘
              ▲                                        │
              └──── sync_from_standard ◄───────────────┘
                    (ADT 직접 신청건 흡수 + 정합성 점검)
```

이 구분이 "최대한 표준과 유사하게" 와 "CBO 로 관리" 를 동시에 만족시키는 선이다.
실행 메커니즘은 손대지 않고, 관리 계층만 자사 것으로 만든다.

## 18.3 요건이 코드가 아니라 설정으로 지켜지는 방식

`ztatccfg` (컨트롤 테이블 — 키는 체크 변형)

| checkvariant | checkgroup | activeflg | fndactive | objactive | pkgactive | maxvalidmon |
|---|---|---|---|---|---|---|
| `Z_NAMING_ONLY` | NAMING | X | (공란) | X | X | 12 |

- **Phase 1**: `NAMING` 3행만 등록, `FND` = `✗` → R2("패키지/오브젝트 단위만") 충족
- **Phase 2**: `PERF` / `SECURITY` 행 추가 → **코드 변경 0**
- 화면의 범위 선택 옵션은 이 테이블을 읽어 **동적 생성**한다

> 보안 체크를 `PCKG` 로 열면 해당 패키지의 보안 검증이 전부 꺼진다. 체크별 차등이 필수인 이유다.

### 5.3 `ZATC_CHK_CFG` — 대상 체크 마스터

| 필드 | 설명 |
|---|---|
| `CHECK_ID` | 체크 클래스 / 체크 ID |
| `MESSAGE_ID` | 메시지 ID (공란 = 체크 전체) |
| `CHECK_GROUP` | `NAMING` / `PERF` / `SECURITY` / `CLOUD` … |
| `ACTIVE` | 앱 취급 대상 여부 |
| `MAX_PRIORITY` | 예외 허용 가능한 최대 Priority (예: Prio 1은 예외 금지) |
| `DESCRIPTION` | 설명 |

Phase 1 은 `NAMING` 행만 `ACTIVE = ✓`. 이로써 R4("네이밍만")가 하드코딩 없이 충족된다.

### 5.4 `ZATC_EXEMPT_H` — 예외 신청 헤더

| 필드 | 타입(예) | 비고 |
|---|---|---|
| `EXEMPT_UUID` | `SYSUUID_X16` | Key |
| `EXEMPT_ID` | `CHAR12` | 넘버레인지 기반 표시용 번호 |
| `CHECK_GROUP` | `CHAR10` | 설정 테이블 참조 |
| `SCOPE_TYPE` | `CHAR3` | `FND` / OBJ / PKG — **설정으로 허용 여부 판정** |
| `DEVCLASS` | `DEVCLASS` | 대상 패키지 (OBJ 스코프 시 TADIR에서 파생) |
| `INCL_SUBPACKAGES` | `ABAP_BOOLEAN` | 하위 패키지 포함 여부 |
| `OBJECT_TYPE` | `TROBJTYPE` | OBJ / FND 스코프 시 필수 |
| `OBJECT_NAME` | `SOBJ_NAME` | OBJ / FND 스코프 시 필수 |
| `SUB_OBJECT` | `CHAR40` | 인클루드명 — **FND 대비 선반영** |
| `LINE_NO` | `INT4` | 소스 라인 — **FND 대비 선반영** |
| `FINDING_KEY` | `CHAR60` | 표준 finding 식별자 — **FND 대비 선반영** (11장 ④) |
| `CHECK_ID` / `MESSAGE_ID` | | 대상 규칙. 공란 = 체크 전체 |
| `RULE_SCOPE` | `CHAR10` | 축 2: Message / Check |
| `REASON_CODE` | `CHAR4` | 사유 코드 (고정값) |
| `REASON_TEXT` | `STRING` | 근거. 필수 + 최소 길이 검증 |
| `VALID_FROM` / `VALID_TO` | `DATS` | **`VALID_TO` 필수, 상한은 설정값** |
| `STATUS` | `CHAR2` | `10` 초안 / `20` 승인대기 / `30` 승인 / `40` 거부 / `50` 철회 / `60` 만료 |
| `REQUESTER` / `APPROVER` | `UNAME` | |
| `APPROVED_AT` | `TIMESTAMPL` | |
| `EXT_EXEMPTION_ID` | `CHAR32` | **표준 예외 저장소에 생성된 ID** — 철회/연장 시 역추적에 필수 |
| `CREATED_BY/AT`, `CHANGED_BY/AT` | | 감사 |
| `LOCAL_LAST_CHANGED_AT` | `TIMESTAMPL` | OCC (etag) |

#### `SUB_OBJECT` / `LINE_NO` / `FINDING_KEY` 를 지금 넣어야 하는 이유

Phase 2 에서 `FND` 를 활성화할 때 이 3개 컬럼이 없으면 **운영 데이터가 있는 상태에서 테이블 구조 변경 + CDS/BDEF/서비스 전면 수정 + 마이그레이션 + 전 구간 재테스트**가 발생한다. 지금 넣는 비용은 사실상 0이며, 값이 없으면 공란으로 남는다.

### 5.5 `ZATC_EXEMPT_I` — 신청 아이템 ★ 의미 주의

**아이템의 역할은 적용범위에 따라 달라진다.** 이를 명시하지 않으면 "아이템에 담긴 건만 면제"로 구현되어 R2가 동작하지 않는다.

| SCOPE | 아이템의 역할 | 위치 정보 |
|---|---|---|
| `FND` | **면제 대상 그 자체** (1:1) | `LINE_NO` / `FINDING_KEY` **필수** |
| `OBJ` | 신청 근거(증빙) 스냅샷. 효력은 오브젝트 전체 | 참고용 |
| `PCKG` | 신청 근거(증빙) 스냅샷. 효력은 패키지 전체 + 향후 오브젝트 | 참고용 |

```
예) 패키지 신청서
  Header : SCOPE=PCKG, DEVCLASS=ZFI_LEGACY, VALID_TO=2027-12-31
  Item   : ZOLD_POSTING_HELPER / ZOLD_TAX_CALC / ZOLD_REPORT01  (증빙 3건)

  -> 승인 후 효력 : ZFI_LEGACY 전체 (증빙 3건 + 향후 생성 오브젝트 전부)
  -> Item 은 "승인 당시 상황"의 기록으로만 남는다
```

**이 분기 판정을 Phase 1부터 로직에 반영**해야 한다. Phase 2에서 끼워 넣으면 기존 데이터와 섞여 판정 버그가 발생한다.

### 5.6 `ZATC_EXEMPT_LOG` — 상태 이력

`EXEMPT_UUID` + `LOG_SEQ` / 변경일시 / 변경자 / from-status / to-status / 코멘트.
감사 대응 시 "누가 언제 무엇을 승인했는지"의 유일한 근거다.

### 5.7 `ZATC_FINDING` — finding 스냅샷

ATC Run 결과를 배치로 적재한다.

| 필드 | 설명 |
|---|---|
| `SNAPSHOT_DATE` / `RUN_ID` | 스냅샷 시점, ATC 런 |
| `DEVCLASS` / `OBJECT_TYPE` / `OBJECT_NAME` / `SUB_OBJECT` / `LINE_NO` | 위치 |
| `FINDING_KEY` | 표준 finding 식별자 |
| `CHECK_ID` / `MESSAGE_ID` / `CHECK_GROUP` | 규칙 |
| `PRIORITY` / `MESSAGE_TEXT` | |
| `CONTACTPERSON` / `RESPONSIBLE` | 담당자 (My Findings 필터용) |

**스냅샷을 두는 이유**
1. ATC 내부 테이블 직접 조회 의존 최소화 (업그레이드 내구성)
2. 대량 건 UI 성능 확보
3. 추세 분석(월별 위반 감소) 리포팅 가능

**Phase 2 대비 필수 설계**

```
데이터량  네이밍만 : 수천 건
          전체 체크 : 수만 ~ 수십만 건  (성능/클라우드준비도가 특히 많음)
```

- 인덱스: `DEVCLASS + CHECK_GROUP + SNAPSHOT_DATE`
- 보관 정책: 스냅샷일자 기준 N일 경과 건 삭제 배치 (보관기간은 설정값)
- 조회 화면: **필수 필터 강제** (패키지 또는 체크그룹 미지정 시 조회 차단)
- 집계는 CDS 레벨에서 처리. ABAP 루프 집계 금지

### 5.8 CDS 계층

```
ZI_ATC_EXEMPT (interface, root) --- composition ---> ZI_ATC_EXEMPT_I
                                                --> ZI_ATC_EXEMPT_LOG
      |
      +-- ZC_ATC_EXEMPT (projection, UI annotation) --> Service Definition / Binding

ZI_ATC_FINDING --- association ---> ZI_ATC_EXEMPT   (범위 매칭)
      +-- ZC_ATC_FINDING (읽기전용, "예외적용여부" 계산 필드 포함)

Value Help : ZI_ATC_VH_PACKAGE / ZI_ATC_VH_OBJTYPE / ZI_ATC_VH_REASON
             ZI_ATC_VH_SCOPE (설정 테이블 기반 동적 목록)
```

### 5.9 면제 판정 로직

finding 상태는 **저장하지 않고 조회 시 계산**한다. (상태를 finding에 직접 기록하면 만료 처리가 불가능해진다)

```
각 finding 에 대해:

  finding = { DEVCLASS, OBJECT_TYPE, OBJECT_NAME, SUB_OBJECT, LINE_NO,
              FINDING_KEY, CHECK_ID, MESSAGE_ID }

  예외 헤더 중 STATUS = 30(승인) AND 오늘이 VALID_FROM ~ VALID_TO 범위 내 인 것을 대상으로

    SCOPE_TYPE = PKG :  DEVCLASS 일치 (INCL_SUBPACKAGES 시 하위 포함)
                        AND 규칙(CHECK_ID / MESSAGE_ID) 일치
    SCOPE_TYPE = OBJ :  DEVCLASS + OBJECT_TYPE + OBJECT_NAME 일치
                        AND 규칙 일치
    SCOPE_TYPE = FND :  위 조건 + FINDING_KEY (또는 SUB_OBJECT + LINE_NO) 일치
                        <- Phase 2

  매칭되면 -> 면제(Exempted), 근거 신청번호 표시
  매칭 없음 -> 미처리 (에러 유지, TR 릴리즈 차단)
```

`PCKG` / `OBJ` 판정에는 **라인 정보가 들어가지 않는다.** 이것이 R2 의 기술적 실체이며, 코드 수정에 강건한 이유다.

---

## 6. RAP BO 동작 설계

```abap
managed implementation in class ZBP_I_ATC_EXEMPT unique;
strict ( 2 );
with draft;
```

### 6.1 Determination

| 이름 | 트리거 | 내용 |
|---|---|---|
| `setInitialValues` | on modify create | `EXEMPT_ID`(넘버레인지), `STATUS=10`, `REQUESTER=sy-uname`, `VALID_FROM` |
| `derivePackage` | on modify, field `OBJECT_NAME` | TADIR 에서 오브젝트의 패키지 파생 → `DEVCLASS` |
| `deriveCheckGroup` | on modify, field `CHECK_ID` | `ZATC_CHK_CFG` 에서 `CHECK_GROUP` 파생 |

### 6.2 Validation

| 이름 | 검증 내용 |
|---|---|
| `validateScopeAllowed` | `ZATC_SCOPE_CFG` 에서 (`CHECK_GROUP`, `SCOPE_TYPE`) 의 `ACTIVE` 조회. 비활성이면 거부 → **R2 강제 지점** |
| `validateScopeFields` | `PCKG`면 오브젝트 필드 공란, `OBJ`면 오브젝트 필드 필수, `FND`면 위치 정보까지 필수 |
| `validatePackage` | TDEVC 존재 + 고객 네임스페이스(Z/Y//XXX/) 여부 |
| `validateObject` | TADIR 존재 + 지원 오브젝트 타입 |
| `validateCheck` | `ZATC_CHK_CFG` 에 `ACTIVE` 로 등록된 체크인지. `MAX_PRIORITY` 초과 시 거부 |
| `validateValidity` | `VALID_TO > VALID_FROM`, 설정된 최대 유효기간 초과 금지 |
| `validateOverlap` | 동일 범위·규칙의 유효한 승인 예외 중복 금지 |
| `validateReason` | 설정상 사유 필수면 `REASON_CODE` + `REASON_TEXT` 최소 길이 검증 |

> `IF scope_type = 'FND'` 같은 **하드코딩 금지.** 반드시 설정 테이블을 조회한다.

### 6.3 Action

| 액션 | 상태 전이 | 권한 |
|---|---|---|
| `submit` | 10 → 20 (승인자 지정 필수) | 신청자 |
| `withdraw` | 20 → 10 (상신 철회, 레코드 유지) | 신청자 |
| `approve` | 20 → 30 (`APPROVED_AT` 기록, Option B 시 표준 예외 생성 후 `EXT_EXEMPTION_ID` 저장) | **설정된 승인 레벨** |
| `reject` | 20 → 40 (거부 사유 필수) | 승인자 |
| `revoke` | 30 → 50 (승인된 예외 무효화. Option B 시 표준 예외도 삭제/무효화) | 승인자 / 관리자 |
| `extendValidity` | 유효기간 연장 → 재승인 경유 | 신청자 → 승인자 |
| `simulateImpact` (static/factory) | 해당 범위가 현재 몇 건의 finding 을 면제하는지 계산 | 승인자 |

**제약**
- `delete` 는 `STATUS = 10`(초안)에서만 허용. **승인/거부된 건은 삭제 금지** (감사 근거 소실)
- 자기승인 금지: `REQUESTER = APPROVER` 차단
- `withdraw` 와 `delete` 의 구분을 명확히 문서화 (철회 = 상태 되돌림, 삭제 = 레코드 소멸)

### 6.4 그 외

- `AUTHORIZATION MASTER ( instance )`
- `etag master LOCAL_LAST_CHANGED_AT`, draft + total etag
- `field ( readonly ) STATUS, REQUESTER, APPROVED_AT, EXT_EXEMPTION_ID, ...`

### 6.5 패키지 단위 예외의 통제 장치 (필수)

| 장치 | 내용 |
|---|---|
| 유효기간 필수 + 상한 | 설정값 기반. 무기한 금지 |
| 승인 권한 차등 | `OBJ` = 팀리더 / `PCKG` = **아키텍트 전용** (설정 테이블) |
| 영향도 강제 노출 | 승인 화면에 면제 건수 + "향후 생성 오브젝트 포함" 경고 |
| 신규 오브젝트 알림 | 패키지 예외 하에 새 위반 오브젝트 발생 시 월간 리포트 통보 |
| 만료 D-30 알림 | 조용히 풀려 갑자기 TR 차단되는 사고 방지 |
| 자기승인 금지 | 신청자 = 승인자 불가 |
| Prio 제한 | `MAX_PRIORITY` 초과 건은 예외 신청 자체를 차단 |

---

## 7. 앱 / 화면 구성

| 앱 | 타입 | 내용 |
|---|---|---|
| ① 예외 등록/승인 | Fiori Elements List Report + Object Page (OData V4) | 등록·상신·승인·거부·철회·연장. 필터: 체크그룹/패키지/범위/상태/만료임박 |
| ② 위반 현황 조회 | List Report (읽기전용) / ALP | finding 목록 + 면제·미처리 분류. 체크그룹별·패키지별 집계, 추세 |
| ③ 만료 처리 | 배치 잡 | 만료 D-30 알림 + 유효기간 경과 건 `STATUS=60` 전환 |
| ④ finding 적재 | 배치 잡 | ATC Run 결과 → `ZATC_FINDING` 스냅샷 |

### 7.1 연계 흐름

```
[② 위반 현황]  finding 선택 -> [예외 신청] 버튼
                                    |
                                    v  패키지/오브젝트 값만 프리필 (위치 정보는 증빙으로만 보관)
[① 등록 화면]  적용범위 선택 (설정 기반 동적 목록) + 사유 + 유효기간 + 승인자
                                    |
                                    v  [상신]
[① 승인 화면]  영향도 시뮬레이션 표시 -> [승인] / [거부]
                                    |
                                    v
                         예외 레코드 STATUS=30 저장
                         (Option B: 표준 예외 생성 + EXT_EXEMPTION_ID 기록)
                                    |
                                    v
                         다음 ATC 실행 시 면제 반영
```

### 7.2 승인 화면 필수 요소 — 영향도

```
+-- 예외 신청 승인 -------------------------------------------+
| 신청번호 EX-000123        신청자 LEE_DEV                    |
| 체크그룹 NAMING                                             |
| 적용범위 (!) 패키지  ZFI_LEGACY                             |
| 대상규칙 네이밍 - 접두어 위반                                |
| 사유     [레거시이관] 2019년 이관, 개명 시 IF 영향           |
| 유효기간 ~ 2027-12-31                                       |
|                                                             |
| +-- 영향도 시뮬레이션 -----------------------------------+   |
| | 승인 시 면제되는 현재 위반 : 3건                       |   |
| |   - CLAS ZOLD_POSTING_HELPER                           |   |
| |   - CLAS ZOLD_TAX_CALC        <- 신청서에 없던 건       |   |
| |   - PROG ZOLD_REPORT01        <- 신청서에 없던 건       |   |
| | (!) 이 패키지에 향후 생성되는 오브젝트도 자동 면제됨    |   |
| +--------------------------------------------------------+   |
|                                        [승인]  [거부]       |
+-------------------------------------------------------------+
```

이 영향도 표시가 **패키지 단위 승인의 유일한 안전장치**다. 없으면 승인자는 자신이 무엇을 승인하는지 알 수 없다.

### 7.3 조회 화면 표기

```
[ ATC 위반 현황 ]
+------------------------------------------------------------------------+
| 체크그룹  패키지      오브젝트                  상태         근거번호  |
| NAMING    ZFI_LEGACY  CLAS ZOLD_POSTING_HELPER  면제(패키지)  EX-000123|
| NAMING    ZFI_LEGACY  CLAS ZOLD_TAX_CALC        면제(패키지)  EX-000123|
| NAMING    ZFI_LEGACY  PROG ZOLD_REPORT01        면제(패키지)  EX-000123|
| NAMING    ZSD_ORDER   CLAS ZORDER_HELPER        미처리        -        |
+------------------------------------------------------------------------+
```

상태는 **조인 계산 결과**다. 예외가 만료되면 다음 조회 시 자동으로 "미처리"로 돌아온다.

---

## 8. 권한 설계 🔴 Phase 1 필수

### 8.1 권한 오브젝트 — 필드를 지금 모두 확보해야 한다

```
[하면 안 되는 설계]
  Z_ATCEXEM : DEVCLASS + ACTVT
      |
      v  Phase 2 에서 체크그룹별 승인자 분리 필요
  권한 오브젝트에 필드 추가 -> PFCG 역할 전수 재작업
  -> 운영 중 전 사용자 권한 재부여 + 보안팀 재승인 + 감사 이슈

[해야 하는 설계]
  Z_ATCEXEM : CHECK_GROUP + DEVCLASS + SCOPE_TYPE + ACTVT
      |
      v  Phase 2
  역할에 값만 추가 -> 끝
```

**권한 오브젝트 필드는 나중에 추가하는 비용이 비대칭적으로 크다.** 값이 비어 있어도 되므로 필드는 처음부터 모두 정의한다.

### 8.2 역할 구성

| 역할 | 권한 |
|---|---|
| 신청자 (개발자) | 본인 신청서 CRUD, `submit` / `withdraw`. finding 조회는 본인 담당분 |
| 승인자 — 팀리더 | `OBJ` 범위 승인/거부. 담당 패키지 범위 |
| 승인자 — 아키텍트 | `PCKG` 범위 포함 전체 승인/거부 |
| 승인자 — 보안담당 | Phase 2, `SECURITY` 체크그룹 전용 |
| 조회자 | 전체 현황 읽기 전용 |
| 관리자 | 설정 테이블 유지보수, `revoke` |

### 8.3 finding 읽기 경로 2개 분리

| 경로 | 필터 | 용도 |
|---|---|---|
| 경로 1 (개발자) | `CONTACTPERSON = sy-uname OR RESPONSIBLE = sy-uname` | My Findings |
| 경로 2 (승인자/조회) | **담당자 필터 없음** + 권한 오브젝트로 통제 | 승인 화면, 영향도 시뮬레이션, 대시보드 |

경로 2가 없으면 다음이 모두 불가능하다.
- 승인자는 **타인의** finding 을 봐야 하므로 승인 자체가 불가
- 패키지 영향도 시뮬레이션은 담당자와 무관하게 패키지 전체를 읽어야 함
- 전사 추세 대시보드

---

## 9. 확장성 설계 원칙 (Phase 2 확정에 따른 필수 준수 사항)

### 9.1 하드코딩 금지 목록

```
X  IF scope_type = 'FND'                  ->  ZATC_SCOPE_CFG 조회
X  IF check_id = <네이밍 체크 클래스>       ->  ZATC_CHK_CFG 조회
X  유효기간 12개월 상수                     ->  설정값
X  승인자 = 아키텍트 역할 고정              ->  체크그룹별 승인 레벨 매핑
X  메시지 텍스트 하드코딩                   ->  표준에서 동적 취득
X  범위 선택 드롭다운 값 고정               ->  설정 기반 동적 생성
X  권한 체크에 DEVCLASS 만 사용             ->  CHECK_GROUP / SCOPE_TYPE 포함
X  스냅샷 보관기간 상수                     ->  설정값
```

### 9.2 Phase 1 선반영 필수 항목

| 항목 | Phase 1 투입 | Phase 2 에 미루면 |
|---|---|---|
| 설정 테이블 2개 + 동적 화면 | 1~2일 | 2~3주 (전 로직 리팩터링) |
| `SUB_OBJECT` / `LINE_NO` / `FINDING_KEY` 컬럼 | 10분 | 1주 (구조변경 + 마이그레이션 + 재테스트) |
| 권한 오브젝트 필드 | 30분 | **수주 + 보안팀 재승인 + 감사 이슈** 🔴 |
| 인덱스 / 보관 정책 | 반나절 | 성능 장애 발생 후 긴급 대응 |
| 아이템 의미 분기 (5.5) | 설계 시 반영 | 판정 버그 + 데이터 정합성 문제 |

**합계 2~3일의 추가 투입으로 Phase 2의 한 달치 재작업을 회피한다.**

### 9.3 요건 해석 정리

> **"네이밍은 패키지/오브젝트 단위만"은 앱 전체의 규칙이 아니라 `NAMING` 체크그룹의 설정값이다.**

이렇게 해석하면 R2(현재 요건)와 R5(확장 계획)가 충돌하지 않고, 설정 테이블 2개로 양쪽을 모두 만족한다.

`FND` 를 Phase 1에서 제외하는 근거는 **"정책적 차단"이 아니라 "네이밍 체크에서는 불필요"** 다. 네이밍 위반은 오브젝트당 1건이라 `FND` 와 `OBJ` 가 사실상 동일하다. 반면 성능·보안 체크는 라인 단위 판단이 본질이므로 **Phase 2 에서 `FND` 는 필수**가 된다.

---

## 10. 시스템 배치 및 전송 전략

```
ATC 실행 / TR 릴리즈 게이트 위치 = DEV 시스템
예외 데이터가 효력을 가져야 하는 곳 = DEV (또는 중앙 ATC 시스템)
Fiori 앱 사용 희망 위치           = 통상 운영/포털
```

**결정 사항**
- 예외 등록 앱은 **DEV 시스템 또는 중앙 ATC 시스템에서 운영**한다. 체크 시점에 데이터가 읽혀야 한다.
- Z 테이블 데이터는 **전송(transport) 대상이 아니다** (애플리케이션 데이터). 커스터마이징 테이블로 만들어 전송하는 방식은 승인 워크플로와 충돌하므로 비권장.
- 중앙 ATC 시스템을 별도 운영한다면 **예외 데이터의 단일 소유 시스템을 하나로 확정**해야 한다.
- 설정 테이블(`ZATC_CHK_CFG` / `ZATC_SCOPE_CFG`)은 성격상 커스터마이징이므로 전송 대상으로 둘지 별도 판단이 필요하다.

### 10.1 PCE 언어버전(Tier) 고려

| 구성요소 | 언어버전 |
|---|---|
| RAP 앱 (CDS / BDEF / 서비스) | ABAP Cloud (Tier 1) 선호 — 단, 참조하는 표준 오브젝트의 릴리즈 상태에 종속 |
| Option C 커스텀 체크 클래스 | **클래식 ABAP (Tier 3) 필수** — `CL_CI_TEST_*` 는 Cloud 미허용 |
| 두 계층 연결 | Z 테이블 read 전용 래퍼 API |

참조하는 ATC 표준 오브젝트가 Cloud 릴리즈되지 않았다면 전체를 클래식으로 가야 한다. **이 결정을 Phase 1 착수 전에 확정해야 한다** (나중 변경 시 전면 재작업).

---

## 11. 미확정 확인 과제 🔴 착수 전 필수

### ① 예외 **생성** API 존재 여부 — 최우선

```
ADT 검색 : SATC_API*            (FINDINGS 외에 EXEMPTION 관련 오브젝트)
          CL_SATC_*API*         (예외 생성/승인 메소드 보유 클래스)
          SATC*EXEMPT*          (예외 저장 테이블/뷰)
```

| 결과 | 설계 영향 |
|---|---|
| 있음 | **Option B 확정.** 앱 승인 시 표준 예외 자동 생성. 가장 깔끔 |
| 없음 | **Option C 선회.** 커스텀 체크 클래스 + Tier 3 패키지 구성. 설계 변경 큼 |

### ② 표준 오브젝트 API State (PCE 필수)

```
ADT 에서 SATC_API_FINDINGS / SATC_AC_RESULTH 열기
  -> Properties -> API State

  "Released for Cloud Development"                -> ABAP Cloud 사용 가능
  "Not Released" / "Use System-Internally Only"   -> 클래식 ABAP 에서만 가능
```

→ RAP 앱을 ABAP Cloud 로 갈지 클래식으로 갈지 결정된다.

### ③ Domain 고정값 확인

```
scope 필드 -> Navigate/Go to Definition -> Data Element -> Domain -> Value Range

확인 항목
  - 전체 코드값 목록 (FND 외에 무엇이 있는지, OBJ/PKG 의 실제 코드값)
  - 각 코드의 설명 텍스트
  - 축 2(Message / Check) 필드의 코드값도 함께 확인
```

### ④ 표준 finding 식별 방식 (`FINDING_KEY`)

```
ADT 에서 FND 범위로 예외 1건 신청 -> 예외 저장소 레코드 확인
  -> 위치를 어떤 필드에 어떤 형태로 저장하는가?
     단순 라인 번호? 해시/체크섬? 코드 문맥 문자열?
```

라인 번호만 보관하면 Phase 2 에서 "FND 예외가 자꾸 풀린다"는 버그로 돌아온다. `SATC_API_FINDINGS` 조회 시 이 필드를 함께 취득해 보관한다.

### ⑤ ATC 설정 현황 파악

- t-code `ATC` : 승인 필수 여부 / 자기승인 허용 / 유효기간 강제 / 기본 승인자
- TR 릴리즈 게이트에 걸린 체크 변형과 차단 Priority
- Baseline 적용 여부 및 적용 시점

### ⑥ 네이밍 체크 식별자

SCI 변형 화면에서 네이밍 체크의 **정확한 체크 클래스명 + 메시지 ID 목록**을 확보하여 `ZATC_CHK_CFG` 초기 데이터로 등록한다.

### ⑦ 조직 결정 사항

- 앱 운영 시스템 (DEV / 중앙 ATC)
- 승인자 체계 (패키지 오너 기반 / 아키텍트 단일 창구)
- legacy 처리 방침 (Baseline 적용 시점 합의)
- `FND` 제외 근거를 "범위 한정(추후 확장)"으로 문서화할지 확인

---

## 12. 기존 프로토타입 분석

참고용 프로토타입에서 확인된 사항이다.

### 12.1 구조

| 요소 | 내용 | 평가 |
|---|---|---|
| 테이블 | Exemption Request **Header** / Request **Finding Item** | ✅ 재사용 — 신청서와 finding 분리 구조가 이미 올바름 |
| 뷰 `req_finding` | `SATC_API_FINDINGS` 기반 | ✅ 재사용 — 이름에 `API` 가 붙은 쪽이 외부 소비를 전제한 인터페이스일 가능성이 높음 |
| 뷰 `my_findings` | `SATC_AC_RESULTH` 기반 | 🔧 축소 — 런 정보(실행일시/변형) 조인용으로만 사용 |
| 필터 | `CONTACTPERSON = sy-uname OR RESPONSIBLE = sy-uname` | 🔧 경로 1 로 유지 + 경로 2 신규 추가 (8.3) |
| 버튼 | Pull My Finding / Submit / Withdraw / Approve / Reject / Delete | ✅ 재사용 + 보완 |

### 12.2 버튼 의미

| 버튼 | 동작 | 주체 | 허용 상태 |
|---|---|---|---|
| Pull My Finding | ATC 결과에서 담당 위반 건을 앱 테이블로 적재 | 개발자 | 항상 |
| Submit | 상신. 10 → 20 | 신청자 | 초안 |
| Withdraw | 상신 철회. 20 → 10 (레코드 유지) | 신청자 | 승인대기 |
| Approve | 승인. 20 → 30 | 승인자 | 승인대기 |
| Reject | 거부. 20 → 40 (사유 필수) | 승인자 | 승인대기 |
| Delete | 레코드 삭제 | 신청자 | **초안만 허용** |

```
        [Pull My Finding]
               |
               v
        +--- 초안(10) ---+
        |                |
   [Delete]         [Submit]
        |                |
        v                v
     (삭제)        승인대기(20)
                   |     |      |
            [Withdraw][Approve][Reject]
                   |     |      |
                   v     v      v
                초안(10) 승인(30) 거부(40)
                         |        |
                         |    (수정 후 재상신)
                         v
                  면제 효력 발생
                         |
                  [Revoke] / 만료
                         v
                  철회(50) / 만료(60)
```

### 12.3 개선·보완 사항

| # | 항목 | 내용 | 우선도 |
|---|---|---|---|
| 1 | 데이터 소스 이원화 | `SATC_API_FINDINGS` 로 단일화. 두 소스가 어긋나면 "화면엔 보이는데 신청 안 되는 건" 발생 | 🔴 |
| 2 | 적용범위 필드 없음 | `SCOPE_TYPE` + 설정 매트릭스 신규 | 🔴 |
| 3 | 아이템 의미 미정의 | 범위별 역할 분기 명시 (5.5). 미정의 시 "아이템에 담긴 건만 면제"로 구현되어 R2 미동작 | 🔴 |
| 4 | 체크 필터 없음 | 네이밍만 대상으로 하려면 체크 마스터 필터 필수 | 🔴 |
| 5 | 승인자/조회 읽기 경로 없음 | sy-uname 필터만 있어 승인 자체가 불가 | 🔴 |
| 6 | 권한 오브젝트 | 필드 확장 반영 (8.1) | 🔴 |
| 7 | `Revoke` 없음 | 승인된 예외 무효화 수단 부재 | 🟡 |
| 8 | 유효기간 / `Extend` 없음 | 영구 백도어화 방지 | 🟡 |
| 9 | 영향도 시뮬레이션 없음 | 패키지 승인 시 승인자가 파급 효과를 모름 | 🟡 |
| 10 | 만료 배치 없음 | 만료 전환 + D-30 알림 | 🟡 |
| 11 | Delete 상태 제약 / 자기승인 금지 | 감사·통제 기본기 | 🟡 |
| 12 | `EXT_EXEMPTION_ID` 없음 | Option B 시 표준 예외 역추적 불가 | 🟡 |
| 13 | `Approve` 의 실제 동작 확인 | 상태만 바꾸는가, 표준 저장소에 쓰는가 → 11장 ① 의 답이 여기 있을 수 있음 | 🔴 |

---

## 13. 개발 오브젝트 목록 (Option B 가정)

```
DB Table
  ZATC_CHK_CFG        대상 체크 마스터
  ZATC_SCOPE_CFG      체크그룹 x 적용범위 허용 매트릭스
  ZATC_REASON         사유 코드
  ZATC_EXEMPT_H       예외 신청 헤더
  ZATC_EXEMPT_I       예외 신청 아이템
  ZATC_EXEMPT_LOG     상태 이력
  ZATC_FINDING        finding 스냅샷

CDS
  ZI_ATC_EXEMPT / ZI_ATC_EXEMPT_I / ZI_ATC_EXEMPT_LOG
  ZI_ATC_FINDING
  ZC_ATC_EXEMPT / ZC_ATC_EXEMPT_I / ZC_ATC_EXEMPT_LOG / ZC_ATC_FINDING
  ZI_ATC_VH_PACKAGE / ZI_ATC_VH_OBJTYPE / ZI_ATC_VH_REASON / ZI_ATC_VH_SCOPE

Behavior Definition
  ZI_ATC_EXEMPT (base) / ZC_ATC_EXEMPT (projection)

Class
  ZBP_I_ATC_EXEMPT        behavior pool
  ZCL_ATC_FINDING_READER  ATC 결과 read 어댑터 (ATC 의존을 이 클래스로 격리)
  ZCL_ATC_EXEMPT_SYNC     승인 -> 표준 예외 생성/삭제
  ZCL_ATC_SNAPSHOT_JOB    finding 스냅샷 적재 배치
  ZCL_ATC_EXPIRY_JOB      만료 전환 + D-30 알림 배치
  ZCL_ATC_IMPACT_SIM      영향도 시뮬레이션
  ZCL_ATC_SCOPE_CFG       설정 조회 (캐싱)

Service
  ZUI_ATC_EXEMPT_O4  + Service Binding
  ZUI_ATC_FINDING_O4 + Service Binding

Authorization
  권한 오브젝트 Z_ATCEXEM (CHECK_GROUP + DEVCLASS + SCOPE_TYPE + ACTVT)
  역할 : 신청자 / 승인자(팀리더) / 승인자(아키텍트) / 조회자 / 관리자

Number Range
  EXEMPT_ID 용 넘버레인지 오브젝트

[Option C 선택 시 추가]
  ZCL_CI_TEST_NAMING        클래식 ABAP 패키지 (Tier 3)
  ZCL_ATC_EXEMPT_READ_API   Cloud <-> Classic read 래퍼
```

`ZCL_ATC_FINDING_READER` 로 ATC 의존을 한 클래스에 격리하는 것이 중요하다. 업그레이드 시 수정 범위가 이 클래스로 한정된다.

---

## 14. 리스크 및 통제

| 리스크 | 통제 |
|---|---|
| **패키지 단위 예외가 향후 신규 위반까지 덮음** (최대 리스크) | 유효기간 상한, 영향도 노출, 승인권한 차등, 월간 "면제 건수" 리포트 |
| ATC 내부 테이블 직접 조회 의존 | `ZCL_ATC_FINDING_READER` 로 격리. 업그레이드 시 단일 수정점 |
| Option C 선택 시 표준 개선 미수혜 | 표준 체크와 커스텀 체크를 병렬 실행해 결과 정기 비교 |
| PCE 언어버전 혼용 | 패키지 분리 + 래퍼 API. **Phase 1 착수 전 확정** |
| legacy 대량건을 앱으로 등록 시도 | Baseline 선적용을 프로세스 규정으로 명문화 |
| ADT 직접 신청으로 R2 우회 | 본 앱을 **승인 단일 창구**로 운영 (3.1) |
| Phase 2 데이터량 폭증 | 인덱스 / 보관 정책 / 필수 필터 강제 (5.7) |
| 승인 지연 방치 | 승인 대기 알림 + 대시보드 노출 |

---

## 15. Phase 계획

### Phase 1 — 네이밍, 조회 + 등록/승인 기반

1. 확인 과제 (11장) 해소, 아키텍처 옵션 확정
2. Baseline 적용으로 legacy 위반 정리 (Option D)
3. 설정 테이블 2개 + 초기 데이터(`NAMING` 3행, `FND` 비활성)
4. 테이블 7개, CDS, BDEF, behavior pool
5. finding 스냅샷 배치 + 조회 앱 ②
6. 등록/승인 앱 ① (`OBJ` / `PCKG`), 영향도 시뮬레이션
7. 권한 오브젝트 + 역할 (확장 필드 포함)
8. 만료 배치 + 알림
9. Option B 확정 시: 표준 예외 자동 생성 연계

### Phase 2 — 기타 ATC 체크 확장

1. `ZATC_CHK_CFG` / `ZATC_SCOPE_CFG` 에 체크그룹 행 추가 → **코드 변경 없음**
2. `FND` 범위 활성화 (컬럼·판정 로직은 Phase 1에서 선반영 완료)
3. 체크그룹별 승인 역할 매핑 (권한 오브젝트 값 추가)
4. 대량 데이터 대응 검증 (인덱스 / 보관 정책 실측)

---

## 16. 용어집

| 용어 | 설명 |
|---|---|
| ATC | ABAP Test Cockpit. 정적 코드 검사 운영 프레임워크 |
| SCI | Code Inspector. 실제 검사 로직 |
| Check Variant | 실행할 체크의 묶음 |
| Finding | 검사에서 발견된 위반 1건 |
| Exemption | 예외(면제). 승인을 거쳐 finding 을 억제하는 표준 수단 |
| Baseline | 특정 시점 이전 기존 위반을 일괄 억제하는 장치 |
| Pseudo comment / Pragma | 소스에 삽입해 특정 체크를 억제하는 주석/지시자 |
| Scope (FND/OBJ/PKG) | 예외 적용 범위. Finding / ABAP Object / All Objects of Package |
| Object Set | ATC Run Series 의 검사 대상 정의 |
| PCE | S/4HANA Private Cloud Edition |
| Tier 1 / Tier 3 | ABAP Cloud 개발 / 클래식 ABAP 개발 계층 |
| OCC | Optimistic Concurrency Control (RAP etag) |

---

## 17. 결정 요약

| # | 결정 사항 |
|---|---|
| 1 | 본 앱은 새 예외 메커니즘이 아니라 **표준 ATC 예외의 관리 콘솔 + 거버넌스 레이어**다 |
| 2 | "패키지/오브젝트 단위만"은 앱의 규칙이 아니라 **`NAMING` 체크그룹의 설정값**이다 |
| 3 | 적용범위 허용 여부는 **체크그룹 × 범위 2차원 설정 매트릭스**로 제어한다 (하드코딩 금지) |
| 4 | `SUB_OBJECT` / `LINE_NO` / `FINDING_KEY` 컬럼과 **권한 오브젝트 확장 필드는 Phase 1에서 선반영**한다 |
| 5 | 아이템은 `FND` 에서만 면제 대상이고, `OBJ` / `PCKG` 에서는 **증빙 스냅샷**이다 |
| 6 | finding 의 면제 상태는 저장하지 않고 **조회 시 조인 계산**한다 |
| 7 | legacy 대량 위반은 앱이 아니라 **Baseline** 으로 처리한다 |
| 8 | 본 앱을 **승인 단일 창구**로 운영해 ADT 직접 신청 우회를 통제한다 |
| 9 | 아키텍처(Option B vs C)와 언어버전(Tier)은 **11장 확인 과제 해소 후 착수 전 확정**한다 |

---

# 18. 구현 확정 사항 (코드 반영)

> **이 장은 앞선 장과 어긋나는 부분을 대체한다.** 논의를 거쳐 확정된 내용이며,
> 실제 구현은 [`abap/zatc_exemption/`](../abap/zatc_exemption/) 에 있다.
> 모듈 단위 설치 절차와 미검증 가정은 [`abap/zatc_exemption/README.md`](../abap/zatc_exemption/README.md) 참조.

## 18.1 뒤집힌 결정

| 항목 | 이전 장 서술 | **확정** | 근거 |
|---|---|---|---|
| 앱 개수 | 신청용 / 승인용 2개 (7장) | **1개** | BO 가 하나여서 분리 이득이 없고 서비스·어노테이션만 이중 관리가 된다. 신청자와 승인자가 실무에서 겹친다. 역할 구분은 권한 + instance features 로 하고, 런치패드 타일만 2개로 나눈다 |
| 승인 기능 | 표준 Fiori 앱에 위임 검토 | **앱에 포함** | CBO 로 관리하는 목적이 결재 이력을 자사 대장에 남기는 것이므로, 승인이 앱 밖에 있으면 대장의 절반이 빈다 |
| 신청 기능 | 포함 여부 논의 | **앱에 포함** | 요건 "패키지/오브젝트 단위로만 등록"은 **신청 단계에서만** 강제할 수 있다. 승인만 하는 앱은 잘못된 범위를 사후 반려만 할 수 있다 |
| Option C 커스텀 체크 클래스 | A/B/C/D 비교 (4장) | **폐기** | 표준 네이밍 체크를 대체하면 표준 개선·노트 수혜를 잃고 유지보수 책임만 넘어온다. API 가 없으면 C 로 우회하지 않고 조회 전용(A)으로 후퇴한다 |
| 데이터 원천 | 표준 저장소 중심을 한때 권고 | **CBO 가 원천** | 관리 목적이 CBO 이므로 Z 테이블이 원천이고 표준 저장소는 실행용 반영 대상이다 |
| 적용범위 제어 | 검증 로직에서 판정 | **컨트롤 테이블 1개, 키는 체크 변형** | 무엇을 대상으로 볼지는 표준의 체크 변형이 이미 묶어놓았다. 변형 단위면 Phase 1 은 1행, Phase 2 도 3~4행이고 체크 추가가 변형 관리로 흡수된다 |
| 테이블 개수 | 7개 (5장) | **4개** | finding 스냅샷은 추세 리포팅이 요건에 없어 제거하고 라이브 조회로, 설정 2개는 1개로 통합 |
| 승인 레벨 | 설정 테이블의 `apprlevel` | **권한 오브젝트** | `Z_ATCEXEM` 에 `SCOPETYPE` 필드가 있어 PFCG 역할로 표현된다. 설정에 두면 이중 관리 |

## 18.2 관통 원칙 — 관리는 CBO, 실행은 표준

```
      관리 계층 (CBO, 자사 통제)              실행 계층 (표준, 미변경)
  ┌──────────────────────────────┐      ┌──────────────────────────────┐
  │ ztatcexempt   신청/승인 원천   │      │ 표준 ATC 예외 저장소          │
  │ ztatcexemptlog 결재 이력      │ ───► │                              │
  │ ztatccfg      동작 규칙(변형별)  │ 승인 │ 표준 ATC 가 억제              │
  │ Z_ATCEXEM     자사 권한 체계   │  시  │ (ADT / TR게이트 / CI-CD)     │
  └──────────────────────────────┘      └──────────────────────────────┘
              ▲                                        │
              └──── sync_from_standard ◄───────────────┘
                    (ADT 직접 신청건 흡수 + 정합성 점검)
```

이 구분이 "최대한 표준과 유사하게" 와 "CBO 로 관리" 를 동시에 만족시키는 선이다.
실행 메커니즘은 손대지 않고, 관리 계층만 자사 것으로 만든다.

## 18.3 요건이 코드가 아니라 설정으로 지켜지는 방식

`ztatccfg` (컨트롤 테이블 — 체크 단위 허용 플래그)

| CHECKGROUP | SCOPETYPE | ACTIVEFLG | APPRLEVEL | MAXVALIDMON |
|---|---|---|---|---|
| NAMING | FND | (공란) | | |
| NAMING | OBJ | X | 1 팀리더 | 12 |
| NAMING | PKG | X | 2 아키텍트 | 12 |

- **Phase 1**: `fndactive` 가 공란 → 화면 드롭다운에 뜨지 않고 `validateScope` 가 거부 → 요건 충족
- **Phase 2**: 성능·보안 변형 행 추가 (`fndactive = X`, `pkgactive` 공란) → **코드 변경 0**
- 체크가 새로 늘어나도 변형에 담기면 되므로 이 테이블은 손대지 않는다

체크마다 허용 범위가 정반대다. 성능·보안 체크는 라인별 판단이 본질이라 `FND` 를
열어야 하고, 반대로 보안 체크를 `PCKG` 로 열면 그 패키지의 보안 검증이 통째로 꺼진다.
그래서 허용 플래그를 체크 단위로 둔다.

소스 어디에도 `IF scopetype = 'FND'` 같은 하드코딩이 없다. 정책값은 전부
`zcl_atc_config` 를 통해 설정에서 읽는다.

## 18.4 데이터 모델 확정 — 테이블 4개

명명 규칙: **테이블 필드는 언더바 없이**, CBO 공통 이력 구조 **`ZSCM00010`** 포함,
업무 데이터 키는 **UUID**.

| 테이블 | 분류 | Delivery Class | 용도 |
|---|---|---|---|
| `ztatcexempt` | 업무 데이터 | `A` | 예외 신청 헤더 (승인 대상) |
| `ztatcexempti` | 업무 데이터 | `A` | 신청 아이템 (근거 finding) |
| `ztatcexemptlog` | 업무 데이터 | `A` | 상태 변경 이력 |
| `ztatccfg` | **컨트롤** | `C` | 앱 동작 규칙. 키는 **체크 변형** |

프로토타입의 2개(신청 헤더 + 아이템)에 **이력**(CBO 감사 목적)과 **컨트롤**(요건 강제)만
더한 구성이다.

### 무엇을 뺐고 왜인가

| 뺀 것 | 이유 |
|---|---|
| finding 스냅샷 테이블 + 적재 배치 + 보관 정책 | 추세 리포팅이 요건에 없다. `SATC_API_FINDINGS` 를 **라이브로 읽는다**. 네이밍만으로는 수천 건이라 성능도 문제되지 않는다. Phase 2 에서 건수가 커지면 그때 도입한다 |
| 설정 테이블 2개 → 1개 | 허용 여부를 행이 아니라 `fndactive`/`objactive`/`pkgactive` 플래그 컬럼으로 펼쳤다 |
| 체크 마스터 성격의 행 관리 | **키를 체크 변형으로 바꿨다.** 체크의 마스터는 표준이 갖고 있고 finding 에 실려 온다. 어떤 체크가 네이밍인지도 표준의 체크 변형이 안다. 우리는 변형 위에 정책만 얹는다 — Phase 1 은 1행 |
| `descr` 컬럼 | 표준이 check title 을 주므로 중복 |
| 설정의 `apprlevel` 컬럼 | 권한 오브젝트의 `SCOPETYPE` 필드와 중복 |

### `ztatccfg` 가 답하는 질문

```
① 이 변형의 결과가 앱 관리 대상인가?  -> activeflg                        (요건: 네이밍 건만)
② 어떤 적용범위를 허용하는가?         -> fndactive / objactive / pkgactive  (요건: 패키지/오브젝트만)
③ 유효기간 상한은?                   -> maxvalidmon
④ 어느 Priority 까지 허용하는가?       -> maxpriority
```

`checkgroup` 을 별도로 둔 이유는 변형명이 버전과 함께 바뀔 수 있어서다
(`Z_NAMING_V1` → `V2`). 권한 역할에는 더 안정적인 분류값을 쓴다.

업무 데이터가 아니라 **앱의 동작 규칙을 담는 스위치판**이다. 가동 전에 초기 데이터를
넣어야 하며, 비어 있으면 모든 신청이 거부된다.

### 아이템의 의미 (구현에 반영된 분기)

| SCOPETYPE | 아이템의 역할 |
|---|---|
| `FND` | 면제 대상 그 자체 (1:1). `resultid` / `itemid` / `lineno` 가 판정에 쓰인다. **단 이 값들은 ATC 실행 단위라 런마다 바뀌므로, FND 를 열기 전에 영구 식별자를 확보해야 한다** |
| `OBJ` / `PCKG` | **신청 근거(증빙) 스냅샷.** 효력은 오브젝트/패키지 전체이며 아이템에 담긴 건에 한정되지 않는다 |

`createFromFinding` 액션은 finding 의 **자연키**(패키지/오브젝트/체크/메시지)를 파라미터로
받는다. 라인 정보는 받지 않고 액션이 finding 을 다시 읽어 증빙에만 채운다 —
신청서 헤더에 라인을 올리지 않는다는 원칙을 호출자 쪽에서도 지키게 하려는 것이다.
패키지 스코프일 때는 헤더의 오브젝트 필드를 비워, 효력 범위가 패키지 전체임이
데이터에서도 드러나게 한다.

## 18.5 면제 판정

`ZI_AtcFinding` 이 finding 과 `ZI_AtcActiveExemption` 을 조인해 **조회 시마다 계산**한다.
상태를 finding 에 저장하지 않는다 — 저장하면 유효기간 만료를 반영할 수 없다.

**판정 조건에 소스 라인이 들어가지 않는 것이 요건의 기술적 실체다.**
코드를 고쳐 라인이 밀려도 `OBJ` / `PCKG` 예외는 유지된다.

## 18.6 패키지 승인 통제 (구현된 것)

| 장치 | 구현 위치 |
|---|---|
| 유효기간 필수 + 설정 기반 상한 | `validateValidity` (`ztatccfg-maxvalidmon`) |
| `PCKG` 승인은 더 높은 권한 | 권한 오브젝트 `Z_ATCEXEM` 의 `SCOPETYPE` + `is_approver` |
| 승인 전 영향도 확인 | `simulateImpact` 액션 |
| **상신 시 영향 건수를 근거 텍스트에 자동 기입** | `submit` 액션 |
| `PCKG` 행 경고색 표시 | `ScopeCriticality` |
| 자기승인 금지 | `get_instance_features` + `approve` 이중 차단 |
| 승인/반려 건 삭제 금지 | `get_instance_features` 의 `%delete` |

근거 텍스트 자동 기입이 특히 중요하다. 표준 승인 앱에는 영향도 화면이 없으므로,
어느 화면에서 결재하든 승인자가 파급 효과를 읽을 수 있게 하는 장치다.

## 18.7 Phase 1 선반영 (나중에 넣으면 비싼 것)

| 항목 | 미루면 |
|---|---|
| `lineno` / `resultid` / `itemid` / `checkrunindex` 컬럼 | 운영 데이터 있는 상태에서 구조변경 + CDS/BDEF 수정 + 마이그레이션 + 재테스트 |
| **권한 오브젝트 `Z_ATCEXEM` 의 4개 필드** | 🔴 PFCG 역할 전수 재작업 + 보안팀 재승인 + 감사 이슈 |
| 아이템 의미의 스코프별 분기 | 기존 데이터와 섞여 판정 버그 |
| 설정 기반 동적 범위 목록 | 전 로직 리팩터링 |

## 18.8 확인 결과 및 남은 과제

### 확인 완료 — 설계가 확정되었다

| 항목 | 결과 | 설계 영향 |
|---|---|---|
| `ZSCM00010` | `createdby` / `createdat` 등 | 같은 이름의 자체 컬럼이 **충돌**이었다. 제거하고 include 에 위임 |
| `SATC_API_FINDINGS` 키 | `resultid` + `itemid` + `checkrunindex` | 가정했던 `findingkey` 대체. `subobject` 없음 |
| **API State** | **릴리즈됨** | RAP 앱 전체를 **ABAP Cloud(Tier 1)** 로. 클래식 패키지 분리 불필요 |
| **적용범위 코드값** | `FND` / `OBJ` / **`PCKG`** | 가정했던 `PKG` 가 틀렸고 4자라 **필드 길이도 `char(4)`** 로 수정 |
| **표준 예외 API** | `CL_SATC_API=>CREATE_API_FACTORY( )->GET_EXEMPTION_CONTROLLER( )` | **Option B 확정, Option C 폐기** |

표준 승인 로직은 `SATC_CI_R_EXEMPTION` 의 `state` / `approver` 를 바꾸는 것이고,
그 경로가 위 컨트롤러다. 우리 앱도 같은 경로를 쓴다.

4장의 아키텍처 옵션 비교는 이로써 종료된다. **Option B (표준 Exemption 자동 생성)**
이며, 커스텀 체크 클래스는 만들지 않는다.

### 표준 반영 시점 — 승인 시

```
[상신 시 생성]  표준 저장소에 승인대기 예외가 생긴다
                 -> 표준 Fiori 승인 앱에서 누군가 먼저 승인할 수 있다
                 -> CBO 대장을 거치지 않은 결재가 생긴다  X

[승인 시 생성]  이 앱에서 결재가 끝난 뒤 승인 상태로 만들어 넣는다
                 -> 표준 저장소에는 이미 결정된 예외만 존재한다
                 -> 결재 창구가 이 앱 하나로 유지된다      O
```

3.1 장의 "승인 단일 창구" 원칙이 여기서 구현으로 내려온다.

### 남은 과제

| # | 항목 | 확인 방법 | 영향 범위 |
|---|---|---|---|
| 1 | `ZSCM00010` 의 변경자/변경일시 필드명 (`changedby`/`changedat` 가정) | ADT 에서 구조 열기 | CDS 2개 × 2줄 + BDEF 2줄 |
| 2 | `SATC_API_FINDINGS` 의 나머지 필드명 | ADT 에서 뷰 열기 | 리더 SELECT + `ZI_AtcFinding` |
| 3 | **예외 컨트롤러의 메소드 시그니처** 🔴 | `GET_EXEMPTION_CONTROLLER( )` 반환 타입의 메소드 목록 | `zcl_atc_exempt_sync` 세 메소드 |
| 4 | **FND 스코프의 영구 식별자** | Phase 2 착수 전 | `resultid` 3종은 런 단위라 재실행 시 매칭이 끊긴다. OBJ/PCKG 는 무관 |

3번만 채우면 표준 반영이 완성된다. 지금은 팩토리까지 호출해 컨트롤러를 얻어 두고,
그 위에서 무엇을 부를지만 비워 둔 상태다.
