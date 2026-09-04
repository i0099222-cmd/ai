# ZBC_JOB — 배치잡 인터페이스 Application Job 컨버전

AS-IS `ZBC_BATCH_JOB_CREATE` / `_CHANGE` / `_DELETE` / `_STATUS` (BDC on SM36) 를
**Application Job Framework** 로 옮긴 것.

---

## 1. 데이터 모델 — 테이블 1개, 컬럼 10개

이 테이블은 **스케줄 등록부**다. 실행 상태와 로그는 갖지 않는다 — 별도 로그 기능 담당.

```
ZTJOB_RUN
  run_uuid    RAP 키
  template    APJ 잡 템플릿
  jobtext     잡 텍스트 (논리 잡명)
  exec_class  실행 클래스 (ZIF_BC_JOB_STEP 구현체)
  param       런처 전달 파라미터 (JSON)
  jobname     APJ 가 만든 잡 이름 (SM37)
  jobcount    APJ 잡 카운트 (SM37)
  created_by  누가 걸었나
  created_at  언제 걸었나
  local_last_changed_at   etag
```

### 필드를 3종류로 나눈 결과

| 종류 | 예 | 어디에 |
|------|-----|--------|
| APJ 가 이미 갖고 있는 것 | 시작일시, 반복주기, 타임존 | **저장 안 함.** `scheduleJob` 액션 파라미터로만 받아 APJ 에 넘김 |
| 런처가 실행 시점에 읽는 것 | 팩토리캘린더, close 시각 | **`param.cond` 에 JSON 직렬화** |
| 스텝에 넘길 업무 파라미터 | 리포트 배리언트를 대신 | **`param.app` 에 JSON 직렬화** |
| 실행 상태 / 이력 | 상태, 실행 메시지 | **저장 안 함.** 별도 로그 기능 |
| 포인터 | template, jobname, jobcount, exec_class | DB 컬럼 |

### 상태 컬럼이 없어도 되는 이유

**`jobname` 유무가 곧 스케줄 여부다.**

| `jobname` | 의미 | 활성 액션 |
|-----------|------|----------|
| 비어 있음 | 아직 스케줄 안 함 | `scheduleJob` |
| 차 있음 | 스케줄됨 | `cancelJob`, `refreshStatus` |

`cancelJob` 은 취소 후 `jobname`/`jobcount` 를 비운다 → 같은 행을 다시 스케줄할 수 있다.
실제 실행 상태(Running / Finished / Aborted)는 `refreshStatus` 가 APJ 에서 읽어
**메시지로만** 돌려준다. DB 에 쓰지 않는다.

### 런처는 DB 에 아무것도 안 쓴다

`ZCL_BC_JOB_RUNNER` 는 읽고 → 판정하고 → 실행하고 → 결과를 반환만 한다.
`COMMIT WORK` 도 없다. 실행 흔적은 잡 로그(`MESSAGE`)로만 남고,
그 로그는 별도 로그 기능이 수집한다.

### 왜 `jobcount` 가 필요한가

APJ 잡의 키는 **`jobname + jobcount`** 다.
`jobcount` 없이는 `GET_JOB_STATUS` / `CANCEL_JOB` 을 호출할 수 없다.

### `param` 에 들어가는 것

```abap
TYPES: BEGIN OF ty_condition,
         calendar_id     TYPE c LENGTH 2,   " 공장시간
         workday_nr      TYPE i,            " 공장근무일수
         workday_time    TYPE t,            " 공장근무시간
         last_start_date TYPE d,            " close 일
         last_start_time TYPE t,            " close 시각
       END OF ty_condition.

TYPES: BEGIN OF ty_param,
         cond TYPE ty_condition,   " 런처가 읽는 실행 조건
         app  TYPE string,         " 스텝 클래스에 넘길 업무 파라미터
       END OF ty_param.
```

`ZCL_BC_JOB_PARAM` 이 XCO(Cloud released 직렬화 API)로 JSON 변환한다.
`app` 은 런처가 해석하지 않고 스텝 클래스에 그대로 넘긴다 — **리포트 배리언트를 대신하는 자리**다.

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

## 2-1. 실행 대상은 리포트가 아니라 클래스

**`SUBMIT` 은 ABAP for Cloud Development 에서 금지된다.**
임의 리포트를 돌리려면 Standard ABAP FM 을 경유해야 하고, 그러면 순수 Cloud 구성이 깨진다.

그래서 실행 대상을 **`ZIF_BC_JOB_STEP` 을 구현한 클래스**로 둔다.
이 구성에는 Standard ABAP 오브젝트가 **하나도 없다.**

```abap
INTERFACE zif_bc_job_step PUBLIC.
  METHODS execute
    IMPORTING iv_param          TYPE string OPTIONAL
    RETURNING VALUE(rv_message) TYPE string
    RAISING   zcx_bc_job.
ENDINTERFACE.
```

런처는 `EXEC_CLASS` 이름으로 동적 생성해서 부른다:

```abap
DATA lo_step TYPE REF TO zif_bc_job_step.
CREATE OBJECT lo_step TYPE (ls_run-exec_class).
rs_result-message = lo_step->execute( ls_param-app ).
```

### 기존 배치 리포트 이관

| 리포트 | 스텝 클래스 |
|--------|------------|
| `START-OF-SELECTION` 로직 | `EXECUTE` 메서드 |
| 셀렉션 스크린 파라미터 | `IV_PARAM` (JSON) — 배리언트를 대신함 |
| `WRITE` 리스트 | `MESSAGE` 또는 반환 문자열 → 잡 로그 |
| 실패 처리 | `RAISE EXCEPTION NEW zcx_bc_job( )` → 잡 오류 종료 |

