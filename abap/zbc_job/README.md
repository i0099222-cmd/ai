# ZBC_JOB — 배치잡 인터페이스 Application Job 컨버전

AS-IS `ZBC_BATCH_JOB_CREATE` / `_CHANGE` / `_DELETE` / `_STATUS` (BDC on SM36) 를
**Application Job Framework** 로 옮긴 것.

---

## 1. 데이터 모델 — 테이블 1개, 컬럼 10개

이 테이블은 **스케줄 등록부**다. 실행 상태와 로그는 갖지 않는다 — 별도 로그 기능 담당.

```
ZTBATCH_SCHED
  run_uuid    RAP 키
  template    APJ 잡 템플릿
  jobtext     잡 텍스트 (논리 잡명)
  param       잡 파라미터 값 (JSON)
  jobname     APJ 가 만든 잡 이름 (SM37)
  jobcount    APJ 잡 카운트 (SM37)
  message     APJ 응답 메시지
  created_by  누가 걸었나
  created_at  언제 걸었나
  local_last_changed_at   etag
```

### 필드를 3종류로 나눈 결과

| 종류 | 예 | 어디에 |
|------|-----|--------|
| APJ 가 이미 갖고 있는 것 | 시작일시, 반복주기, 타임존 | **저장 안 함.** 액션 파라미터로만 받아 APJ 에 넘김 |
| 잡 파라미터 값 | 리포트 배리언트를 대신 | **`param` 에 JSON 배열** |
| 실행 상태 / 이력 | 상태, 실행 메시지 | **저장 안 함.** 별도 로그 기능 |
| 포인터 | template, jobname, jobcount | DB 컬럼 |

### 상태 컬럼이 없어도 되는 이유

**`jobname` 유무가 곧 스케줄 여부다.**

| `jobname` | 의미 | 활성 액션 |
|-----------|------|----------|
| 차 있음 | 스케줄됨 | `changeJob`, `cancelJob`, `refreshStatus` |
| 비어 있음 | 취소된 행 | 없음 — 다시 걸려면 `createJob` 으로 새로 만든다 |

`cancelJob` 은 취소 후 `jobname`/`jobcount` 를 비운다 → 같은 행을 다시 스케줄할 수 있다.
실제 실행 상태(Running / Finished / Aborted)는 `refreshStatus` 가 APJ 에서 읽어
**메시지로만** 돌려준다. DB 에 쓰지 않는다.

### 런처는 DB 에 아무것도 안 쓴다

`ZCL_BATCH_RUNNER` 는 읽고 → 판정하고 → 실행하고 → 결과를 반환만 한다.
`COMMIT WORK` 도 없다. 실행 흔적은 잡 로그(`MESSAGE`)로만 남고,
그 로그는 별도 로그 기능이 수집한다.

### 왜 `jobcount` 가 필요한가

APJ 잡의 키는 **`jobname + jobcount`** 다.
`jobcount` 없이는 `GET_JOB_STATUS` / `CANCEL_JOB` 을 호출할 수 없다.

### `param` 에 들어가는 것

실행 클래스가 `GET_PARAMETERS` 로 정의한 파라미터의 **값**들이다.
**리포트 배리언트를 대신하는 자리**다.

**`SCHEDULE_JOB` 의 `IT_JOB_PARAMETER_VALUE` 타입을 그대로 직렬화한 것**이다.
그래서 스케줄할 때 역직렬화 한 줄이면 끝이고, 변환 로직이 없다.

```json
[
  { "name": "P_MODU",
    "t_value": [ { "sign": "I", "option": "EQ", "low": "SD" } ] },
  { "name": "P_DATS",
    "t_value": [ { "sign": "I", "option": "BT",
                   "low": "20260101", "high": "20261231" } ] }
]
```

`t_value` 가 range 테이블이라 select-option 도 그대로 표현된다.

```abap
DATA lt_param TYPE cl_apj_rt_api=>tt_job_parameter_value.
/ui2/cl_json=>deserialize( EXPORTING json = iv_param
                           CHANGING  data = lt_param ).
```

호출자도 같은 타입을 `/UI2/CL_JSON` 으로 직렬화해서 보내면 된다 —
기존 배치 인터페이스 코드가 이미 그렇게 하고 있다.

`name` 은 실행 클래스의 `SELNAME` 과 일치해야 하고, 값 검증은 그 클래스의
`CHECK_PARAMETERS` 가 한다.

