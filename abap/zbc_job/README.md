# ZBC_JOB — 배치잡 인터페이스 Application Job 컨버전

AS-IS `ZBC_BATCH_JOB_CREATE` / `_CHANGE` / `_DELETE` / `_STATUS` (BDC on SM36) 를
**Application Job Framework** 로 옮긴 것.

---

## 1. 데이터 모델 — 테이블 2개

AS-IS 인터페이스 파라미터 구조가 그대로 테이블이 된다.

```
ls_info (ZBCS0011)  헤더 1건   →   ZTJOB_RUN   (root)
lt_pg   (ZBCS0012)  스텝 N건   →   ZTJOB_STEP  (composition child)
```

```
ZTJOB_RUN  ──1:N──  ZTJOB_STEP
```

| | 내용 | 건수 |
|---|---|---|
| **ZTJOB_RUN** | 배치잡 1건. 이름/클래스/시작조건/주기/캘린더 + APJ 가 준 `job_name`·`job_count` + 상태 | 잡 하나당 1건 |
| **ZTJOB_STEP** | 그 잡이 돌릴 프로그램들 (`pg_id` + 배리언트) | 잡 하나당 **1~N건** |

> SAP 에서 **"배치" = "job"** 이고 그 위에 더 큰 단위는 없다.
> `job 하나에 step 여러 개` 구조이며, AS-IS 에도 2스텝 잡이 실재한다.

예시:

```
ZTJOB_RUN   run_uuid=A1  job_label='월마감'  start_date=2026.10.01  prd_months=1
ZTJOB_STEP  run_uuid=A1  step_no=1  pg_id=ZR_CLOSE_STEP1  variant=DEFAULT
ZTJOB_STEP  run_uuid=A1  step_no=2  pg_id=ZR_CLOSE_STEP2  variant=MONTH
```

---

## 2. 왜 런처가 필요한가

APJ 는 **잡 카탈로그 엔트리에 등록된 클래스만** 실행한다.
AS-IS 는 화면에서 프로그램을 골라 스케줄하므로 카탈로그를 미리 만들 수 없다.

→ **"무엇이든 실행하는" 클래스 하나만 등록**하고, 무엇을 돌릴지는 파라미터로 받는다.

```
Job Catalog Entry  ZJC_BC_JOB   ← 1개
Job Template       ZJT_BC_JOB   ← 1개
Job (런타임)        P_RUNID 값만 다르게 해서 N개
```

APJ 파라미터(`tt_templ_val`)는 `selname`/`low`/`high` 구조라 스텝 테이블을 못 넘긴다.
그래서 **`P_RUNID` 하나만 넘기고 런처가 DB 에서 읽는다.**

```
scheduleJob 액션 → CL_APJ_RT_API=>SCHEDULE_JOB (P_RUNID = run_uuid)
                     → ZCL_APJ_JOB_LAUNCHER
                        → ZCL_BC_JOB_RUNNER   (조건 판정 + 스텝 LOOP)
                           → Z_BC_RUN_REPORT  (SUBMIT)
```

**대가**: APJ 의 카탈로그 화이트리스트(보안 통제)를 우회하게 된다.
실행 가능 프로그램 통제는 `check_parameters` 와 업무 권한으로 직접 해야 한다.

---

## 3. 파일

| 파일 | 언어버전 | 내용 |
|------|---------|------|
| `ztjob_run.tabl.abap` | — | root 테이블 (ZBCS0011) |
| `ztjob_step.tabl.abap` | — | child 테이블 (ZBCS0012) |
| `zi_job_run.ddls.abap` / `zi_job_step.ddls.abap` | — | interface view (composition) |
| `zc_job_run.ddls.abap` / `zc_job_step.ddls.abap` | — | projection view |
| `zd_job_schedule.ddls.abap` | — | `scheduleJob` 파라미터 |
| `zi_job_run.bdef.abap` / `zc_job_run.bdef.abap` | — | **BDEF + 액션 3종** |
| `zbp_i_job_run.clas.abap` | ABAP Cloud | 액션 구현 + 저장 시 검증 |
| `zcl_job_apj_adapter.clas.abap` | ABAP Cloud | `CL_APJ_RT_API` 래퍼 |
| `zcl_apj_job_launcher.clas.abap` | ABAP Cloud | **APJ 실행 오브젝트** |
| `zcl_bc_job_runner.clas.abap` | ABAP Cloud | 조건 판정 + 스텝 LOOP |
| `zif_bc_job.intf.abap` | ABAP Cloud | 상수/타입 |
| `z_bc_run_report.abap` | **Standard ABAP** | `SUBMIT` 래퍼 |
| `z_bc_check_workday.abap` | **Standard ABAP** | 팩토리 캘린더 판정 |
| `zui_bc_job.srvd.abap` | — | service definition |

