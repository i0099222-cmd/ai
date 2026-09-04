# AS-IS 분석 & TO-BE 판정 — 배치잡 관리 인터페이스

> 대상: `ZBC_BATCH_JOB_CREATE` / `_DELETE` / `_STATUS` (GBC 시리즈 인터페이스)
> 상태: **판정 확정 — Application Job 전면 대체 불가**

---

## 1. AS-IS 구조

```
화면
 │  HTTP POST /GBC00001 (JSON)
 ▼
Spring Boot ("PO")  @PostMapping("/GBC00001")
 │  JCo(RFC) 또는 SOAP  ← 확정 필요 (SPROXY 경로 존재)
 ▼
ZBC_BATCH_JOB_CREATE / _DELETE / _STATUS
 │
 ▼
BDC (CALL TRANSACTION 'SM36')
```

### `ZBC_BATCH_JOB_CREATE` 시그니처

| 구분 | 파라미터 | 내용 |
|------|---------|------|
| IMPORTING | `reqid` | 요청자 사번 |
| | `reqname` | 요청자 이름 |
| | `reqdatetime` | 요청 시간 |
| | `ls_info` | `ZBCS00110` — 잡 생성 입력 파라미터 |
| EXPORTING | `reqid` / `reqname` / `reqdatetime` | 요청 정보 에코 |
| | `status` / `message` | 처리 결과 |
| TABLES | `lt_pg` | `ZBCS0012` — 잡 생성 인터페이스 (스텝 목록으로 추정) |

### BDC 화면 조작 (SM36 3단계)

**① 첫 화면 — 잡 헤더**

`jobname`, `jobclass`

**② Step 등록 — `lt_pg` 각 행마다 1스텝**

| 필드 | 의미 |
|------|------|
| `pgtype = 'PROG'` | 스텝 종류 (ABAP 리포트 / 외부 커맨드 / 외부 프로그램) |
| `jobuser` | 스텝 실행 사용자 |
| `pgid` | **실행할 리포트 이름** — 호출자가 지정 |
| `pgvariant` | 리포트 배리언트 |
| `pglang` | 실행 언어 |

`lt_pg` 가 TABLES(다중 행)이고 위 필드를 담으므로 **다중 스텝 잡이 확정**이다.

**③ 시작 조건 — 주기**

`facdatetime`, `workday`, `worktime`, `workperiod`,
`sdlstrtdt`, `sdlstrttm`, `laststrtdt`, `laststrttm`, `lv_time`

- `sdlstrtdt`/`sdlstrttm` : 예정 시작 일시
- `laststrtdt`/`laststrttm` : **최종 시작 가능 일시** (이 시각을 넘기면 실행하지 않음)
- `facdatetime`/`workday`/`workperiod` : **팩토리 캘린더 기준 작업일 실행**

---

## 2. 판정 — Application Job 1:1 대체 불가

BDC 가 채우는 필드 **9종이 전부** Application Job 에 대응이 없다.

| AS-IS 필드 | SM36 기능 | Application Job 대응 | 판정 | 근거 |
|-----------|----------|---------------------|------|------|
| **`pgid`** | 임의 프로그램 지정 | 카탈로그 엔트리 **화이트리스트**만 | **✗ 치명적** | APJ 는 실행 클래스 사전 등록 필수 |
| **`pgvariant`** | 리포트 배리언트 | 배리언트 개념 없음 | ✗ | COMPARISON #10 |
| **`jobuser`** | 스텝별 실행 사용자 | 스케줄 사용자 컨텍스트 고정 | ✗ | COMPARISON #2 |
| **`pgtype`** | 스텝 종류(외부 커맨드 등) | ABAP 클래스만 | ✗ | COMPARISON #3 |
| **`lt_pg` 다중 행** | 다중 스텝 | 실행 오브젝트 1개 | ✗ **확정** | COMPARISON #1 |
| **`jobclass`** | 우선순위 A/B/C | 대응 파라미터 없음 | ✗ | COMPARISON #4 |
| **`jobname`** | 잡 이름 직접 지정 | 프레임워크 자동 생성 | ✗ | COMPARISON #16 |
| **`facdatetime`/`workday`/`workperiod`** | 팩토리캘린더 작업일 실행 | 대응 없음 | ✗ | COMPARISON #12 |
| **`laststrtdt`/`laststrttm`** | 최종 시작 가능 일시 | 대응 확인 안 됨 | ✗ *(확인)* | COMPARISON #19 |
| `reqid` / `reqname` / `reqdatetime` | 요청자 추적 | RAP 관리필드 + 커스텀 필드 | ○ | |
| `status` / `message` | 처리 결과 | RAP `reported` / 로그 테이블 | ○ | |

### 결론

AS-IS 는 **"임의의 프로그램을 다중 스텝으로 스케줄하는 범용 잡 생성기"** 다.
Application Job Framework 는 **화이트리스트 + 단일 실행 오브젝트** 모델이므로
이 요구사항을 구조적으로 만족할 수 없다. 대체 가능한 필드가 하나도 없다.

---

## 3. TO-BE 권고 — A안: BDC 제거 + 클래식 유지

BDC 를 표준 FM 으로 바꾸면 **AS-IS 기능을 하나도 잃지 않고** 화면 의존을 제거할 수 있다.

필드 단위 매핑이 거의 1:1 이다. BDC 가 원래 그 화면 필드를 채우던 것이라 이름까지 같다.

