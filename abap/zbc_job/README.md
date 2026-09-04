# ZBC_JOB — 배치잡 인터페이스 Application Job 컨버전

AS-IS `ZBC_BATCH_JOB_CREATE` / `_CHANGE` / `_DELETE` / `_STATUS` (BDC on SM36) 를
**Application Job Framework** 로 옮긴 것.

---

## 1. 데이터 모델 — 테이블 1개, 컬럼 12개

**필드를 3종류로 나눠서, DB 에는 꼭 필요한 것만 남겼다.**

| 종류 | 예 | 어디에 |
|------|-----|--------|
| APJ 가 이미 갖고 있는 것 | 시작일시, 반복주기, 타임존 | **DB 저장 안 함.** `scheduleJob` 액션 파라미터로만 받아 APJ 에 넘김 |
| 런처가 실행 시점에 읽는 것 | 배리언트, 팩토리캘린더, close 시각 | **`param` 에 JSON 직렬화** |
| 포인터 | template, jobname, jobcount, pgmid | DB 컬럼 |

```
ZTJOB_RUN
  run_uuid    RAP 키
  template    APJ 잡 템플릿
  jobtext     잡 텍스트 (논리 잡명)
  pgmid       실행할 프로그램
  param       런처 전달 파라미터 (JSON)
  jobname     APJ 가 만든 잡 이름 (SM37)
  jobcount    APJ 잡 카운트 (SM37)
  status      상태 캐시
  message     마지막 메시지
  + created_by / created_at / last_changed_by / local_last_changed_at
```

### 왜 `jobcount` 가 필요한가

APJ 잡의 키는 **`jobname + jobcount`** 다.
`jobcount` 없이는 `GET_JOB_STATUS` / `CANCEL_JOB` 을 호출할 수 없다.

### 요청자 정보는

`created_by` / `created_at` (RAP 관리 필드)이 대신한다.
요청사유처럼 별도 텍스트가 필요하면 `param` 에 넣거나 컬럼 하나만 추가한다.

### `param` 에 들어가는 것

```abap
TYPES: BEGIN OF ty_param,
         variant         TYPE c LENGTH 14,  " 리포트 배리언트
         calendar_id     TYPE c LENGTH 2,   " 공장시간
         workday_nr      TYPE i,            " 공장근무일수
         workday_time    TYPE t,            " 공장근무시간
         last_start_date TYPE d,            " close 일
         last_start_time TYPE t,            " close 시각
       END OF ty_param.
```

`ZCL_BC_JOB_PARAM` 이 XCO(Cloud released 직렬화 API)로 JSON 변환한다.
이 값들은 런처만 읽으므로 SQL 조건으로 쓸 일이 없어 컬럼으로 뺄 이유가 없다.

### 상태의 진실의 원천은 APJ

`status` 는 **목록 조회 때마다 API 를 부르지 않으려는 캐시**다.
`refreshStatus` 액션이 `GET_JOB_STATUS` 로 갱신한다.

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

APJ 파라미터(`tt_templ_val`)는 `selname`/`low`/`high` 구조라 복잡한 설정을 못 넘긴다.
그래서 **`P_RUNID`(스케줄 행 UUID) 하나만 넘기고 런처가 DB 에서 읽는다.**

```
scheduleJob 액션 → CL_APJ_RT_API=>SCHEDULE_JOB (P_RUNID = run_uuid)
                     → ZCL_APJ_JOB_LAUNCHER
                        → ZCL_BC_JOB_RUNNER   (조건 판정 + 실행)
                           → Z_BC_RUN_REPORT  (SUBMIT)
```

**대가**: APJ 의 카탈로그 화이트리스트(보안 통제)를 우회하게 된다.
실행 가능 프로그램 통제는 `check_parameters` 와 업무 권한으로 직접 해야 한다.

---

## 3. 파일