> API 로 직접 테스트할 때는 `Parameters` 가 string 필드라 JSON 안의 따옴표를
> 이스케이프해야 한다:
> `"Parameters": "[{\"name\":\"P_MODU\",\"t_value\":[{\"sign\":\"I\",\"option\":\"EQ\",\"low\":\"SD\"}]}]"`

---

## 2. 실행 대상은 잡 템플릿이 결정한다

APJ 의 실행 경로는 이렇다.

```
잡 템플릿  ──▶  잡 카탈로그 엔트리  ──▶  실행 클래스
ZJT_XXX          ZJC_XXX                 ZCL_APJ_XXX
                                          ├ IF_APJ_DT_EXEC_OBJECT  (파라미터 정의/검증)
                                          └ IF_APJ_RT_EXEC_OBJECT  (EXECUTE)
```

**`template` 하나면 무엇을 실행할지가 정해진다.** 별도의 실행 클래스 컬럼이 없는 이유다.

배치 하나 = **실행 클래스 1개 + 카탈로그 엔트리 1개 + 잡 템플릿 1개.**
런처도, 동적 생성도, Standard ABAP 도 없다. APJ 가 클래스를 직접 실행한다.

### 기존 배치 리포트 이관

| 리포트 | 실행 클래스 |
|--------|------------|
| `START-OF-SELECTION` 로직 | `IF_APJ_RT_EXEC_OBJECT~EXECUTE` |
| 셀렉션 스크린 파라미터 | `IF_APJ_DT_EXEC_OBJECT~GET_PARAMETERS` |
| 배리언트 | 잡 템플릿 (파라미터 값 세트) |
| 값 검증 | `CHECK_PARAMETERS` — **SM36 배리언트에는 없는 계층** |
| `WRITE` 리스트 | `MESSAGE` → 잡 로그 |
| 실패 | `RAISE EXCEPTION` → 잡 오류 종료 |

`example_zcl_apj_batch_sample.clas.abap` 이 그 형태의 예시다.

### 왜 런처를 쓰지 않는가

초기에는 "무엇이든 실행하는" 런처 클래스 하나로 카탈로그를 1개만 두는 안을 검토했다.
AS-IS 가 리포트 이름(`pgmid`)을 파라미터로 받아 아무거나 스케줄하기 때문이다.

실행 대상을 클래스로 바꾸는 순간 그 전제가 사라진다.
클래스는 미리 만들어져 있어야 하므로 **유한한 목록**이고, 그러면 각각을 카탈로그에
등록하는 것이 가능하다. 런처는 APJ 의 카탈로그 화이트리스트(보안 통제)를 우회하는
구조여서, 피할 수 있으면 피하는 것이 맞다.

대가는 **배치 종류마다 카탈로그 엔트리와 템플릿을 만들어야 한다**는 것이다.
어차피 실행 클래스를 새로 만드는 마당이라 큰 부담은 아니다.

---

## 2-2. LUW 분리 — APJ 호출은 saver 에서

`CL_APJ_RT_API` 는 **RAP 인터랙션 단계에서 호출할 수 없다.**
RAP 이 LUW 를 소유하는데 이 API 가 트랜잭션을 건드려서 덤프가 난다.

그래서 behavior 에 `with additional save` 를 걸고, APJ 호출은
`LSC_ZI_BATCH_SCHEDULE~SAVE_MODIFIED` 에서만 한다.

**시작 조건이 전부 엔티티 필드라 `create` / `update` 를 그대로 읽으면 되고,
인터랙션 → save 로 값을 넘기는 버퍼가 필요 없다.**

```abap
METHOD save_modified.

  LOOP AT delete INTO DATA(ls_del).       " 삭제 -> 잡 취소
    cancel_current( ls_del-runuuid ).
  ENDLOOP.

  lt_target = create.                     " 생성
  LOOP AT update INTO DATA(ls_upd).       " 변경 -> 취소 후 재스케줄
    cancel_current( ls_upd-runuuid ).
    APPEND CORRESPONDING #( ls_upd ) TO lt_target.
  ENDLOOP.

  LOOP AT lt_target INTO DATA(ls_row).
    ls_sched = lo_adapter->schedule( ... ls_row ... ).
    UPDATE ztbatch_sched SET jobname/jobcount/message WHERE run_uuid = ...
  ENDLOOP.

ENDMETHOD.
```

