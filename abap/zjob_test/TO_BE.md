# AS-IS 분석 & TO-BE 판정 — 배치잡 관리 인터페이스

> 대상: `ZBC_BATCH_JOB_CREATE` / `_DELETE` / `_STATUS` (GBC 시리즈 인터페이스)
> 상태: **APJ 컨버전 설계 확정** — 구현 뼈대는 [tobe/](tobe/) 참고

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
APJ 는 **화이트리스트 + 단일 실행 오브젝트** 모델이라 위 필드를 **직접은** 못 받는다.

다만 **런처(launcher) 패턴**으로 대부분을 우회할 수 있다 — 아래 3절.
직접 대응이 없다는 것과 구현이 불가능하다는 것은 다르다.

---

## 3. TO-BE 설계 — 런처 패턴으로 APJ 컨버전

상세 설계와 코드는 **[tobe/README.md](tobe/README.md)** 에 있다. 요약하면:

| 벽 | 해법 |
|----|------|
| APJ 는 등록된 클래스만 실행 | **"무엇이든 실행하는" 런처 클래스 1개**를 카탈로그에 등록. 무엇을 돌릴지는 파라미터로 |
| APJ 파라미터에 테이블(스텝 목록)을 못 넘김 | 스텝을 `ZTJOB_STEP` 에 저장하고 **잡 정의 ID 하나만** 파라미터로 전달 |
| Cloud 언어버전에서 `SUBMIT` 금지 | `Z_BC_RUN_REPORT` (Standard ABAP, Local API released) 에만 두고 런처가 호출 |
| 팩토리 캘린더 주기 옵션 없음 | APJ 는 "매일"로 걸고, 런처가 실행 시점에 작업일 판정해 skip |
| close 시각(`laststrt`) 옵션 없음 | 런처가 실행 시점에 시각 판정해 skip |

```
화면 → OData V4 → RAP action scheduleJob → CL_APJ_RT_API=>SCHEDULE_JOB (P_DEFID)
                                              → ZCL_APJ_JOB_LAUNCHER
                                                 → ZCL_BC_JOB_RUNNER
                                                    → Z_BC_RUN_REPORT (SUBMIT)
```

### 기능 손실 — 3개

| 항목 | 사유 | 확인 필요 |
|------|------|----------|
| **스텝별 실행 사용자** (`jobuser`) | `SUBMIT` 은 현재 사용자 권한으로 실행. 우회 없음 | AS-IS 에서 스텝마다 사용자가 실제로 다른가? |
| **잡 클래스 A/B/C** (`jobclass`) | APJ 에 개념 없음 | 실제로 A/B 를 쓰는 잡이 있나? |
| **외부 커맨드/프로그램** (`pgtype`≠PROG) | APJ 는 ABAP 클래스만 | `PROG` 외 값이 쓰이나? |

이 3개가 전부 "안 쓴다"면 **APJ 컨버전에 기능 손실이 없다.**

### 품질 저하 — 3개 (동작은 하되 SM36 만 못함)

| 항목 | 저하 내용 |
|------|----------|
| 다중 스텝 | 런처 LOOP 로 순차 실행은 되나 **스텝별 상태 구분이 안 되고 로그가 합쳐짐** |
| 잡 이름 | 사용자 지정 이름은 `ZTJOB_DEF-job_label` 에 보관. **SM37 에는 자동생성명으로 보임** |
| 팩토리 캘린더 | 잡은 매일 돌고 비작업일엔 skip 로그만 남음 |

### 개선 — 1개

| 항목 | 내용 |
|------|------|
| **타임존** | AS-IS 는 "시스템 zone시간" 을 받아 직접 변환했다. **APJ 는 프레임워크가 처리** (COMPARISON A4) |

---

## 4. ZJOB_TEST 비교 테스트의 역할

`zjob_test/` 의 비교 테스트는 위 "기능 손실 3개 / 품질 저하 3개"를 **실측으로 확정**하는 데 쓴다.

| 확정할 것 | 대응 TC |
|----------|---------|
| APJ 잡이 SM37 에 어떤 이름으로 보이는가 | TC01 (#16) |
| APJ 잡 로그 vs SM37 Job log 내용 차이 | TC01 (#18) |
| APJ 에 스풀이 생기는가 | TC07 (#9) |
| 취소 시 어느 시점에 끊기는가 | TC05 (#14) |
| 오류 종료 시 상태 표기 | TC06 (#15) |
| APJ 반복 주기의 실제 정확도 | TC02 |

---

## 5. 남은 확인 항목

| # | 확인할 것 | 왜 필요한가 |
|---|----------|-------------|
| 1 | **`ZBCS00110` 에 이벤트/선행 잡/대상 서버 필드가 있는지** | 확인된 주기 필드 외에 `event_id`(#6), `predjob`(#7), `targetserver`(#5)가 더 있으면 APJ 불가 항목 추가 |
| 2 | ~~`ZBCS0012` 필드 목록~~ | **확인 완료** — 스텝 목록 맞음. 다중 스텝 확정 (#1) |
| 3 | **Spring 호출 방식** | `sapjco3` 의존성 유무 → RFC 직통인지 SOAP(SPROXY) 경유인지 |
| 4 | **`CL_APJ_RT_API` 의 change/modify 메서드 존재 여부** | 없으면 change = cancel + 재스케줄 → 잡 이름/카운트가 바뀜 |
| 5 | GBC 시리즈 전체 인터페이스 목록 | create/delete/status 외 어떤 조작이 더 있는지 |