| 파일 | 언어버전 | 내용 |
|------|---------|------|
| `ztjob_run.tabl.abap` | — | 테이블 (유일, 12 컬럼) |
| `zi_job_run.ddls.abap` / `zc_job_run.ddls.abap` | — | interface / projection view |
| `zd_job_schedule.ddls.abap` | — | `scheduleJob` 파라미터 |
| `zi_job_run.bdef.abap` / `zc_job_run.bdef.abap` | — | **BDEF + 액션 3종 + 저장 검증** |
| `zbp_i_job_run.clas.abap` | ABAP Cloud | 액션 구현 |
| `zcl_job_apj_adapter.clas.abap` | ABAP Cloud | `CL_APJ_RT_API` 래퍼 |
| `zcl_apj_job_launcher.clas.abap` | ABAP Cloud | **APJ 실행 오브젝트** |
| `zcl_bc_job_runner.clas.abap` | ABAP Cloud | 조건 판정 + 실행 |
| `zif_bc_job.intf.abap` | ABAP Cloud | 상수/타입 (`ty_param`, `ty_start_option`) |
| `zcl_bc_job_param.clas.abap` | ABAP Cloud | `param` JSON 직렬화 (XCO) |
| `z_bc_run_report.abap` | **Standard ABAP** | `SUBMIT` 래퍼 |
| `z_bc_check_workday.abap` | **Standard ABAP** | 팩토리 캘린더 판정 |
| `zui_bc_job.srvd.abap` | — | service definition |

Standard ABAP FM 2개는 SE37 > Goto > API State >
**"Use in Cloud Development"(Local API)** 로 release 해야 Cloud 티어에서 호출된다.

---

## 4. AS-IS 인터페이스 대응

| AS-IS | TO-BE |
|-------|-------|
| `ZBC_BATCH_JOB_CREATE` | `JobRun` create → action `scheduleJob` |
| `ZBC_BATCH_JOB_CHANGE` | `JobRun` update → `cancelJob` + `scheduleJob` |
| `ZBC_BATCH_JOB_DELETE` | action `cancelJob` (+ delete) |
| `ZBC_BATCH_JOB_STATUS` | action `refreshStatus` / `JobRun` 조회 |

`reqid` / `reqname` / `reqdatetime` / 요청사유 → `ZTJOB_RUN` 컬럼으로 그대로 보존.

---

## 5. APJ 로 못 넘어가는 것

| AS-IS | 처리 | 확인 필요 |
|-------|------|----------|
| **`jobuser` 실행 사용자** | **불가.** `SUBMIT` 은 현재 사용자 권한. 컬럼에 보관만 | AS-IS 에서 잡마다 사용자가 다른가? |
| **`jobclass` A/B/C** | **불가.** APJ 에 개념 없음. 컬럼에 보관만 | 실제로 A/B 를 쓰나? |
| **`pgtype` ≠ PROG** | **모델에서 제외.** ABAP 리포트만 지원 | `PROG` 외 값이 쓰이나? |
| 다중 스텝 | **모델에서 제외.** 잡 1개 = 프로그램 1개 | 2스텝 잡을 어떻게 나눌지 |
| `jobname` 지정 | 논리명은 `jobtext`, SM37 이름은 `jobname` 으로 나란히 보관 | — |
| 팩토리 캘린더 주기 | APJ 는 "매일"로 걸고 런처가 작업일 판정해 skip. **잡은 매일 돌고 skip 로그가 쌓임** | — |
| `laststrt` (close 시각) | 런처가 실행 시 판정해 skip | — |
| **타임존** | **APJ 가 기본 제공** — AS-IS 는 직접 변환했음 | — (개선) |

---

## 6. 생성 순서

1. 패키지 2개 — `ZBC_JOB` (ABAP Cloud) / `ZBC_JOB_CLASSIC` (Standard ABAP)
2. `ztjob_run` → `zif_bc_job`
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
| `zcl_bc_job_param` | `XCO_CP_JSON` 메서드 체인 (`from_abap`/`to_string`/`from_string`/`write_to`) |
| — | `CL_APJ_RT_API` 에 change/modify 메서드가 있는지 (없으면 change = cancel + 재스케줄) |
| — | 백그라운드 `SUBMIT ... AND RETURN` 의 스풀 생성 여부 |

기능 비교 자료는 [`../zjob_test/COMPARISON.md`](../zjob_test/COMPARISON.md),
AS-IS 분석은 [`../zjob_test/TO_BE.md`](../zjob_test/TO_BE.md).