Standard ABAP FM 2개는 SE37 > Goto > API State >
**"Use in Cloud Development"(Local API)** 로 release 해야 Cloud 티어에서 호출된다.

---

## 4. AS-IS 인터페이스 대응

| AS-IS | TO-BE |
|-------|-------|
| `ZBC_BATCH_JOB_CREATE` | `JobRun` create (+ `_Step` deep create) → action `scheduleJob` |
| `ZBC_BATCH_JOB_CHANGE` | `JobRun`/`Step` update → `cancelJob` + `scheduleJob` |
| `ZBC_BATCH_JOB_DELETE` | action `cancelJob` (+ delete) |
| `ZBC_BATCH_JOB_STATUS` | action `refreshStatus` / `JobRun` 조회 |

`reqid` / `reqname` / `reqdatetime` / 요청사유 → `ZTJOB_RUN` 컬럼으로 그대로 보존.

---

## 5. APJ 로 못 넘어가는 것

| AS-IS | 처리 | 확인 필요 |
|-------|------|----------|
| **`jobuser` 스텝별 실행 사용자** | **불가.** `SUBMIT` 은 현재 사용자 권한. 컬럼에 보관만 | AS-IS 에서 스텝마다 사용자가 실제로 다른가? |
| **`jobclass` A/B/C** | **불가.** APJ 에 개념 없음. 컬럼에 보관만 | 실제로 A/B 를 쓰나? |
| **`pgtype` ≠ PROG** | **불가.** 런처가 거부 | `PROG` 외 값이 쓰이나? |
| 다중 스텝 | 런처 LOOP. **SM37 에서 스텝별 상태를 못 봄** → `ZTJOB_STEP-exec_success`/`exec_message` 에 직접 기록해 조회 가능하게 함 | — |
| `jobname` 지정 | 논리명은 `job_label`, SM37 이름은 `job_name` 으로 나란히 보관 | — |
| 팩토리 캘린더 주기 | APJ 는 "매일"로 걸고 런처가 작업일 판정해 skip. **잡은 매일 돌고 skip 로그가 쌓임** | — |
| `laststrt` (close 시각) | 런처가 실행 시 판정해 skip | — |
| **타임존** | **APJ 가 기본 제공** — AS-IS 는 직접 변환했음 | — (개선) |

위 3개가 전부 "안 쓴다"로 나오면 **기능 손실 없이 컨버전된다.**

---

## 6. 생성 순서

1. 패키지 2개 — `ZBC_JOB` (ABAP Cloud) / `ZBC_JOB_CLASSIC` (Standard ABAP)
2. `ztjob_run`, `ztjob_step` → `zif_bc_job`
3. Standard ABAP FG `Z_BC_JOB_RUN` 에 `Z_BC_RUN_REPORT`, `Z_BC_CHECK_WORKDAY` 생성 후 **Local API release**
4. `zcl_bc_job_runner` → `zcl_apj_job_launcher`
5. **Job Catalog Entry `ZJC_BC_JOB`** (실행클래스 = `ZCL_APJ_JOB_LAUNCHER`) → **Job Template `ZJT_BC_JOB`**
6. CDS(interface → projection) → BDEF → `zbp_i_job_run`
7. Service Definition `ZUI_BC_JOB` → Service Binding (OData V4 - UI) → Publish

---

## 7. 미확인 지점

`TODO: 시그니처 확인` 주석 위치:

| 파일 | 확인할 것 |
|------|----------|
| `zcl_apj_job_launcher` | `IF_APJ_DT_EXEC_OBJECT~GET_PARAMETERS`/`CHECK_PARAMETERS`, `IF_APJ_RT_EXEC_OBJECT~EXECUTE` 시그니처, `CX_APJ_DT_CONTENT` textid |
| `zcl_job_apj_adapter` | `CL_APJ_RT_API=>TY_START_INFO` 필드명, `SCHEDULE_JOB`/`GET_JOB_STATUS`/`CANCEL_JOB` 시그니처, 상태값 도메인 |
| `z_bc_check_workday` | `DATE_CONVERT_TO_FACTORYDATE` 파라미터/예외명, `WORKINGDAY_INDICATOR` 값 의미 |
| — | `CL_APJ_RT_API` 에 change/modify 메서드가 있는지 (없으면 change = cancel + 재스케줄) |
| — | 백그라운드 `SUBMIT ... AND RETURN` 의 스풀 생성 여부 |

기능 비교 자료는 [`../zjob_test/COMPARISON.md`](../zjob_test/COMPARISON.md),
AS-IS 분석은 [`../zjob_test/TO_BE.md`](../zjob_test/TO_BE.md).