| AS-IS 필드 | 표준 FM | 파라미터 |
|-----------|---------|---------|
| `jobname` | `JOB_OPEN` | `JOBNAME` |
| `jobclass` | `JOB_OPEN` | `JOBCLASS` |
| `pgid` | `JOB_SUBMIT` | `REPORT` |
| `pgvariant` | `JOB_SUBMIT` | `VARIANT` |
| `jobuser` | `JOB_SUBMIT` | `AUTHCKNAM` |
| `pglang` | `JOB_SUBMIT` | `LANGUAGE` |
| `pgtype` | `JOB_SUBMIT` | `REPORT` / `COMMANDNAME` / `EXTPGM_NAME` 로 분기 |
| `sdlstrtdt` / `sdlstrttm` | `JOB_CLOSE` | `SDLSTRTDT` / `SDLSTRTTM` |
| `laststrtdt` / `laststrttm` | `JOB_CLOSE` | `LASTSTRTDT` / `LASTSTRTTM` |
| `workperiod` (주기) | `JOB_CLOSE` | `PRDMINS` / `PRDHOURS` / `PRDDAYS` / `PRDWEEKS` / `PRDMONTHS` |
| `facdatetime` / `workday` | `JOB_CLOSE` | `CALENDAR_ID`, `START_ON_WORKDAY_NR`, `WORKDAY_COUNT_DIRECTION`, `START_ON_WORKDAY_NOT_BEFORE` |
| (삭제) | `BP_JOB_DELETE` | |
| (조회) | `BP_JOB_SELECT` / `BP_JOB_READ` / TBTCO·TBTCP | |

> `JOB_SUBMIT` 은 스텝마다 반복 호출한다. `lt_pg` 를 그대로 LOOP 돌리면 된다.
> 정확한 파라미터명은 SE37 에서 각 FM 의 시그니처로 확인할 것.

**BDC 대비 이점**: 화면을 타지 않으므로 조건부 팝업·SP 업그레이드로 인한 화면 변경 리스크가 사라진다.

### 아키텍처

```
AS-IS:  화면 → Spring → (PI?) → RFC → BDC → SM36 화면
TO-BE:  화면 → OData V4 → RAP action → Z_BC_JOB_SCHEDULE (Standard ABAP FM)
                                          → JOB_OPEN / JOB_SUBMIT / JOB_CLOSE
```

`JOB_*` FM 은 ABAP Cloud 언어버전에서 호출 불가이므로,
**Standard ABAP FM 으로 감싸고 Local API 로 release** 해서 RAP(Cloud 티어)에서 호출한다.
→ 이 리포의 `ZCL_PARKED_DOC_POSTER` → `Z_FI_PARKED_DOC_POST_BDC` 와 동일한 패턴.

### RAP 계층 재사용

`odata/` 의 뼈대를 그대로 쓰되 액션 매핑만 바꾼다:

| AS-IS RFC | RAP action | 내부 |
|-----------|-----------|------|
| `ZBC_BATCH_JOB_CREATE` | `scheduleJob` | `JOB_OPEN` → `JOB_SUBMIT`(n회) → `JOB_CLOSE` |
| `ZBC_BATCH_JOB_DELETE` | `deleteJob` | `BP_JOB_DELETE` |
| `ZBC_BATCH_JOB_STATUS` | `refreshStatus` | `BP_JOB_SELECT` |
| `..._CHANGE` | `changeJob` | `BP_JOB_MODIFY` 또는 delete + 재생성 |

`ZTJOB_RUN` 에 `reqid` / `reqname` / `reqdatetime` 컬럼을 추가하면
요청자 추적이 그대로 유지된다.

---

## 4. Application Job 적용 범위 — 혼합

| 대상 | 방식 |
|------|------|
| 신규 잡, 대상 프로그램이 **고정** | **Application Job** (카탈로그 엔트리 생성 가능) |
| 기존 범용 스케줄러 | **클래식 + BDC 제거** |
| 중장기 | 사용 빈도 높은 프로그램 Top-N 을 카탈로그 엔트리로 올려 점진 이관 |

`ZJOB_TEST` 비교 테스트는 **"왜 APJ 로 전면 전환하지 않았는가"** 를 설명하는 실증 근거로 쓴다.
COMPARISON.md 의 #1 / #4 / #5 / #16 이 여기 직접 대응한다.

---

## 5. 남은 확인 항목

| # | 확인할 것 | 왜 필요한가 |
|---|----------|-------------|
| 1 | **`ZBCS00110` 에 이벤트/선행 잡/대상 서버 필드가 있는지** | 확인된 주기 필드 외에 `event_id`(#6), `predjob`(#7), `targetserver`(#5)가 더 있으면 APJ 불가 항목 추가 |
| 2 | ~~`ZBCS0012` 필드 목록~~ | **확인 완료** — 스텝 목록 맞음. 다중 스텝 확정 (#1) |
| 3 | **Spring 호출 방식** | `sapjco3` 의존성 유무 → RFC 직통인지 SOAP(SPROXY) 경유인지 |
| 4 | **`CL_APJ_RT_API` 의 change/modify 메서드 존재 여부** | 없으면 change = cancel + 재스케줄 → 잡 이름/카운트가 바뀜 |
| 5 | GBC 시리즈 전체 인터페이스 목록 | create/delete/status 외 어떤 조작이 더 있는지 |