`example_zcl_bc_step_sample.clas.abap` 이 그 형태의 예시다.

---

## 3. 파일

| 파일 | 언어버전 | 내용 |
|------|---------|------|
| `ztjob_run.tabl.abap` | — | 테이블 (유일, 10 컬럼) |
| `zi_job_run.ddls.abap` / `zc_job_run.ddls.abap` | — | interface / projection view |
| `zd_job_schedule.ddls.abap` | — | `scheduleJob` 파라미터 |
| `zi_job_run.bdef.abap` / `zc_job_run.bdef.abap` | — | **BDEF + 액션 3종 + 저장 검증** |
| `zbp_i_job_run.clas.abap` | ABAP Cloud | 액션 구현 (상태 컬럼 없이 `jobname` 유무로 제어) |
| `zcl_job_apj_adapter.clas.abap` | ABAP Cloud | `CL_APJ_RT_API` 래퍼 |
| `zcl_apj_job_launcher.clas.abap` | ABAP Cloud | **APJ 실행 오브젝트** |
| `zcl_bc_job_runner.clas.abap` | ABAP Cloud | 조건 판정 + 실행 클래스 동적 호출 (DB 쓰기 없음) |
| `zif_bc_job_step.intf.abap` | ABAP Cloud | **실행 클래스가 구현할 인터페이스** |
| `zcx_bc_job.clas.abap` | ABAP Cloud | 실행 예외 |
| `example_zcl_bc_step_sample.clas.abap` | ABAP Cloud | 실행 클래스 작성 예시 (참고용) |
| `zif_bc_job.intf.abap` | ABAP Cloud | 상수/타입 (`ty_param`, `ty_start_option`) |
| `zcl_bc_job_param.clas.abap` | ABAP Cloud | `param` JSON 직렬화 (XCO) |
| `zui_bc_job.srvd.abap` | — | service definition |

**전부 ABAP for Cloud Development 다.** Standard ABAP 오브젝트가 하나도 없고,
Local API release 도 필요 없다.

---

## 4. AS-IS 인터페이스 대응

| AS-IS | TO-BE |
|-------|-------|
| `ZBC_BATCH_JOB_CREATE` | `JobRun` create → action `scheduleJob` |
| `ZBC_BATCH_JOB_CHANGE` | `JobRun` update → `cancelJob` + `scheduleJob` |
| `ZBC_BATCH_JOB_DELETE` | action `cancelJob` (+ delete) |
| `ZBC_BATCH_JOB_STATUS` | action `refreshStatus` — APJ 에서 읽어 메시지로 반환 (DB 저장 안 함) |

`reqid` / `reqname` / `reqdatetime` → RAP 관리 필드 `created_by` / `created_at` 이 대신한다.
요청사유처럼 별도 텍스트가 필요하면 `param` 에 넣거나 컬럼 하나만 추가한다.

---

## 5. APJ 로 못 넘어가는 것

| AS-IS | 처리 | 확인 필요 |
|-------|------|----------|
| **`jobuser` 실행 사용자** | **불가.** 잡은 스케줄한 사용자 컨텍스트로 실행 | AS-IS 에서 잡마다 사용자가 다른가? |
| **`jobclass` A/B/C** | **불가.** APJ 에 개념 없음. 컬럼에 보관만 | 실제로 A/B 를 쓰나? |
| **`pgtype` ≠ PROG** | **모델에서 제외.** 실행 클래스만 지원 | `PROG` 외 값이 쓰이나? |
| 다중 스텝 | **모델에서 제외.** 잡 1개 = 프로그램 1개 | 2스텝 잡을 어떻게 나눌지 |
| `jobname` 지정 | 논리명은 `jobtext`, SM37 이름은 `jobname` 으로 나란히 보관 | — |
| **팩토리 캘린더** | **미구현.** 판정에 쓸 released API 확인 필요 (아래 7절) | 실제로 쓰는 잡이 있나? |
| 기존 배치 리포트 | **클래스로 이관 필요.** `ZIF_BC_JOB_STEP` 구현체로 다시 작성 | 대상 리포트가 몇 개인가? |
| `laststrt` (close 시각) | 런처가 실행 시 판정해 skip | — |
| **타임존** | **APJ 가 기본 제공** — AS-IS 는 직접 변환했음 | — (개선) |

---

## 6. 생성 순서

1. 패키지 1개 — `ZBC_JOB` (ABAP for Cloud Development)
2. `ztjob_run` → `zif_bc_job` → `zcx_bc_job` → `zif_bc_job_step` → `zcl_bc_job_param`
3. 실행 클래스들 (`ZIF_BC_JOB_STEP` 구현) — 기존 배치 리포트 이관분
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
| `zcl_bc_job_runner` | `CREATE OBJECT ... TYPE (name)` 동적 생성이 Cloud 언어버전에서 통과하는지. 막히면 CASE 분기 레지스트리로 대체 |
| `zcl_bc_job_runner` | **팩토리 캘린더 판정용 released API.** 후보: released CDS 뷰 / 없으면 Standard ABAP FM 을 Local API release (순수 Cloud 깨짐) / 요구사항 드롭 |
| `zcl_bc_job_param` | `XCO_CP_JSON` 메서드 체인 (`from_abap`/`to_string`/`from_string`/`write_to`) |
| — | `CL_APJ_RT_API` 에 change/modify 메서드가 있는지 (없으면 change = cancel + 재스케줄) |

기능 비교 자료는 [`../zjob_test/COMPARISON.md`](../zjob_test/COMPARISON.md),
AS-IS 분석은 [`../zjob_test/TO_BE.md`](../zjob_test/TO_BE.md).