### 대가 — 에러를 응답으로 못 준다

save 단계에서는 `reported` 로 메시지를 돌려줄 수 없다. 그래서:

- APJ 응답은 **`ZTBATCH_SCHED-MESSAGE`** 에 기록한다
- 스케줄 실패 시 **`jobname` 이 빈 채로 남는다** (`IsScheduled = ''`)

호출자는 `IsScheduled` / `Message` 로 성공 여부를 판단한다.

### `refreshStatus` 는 예외

`GET_JOB_STATUS` 는 읽기만 하므로 인터랙션 단계에 남겨뒀다.
`reported` 로 상태를 바로 돌려줄 수 있다.

### 확인 필요

- `update` / `delete` 시 기존 `jobname` 을 `SELECT` 로 읽는다.
  managed 프레임워크의 저장 순서에 따라 `delete` 시점에 행이 이미
  지워졌을 수 있다 — 실제로 취소가 걸리는지 확인할 것.
- `PATCH` 로 재스케줄할 때는 **스케줄 관련 필드를 모두 보내야 한다.**
  `update` 테이블에는 요청에 담긴 필드만 온다.
- `SCHEDULE_JOB` 이 내부에서 `COMMIT WORK` 를 하면 save 단계에서도 막힌다.
  그 경우 bgPF 로 RAP 커밋 이후 별도 LUW 에서 실행하거나, 스케줄 호출을
  BO 밖으로 빼야 한다.

---

## 3. 파일

| 파일 | 언어버전 | 내용 |
|------|---------|------|
| `ztbatch_sched.tabl.abap` | — | 테이블 (유일, 10 컬럼) |
| `zi_batch_schedule.ddls.abap` / `zc_batch_schedule.ddls.abap` | — | interface / projection view |
| `zi_batch_schedule.bdef.abap` / `zc_batch_schedule.bdef.abap` | — | **BDEF + 액션 3종 + 저장 검증** |
| `zbp_i_batch_schedule.clas.abap` | ABAP Cloud | refreshStatus + **saver** (APJ 호출) |
| `zcl_batch_apj_adapter.clas.abap` | ABAP Cloud | `CL_APJ_RT_API` 래퍼 |
| `zcx_batch_job.clas.abap` | ABAP Cloud | 실행 클래스가 쓰는 예외 |
| `example_zcl_apj_batch_sample.clas.abap` | ABAP Cloud | **APJ 실행 클래스 작성 예시** (참고용) |
| `zif_batch_job.intf.abap` | ABAP Cloud | 상수/타입 (`ty_param`, `ty_start_option`) |
| `zui_batch_schedule.srvd.abap` | — | service definition |

**전부 ABAP for Cloud Development 다.** Standard ABAP 오브젝트가 하나도 없고,
Local API release 도 필요 없다.

---

## 4. AS-IS 인터페이스 대응

| AS-IS RFC | OData |
|-----------|-------|
| `ZBC_BATCH_JOB_CREATE` | **`POST /BatchSchedule`** → `SCHEDULE_JOB` |
| `ZBC_BATCH_JOB_CHANGE` | **`PATCH /BatchSchedule(...)`** → `CANCEL_JOB` + `SCHEDULE_JOB` |
| `ZBC_BATCH_JOB_DELETE` | **`DELETE /BatchSchedule(...)`** → `CANCEL_JOB` |
| `ZBC_BATCH_JOB_STATUS` | `POST .../refreshStatus` |

**표준 CRUD 가 곧 AS-IS 인터페이스다.** 별도 액션을 만들지 않았다 —
스케줄에 필요한 값이 전부 엔티티 필드라서 `create`/`update`/`delete` 만으로
`save_modified` 가 할 일을 알 수 있다.

### 잡 생성 = 스케줄 등록

SAP 에서 이 둘은 별개가 아니다. SM36 도 `JOB_OPEN` → `JOB_SUBMIT` → `JOB_CLOSE`
가 끝나면 그게 곧 스케줄된 잡이고, APJ 는 아예 `SCHEDULE_JOB` 하나뿐이다.

그래서 `createJob` 한 번이 두 가지를 만든다:

| | 무엇 | 성격 |
|---|------|------|
| 1 | **DB 등록부 행 1건** | SAP 개념이 아니라 이 서비스가 관리하려고 두는 것. AS-IS 도 자체 테이블에 template/jobtext/param 을 남겼다 |
| 2 | **APJ 잡 1건** | 이것이 진짜 "잡 생성" |

1번은 부수효과지 별도 단계가 아니다.

### 표준 create / update 를 노출하지 않는 이유

`POST` / `PATCH` 를 열어두면 **스케줄이 걸리지 않은 반쪽 행**이 생긴다.
잡 생성은 `createJob`, 변경은 `changeJob` 으로만 한다.

`DELETE` 는 열어둔다 — 등록부 행 정리용이며 APJ 잡과 무관하다.
APJ 잡을 없애는 것은 `cancelJob` 이다.

### `changeJob` 은 취소 + 재생성이다

**APJ 에 잡 수정 API 가 없다.** 그래서 기존 잡을 취소하고 새 조건으로 다시 건다.
그 결과 **SM37 의 `jobname`/`jobcount` 가 바뀐다.** SM36 은 제자리 변경이 되므로,
화면 쪽에서 잡 ID 를 들고 있다면 영향이 있다 — 확인 필요.

---

## 4-1. API 테스트

서비스 바인딩(OData V4 - UI) Publish 후 엔드포인트는 대략 이렇다.

```
/sap/opu/odata4/sap/zui_batch_schedule/srvd/sap/zui_batch_schedule/0001/
```

### 잡 생성 = `POST`

```http
POST {base}/BatchSchedule
Content-Type: application/json
X-CSRF-Token: {token}

{
  "JobTemplateName":  "ZJT_BATCH_SAMPLE",
  "JobText":          "테스트 잡",
  "StartImmediately": true
}
```

응답의 **`IsScheduled`** 와 **`Message`** 로 성공 여부를 본다.
`JobName` / `JobCount` 가 채워졌으면 SM37 에서 대조한다.

### 파라미터 넣기

`Parameters` 가 string 필드라 JSON 안의 따옴표를 이스케이프해야 한다.

```json
  "Parameters": "[{\"name\":\"P_BUKRS\",\"t_value\":[{\"sign\":\"I\",\"option\":\"EQ\",\"low\":\"1000\"}]}]",
```

### 예약 + 반복

```json
{
  "JobTemplateName":  "ZJT_BATCH_SAMPLE",
  "JobText":          "월마감 배치",
  "StartImmediately": false,
  "StartDate":        "2026-10-01",
  "StartTime":        "02:00:00",
  "TimeZone":         "CET",
  "PeriodMonths":     1
}
```

`PeriodMinutes` / `PeriodHours` / `PeriodDays` / `PeriodWeeks` / `PeriodMonths` 중
**하나만** 채운다.

### 변경 / 삭제 / 상태

```http
PATCH  {base}/BatchSchedule(RunUuid={uuid})    → 취소 + 재스케줄
DELETE {base}/BatchSchedule(RunUuid={uuid})    → 잡 취소 + 행 삭제
POST   {base}/BatchSchedule(RunUuid={uuid})/com...v0001.refreshStatus
```

`PATCH` 로 재스케줄할 때는 **스케줄 관련 필드를 모두 보내야 한다** —
`update` 테이블에는 요청에 담긴 필드만 오기 때문이다.

### 목록 조회

```http
GET {base}/BatchSchedule?$orderby=CreatedAt desc
```

## 5. APJ 로 못 넘어가는 것

| AS-IS | 처리 | 확인 필요 |
|-------|------|----------|
| **`jobuser` 실행 사용자** | **불가.** 잡은 스케줄한 사용자 컨텍스트로 실행 | AS-IS 에서 잡마다 사용자가 다른가? |
| **`jobclass` A/B/C** | **불가.** APJ 에 개념 없음. 컬럼에 보관만 | 실제로 A/B 를 쓰나? |
| **`pgtype` ≠ PROG** | **모델에서 제외.** 실행 클래스만 지원 | `PROG` 외 값이 쓰이나? |
| 다중 스텝 | **모델에서 제외.** 잡 1개 = 프로그램 1개 | 2스텝 잡을 어떻게 나눌지 |
| `jobname` 지정 | 논리명은 `jobtext`, SM37 이름은 `jobname` 으로 나란히 보관 | — |
| **팩토리 캘린더** | APJ 반복 패턴에 대응 없음. 필요하면 실행 클래스가 `EXECUTE` 안에서 직접 판정 | 실제로 쓰는 잡이 있나? |
| **close 시각** (`laststrt`) | 위와 동일 | 실제로 쓰나? |
| 기존 배치 리포트 | **클래스로 이관 필요.** 배치마다 실행 클래스 + 카탈로그 + 템플릿 | 대상 리포트가 몇 개인가? |
| `laststrt` (close 시각) | 런처가 실행 시 판정해 skip | — |
| **타임존** | **APJ 가 기본 제공** — AS-IS 는 직접 변환했음 | — (개선) |

