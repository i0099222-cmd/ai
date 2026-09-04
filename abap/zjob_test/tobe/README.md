# TO-BE — AS-IS 배치잡 인터페이스의 Application Job 컨버전

AS-IS `ZBC_BATCH_JOB_CREATE` / `_CHANGE` / `_DELETE` / `_STATUS` (BDC on SM36) 를
**Application Job Framework 위에서** 재현하는 구현 뼈대.

기능 비교 근거는 [../COMPARISON.md](../COMPARISON.md), AS-IS 분석은 [../TO_BE.md](../TO_BE.md).

---

## 1. 두 개의 벽과 그 해법

APJ 로 범용 스케줄러를 만들 때 막히는 지점은 정확히 두 개다.

### 벽 ①  "APJ 는 임의 프로그램을 못 돌린다"

APJ 는 잡 카탈로그 엔트리에 등록된 **클래스**만 실행한다. AS-IS 는 `pgid` 를
파라미터로 받아 아무 리포트나 건다.

**해법 — 런처(launcher) 패턴.** "무엇이든 실행하는 클래스" 하나를 등록하고,
무엇을 돌릴지는 파라미터로 받는다.

```
Job Catalog Entry  ZJC_JOB_LAUNCHER   ← 딱 1개
      └─ 실행클래스 ZCL_APJ_JOB_LAUNCHER
Job Template       ZJT_JOB_LAUNCHER   ← 딱 1개
      └─ 파라미터  P_DEFID (잡 정의 ID) 하나뿐
Job (런타임)        P_DEFID 값만 다르게 해서 N 개
```

잡마다 카탈로그 엔트리를 만들 필요가 없다.

### 벽 ②  "APJ 파라미터에 테이블을 못 넘긴다"

APJ 파라미터(`tt_templ_val`)는 `selname` / `low` / `high` 구조다.
AS-IS 의 `lt_pg`(다중 스텝)를 통째로 넘길 방법이 없다.

**해법 — 스텝을 DB 에 두고 ID 만 넘긴다.**

```
ZTJOB_DEF    잡 정의 헤더  (논리 잡명, 시스템/클라이언트, 요청자, 캘린더, close 시각)
ZTJOB_STEP   잡 정의 스텝  (pg_id, pg_variant, pg_lang, step_no)   ← 다중 스텝
ZTJOB_RUN    스케줄/실행 이력 (APJ jobname/jobcount, 상태)

APJ 스케줄 ──P_DEFID──▶ 런처가 DEF/STEP 읽어서 순차 실행
```

### 그리고 SUBMIT

`SUBMIT` 은 ABAP Cloud 언어버전에서 금지다.
→ **`Z_BC_RUN_REPORT` (Standard ABAP FM, Local API released)** 에만 두고 런처가 호출한다.
이 리포의 `ZCL_PARKED_DOC_POSTER` → `Z_FI_PARKED_DOC_POST_BDC` 와 같은 패턴.

---

## 2. 전체 흐름

```
화면
 │ OData V4
 ▼
RAP  ZC_JOB_DEF (+ _Step composition)
 │    create/update/delete  = AS-IS create / change / delete
 │    action scheduleJob    → CL_APJ_RT_API=>SCHEDULE_JOB (P_DEFID 전달)
 │    action cancelJob      → CANCEL_JOB
 │    action refreshStatus  → GET_JOB_STATUS
 ▼
Application Job (ZJT_JOB_LAUNCHER)
 ▼
ZCL_APJ_JOB_LAUNCHER   [ABAP Cloud]   ← IF_APJ_DT/RT_EXEC_OBJECT
 ▼
ZCL_BC_JOB_RUNNER      [ABAP Cloud]   ← 조건 판정 + 스텝 LOOP
 ├─ Z_BC_CHECK_WORKDAY  [Standard ABAP]  팩토리 캘린더 판정
 └─ Z_BC_RUN_REPORT     [Standard ABAP]  SUBMIT (pgid) USING SELECTION-SET (variant)
```

---

## 3. AS-IS 필드가 어디로 갔나