---

## 6. 생성 순서

1. 패키지 1개 — `ZBC_JOB` (ABAP for Cloud Development)
2. `ztbatch_sched` → `zif_batch_job` → `zcx_batch_job`
3. **배치별로** 실행 클래스(`IF_APJ_DT/RT_EXEC_OBJECT` 구현) → 잡 카탈로그 엔트리 → 잡 템플릿
   — 기존 배치 리포트 이관분
4. `zcl_batch_apj_adapter`
5. CDS(interface → projection) → BDEF → `zbp_i_batch_schedule`
6. Service Definition `ZUI_BATCH_SCHEDULE` → Service Binding (OData V4 - UI) → Publish

---

## 7. 미확인 지점

`TODO: 시그니처 확인` 주석 위치:

| 파일 | 확인할 것 |
|------|----------|
| `zcl_batch_apj_adapter` | **반복 주기** — `TY_PERIOD_INFO` 의 구성 필드명, `SCHEDULE_JOB` 의 파라미터명이 `IS_PERIOD_INFO` 인지 (아래) |
| `zcl_batch_apj_adapter` | `SCHEDULE_JOB`/`GET_JOB_STATUS`/`CANCEL_JOB` 시그니처, 상태값 도메인 |
| `example_zcl_apj_batch_sample` | `IF_APJ_DT_EXEC_OBJECT~GET_PARAMETERS`/`CHECK_PARAMETERS`, `IF_APJ_RT_EXEC_OBJECT~EXECUTE` 시그니처, `CX_APJ_DT_CONTENT` textid |
| — | 팩토리 캘린더 판정이 필요하면 Cloud 에서 쓸 수 있는 released API 확인 |
| — | `CL_APJ_RT_API` 에 change/modify 메서드가 있는지 (없으면 change = cancel + 재스케줄) |

### 반복 주기 — 부분 확인됨

`CL_APJ_RT_API=>TY_START_INFO` 에 반복 관련 필드가 없고, 대신
**`TY_PERIOD_INFO`** 가 별도 타입으로 존재한다는 것까지 확인됐다.
→ 반복 주기가 `SCHEDULE_JOB` 의 **별도 파라미터**로 빠져 있다고 보고 구성했다.

`ZCL_BATCH_APJ_ADAPTER->build_period_info` 가 그 변환을 담당한다.

아직 확인이 필요한 두 가지:

| # | 확인할 것 | 틀렸을 때 조치 |
|---|----------|---------------|
| 1 | `TY_PERIOD_INFO` 의 **구성 필드명** — `min` / `hour` / `day` / `week` / `month` 로 가정 | `build_period_info` 의 5줄만 수정 |
| 2 | `SCHEDULE_JOB` 의 **파라미터명이 `IS_PERIOD_INFO`** 인지 | 호출부 한 줄 수정. `TY_START_INFO` 안에 중첩된 필드라면 그 줄을 지우고 `ls_start_info-<필드> = ls_period_info` 로 |

두 경우 모두 이 파일 안에서만 고치면 된다.

AS-IS 매핑:

| AS-IS | `ty_start_option` | `TY_PERIOD_INFO` (가정) |
|-------|-------------------|------------------------|
| 반복주기 (분/시/주/월) | `prd_mins` / `prd_hours` / `prd_weeks` / `prd_months` | `min` / `hour` / `week` / `month` |
| 일반복주기 | `prd_days` | `day` |

주기는 **한 단위만** 채운다 (`ELSEIF` 로 배타 처리). 여러 개를 채우면 APJ 가 거부할 수 있다.

---

기능 비교 자료는 [`../zjob_test/COMPARISON.md`](../zjob_test/COMPARISON.md),
AS-IS 분석은 [`../zjob_test/TO_BE.md`](../zjob_test/TO_BE.md).