| AS-IS | TO-BE 처리 | 완전성 |
|-------|-----------|--------|
| `pgid` (임의 프로그램) | `ZTJOB_STEP` → 런처 → `Z_BC_RUN_REPORT` 의 `SUBMIT` | **○ 완전** |
| `pgvariant` | `SUBMIT ... USING SELECTION-SET` | **○ 완전** |
| `pglang` | `Z_BC_RUN_REPORT` 파라미터 | ○ |
| 배치잡 시작시간 | APJ 스케줄 옵션 | ○ |
| 반복주기 / 일반복주기 | APJ 반복 패턴 | ○ |
| **시스템 zone시간** | **APJ 가 기본 제공** | **◎ 개선** (AS-IS 는 직접 구현했음) |
| `laststrtdt` / `laststrttm` (close) | `ZTJOB_DEF` 컬럼 → 런처가 실행 시 판정해 skip | **○ 완전** |
| 시스템 / 클라이언트 / 업무구분 | `ZTJOB_DEF` 컬럼 | ○ |
| 요청자 사번·이름·시각 / 요청사유 | `ZTJOB_DEF` 컬럼 | ○ |
| **다중 스텝 (`lt_pg`)** | 런처가 `ZTJOB_STEP` 을 LOOP 순차 실행 | **△ 스텝별 상태 구분 안 됨, 로그 합쳐짐** |
| **`jobname` 직접 지정** | `ZTJOB_DEF-job_label` 에 논리명 저장, SM37 자동생성명과 `ZTJOB_RUN` 에서 매핑 | **△ 이름이 두 개** |
| **팩토리 캘린더 주기** | APJ 는 "매일" 로 걸고 런처가 작업일 판정해 skip | **△ 잡은 매일 돎, skip 로그 쌓임** |
| **`jobuser` 스텝별 실행 사용자** | **우회 없음** — `SUBMIT` 은 현재 사용자 권한으로 실행 | **✗ 불가** |
| **`jobclass` A/B/C** | **우회 없음** — APJ 에 개념 없음 | **✗ 불가** |
| `pgtype` 외부 커맨드/프로그램 | 런처가 거부 (`PROG` 만 지원) | **✗ 불가** |

### 못 하는 3가지 — 확인 필요

1. **스텝별 실행 사용자** — AS-IS 에서 스텝마다 사용자가 실제로 다른가?
   전부 같으면 문제없다. 다르면 그 잡은 스텝별로 쪼개서 각각 스케줄해야 한다.
2. **잡 클래스 A/B/C** — 실제로 A 나 B 를 쓰는 잡이 있나? C(기본)만 쓰면 문제없다.
3. **`pgtype`** — `PROG` 외의 값이 실제로 쓰이나?

이 3개가 전부 "안 쓴다"로 나오면 **APJ 컨버전에 기능 손실이 없다.**

---

## 4. 파일

| 파일 | 언어버전 | 내용 |
|------|---------|------|
| `zif_bc_job.intf.abap` | ABAP Cloud | 파라미터명 / 상태 / skip 사유 상수, 실행 결과 타입 |
| `ztjob_def.tabl.abap` | — | 잡 정의 헤더 (AS-IS ZBCS0011 대응) |
| `ztjob_step.tabl.abap` | — | 잡 정의 스텝 (AS-IS ZBCS0012 / `lt_pg` 대응) |
| `zcl_apj_job_launcher.clas.abap` | ABAP Cloud | **APJ 실행 오브젝트** — `IF_APJ_DT/RT_EXEC_OBJECT` |
| `zcl_bc_job_runner.clas.abap` | ABAP Cloud | 실행 조건 판정 + 스텝 LOOP |
| `z_bc_run_report.abap` | **Standard ABAP** | `SUBMIT` 래퍼 — 벽 ① 을 푸는 열쇠 |
| `z_bc_check_workday.abap` | **Standard ABAP** | 팩토리 캘린더 작업일 판정 |

Standard ABAP FM 2개는 SE37 > Goto > API State >
**"Use in Cloud Development"(Local API)** 로 release 해야 Cloud 티어에서 호출된다.

---

## 5. 생성 순서

1. 패키지 2개 — `ZBC_JOB` (ABAP Cloud) / `ZBC_JOB_CLASSIC` (Standard ABAP)
2. `ztjob_def`, `ztjob_step` 테이블 → `zif_bc_job` 인터페이스
3. Standard ABAP FG `Z_BC_JOB_RUN` 에 `Z_BC_RUN_REPORT`, `Z_BC_CHECK_WORKDAY` 생성 후 **Local API release**
4. `zcl_bc_job_runner` → `zcl_apj_job_launcher`
5. **Job Catalog Entry `ZJC_JOB_LAUNCHER`** (실행클래스 = `ZCL_APJ_JOB_LAUNCHER`)
6. **Job Template `ZJT_JOB_LAUNCHER`**
7. RAP 계층 — `ZI_JOB_DEF` + `ZI_JOB_STEP`(composition) + BDEF + BP + service (다음 단계)

---

## 6. 미확인 지점

| 파일 | 확인할 것 |
|------|----------|
| `zcl_apj_job_launcher` | `IF_APJ_DT_EXEC_OBJECT~GET_PARAMETERS`/`CHECK_PARAMETERS`, `IF_APJ_RT_EXEC_OBJECT~EXECUTE` 시그니처, `CX_APJ_DT_CONTENT` textid |
| `z_bc_run_report` | 백그라운드 `SUBMIT ... AND RETURN` 의 스풀 생성 여부 (COMPARISON #9) |
| `z_bc_check_workday` | `DATE_CONVERT_TO_FACTORYDATE` 파라미터/예외명, `WORKINGDAY_INDICATOR` 값 의미 |
| `zcl_apj_job_launcher~write_run_log` | APJ 런타임에서 현재 잡 이름/카운트를 얻는 방법 (COMPARISON #16) |
| — | `CL_APJ_RT_API` 에 change/modify 메서드가 있는지 (없으면 change = cancel + 재스케줄) |
