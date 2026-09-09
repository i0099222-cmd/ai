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
  param           잡 파라미터 값 (JSON)
  start_datetime  시작 일시   CHAR(15)  (AS-IS 형식 그대로)
  end_datetime    종료 일시   CHAR(15)  (AS-IS 배치잡 close시간)
  timezone        타임존
  prd_*           반복 주기
  jobname     APJ 가 만든 잡 이름 (SM37)   - 끝나도 지우지 않는다
  jobcount    APJ 잡 카운트 (SM37)         - 로그를 찾는 열쇠라서
  is_canceled 취소됨. 비어 있으면 살아 있는 잡
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

### APJ 잡 1개 = 행 1개

이게 이 테이블의 규칙이다. **잡이 끝나도 행을 고치지 않고 `is_canceled` 만 세운다.**
`changeJob` 으로 교체된 잡도 APJ 상으로는 취소이므로 여기 걸린다.

상태를 두 필드로 나눠 본다. 서로 다른 질문이라서다.

| | 묻는 것 | 판정 |
|---|---|---|
| `IsScheduled` | 스케줄이 **성공했나** | `jobname <> ''` |
| `IsCanceled` | 그 잡이 **아직 살아 있나** | 플래그 |

| `IsScheduled` | `IsCanceled` | 뜻 |
|---|---|---|
| `X` | | 살아 있는 잡 |
| `X` | `X` | 끝난 잡 (로그는 계속 조회 가능) |
| | | **스케줄 실패** — 사유는 `message` |

하나로는 세 번째 줄을 표현할 수 없다. 스케줄에 실패한 행은 취소된 것도 아니다.

끝난 **시각**은 `local_last_changed_at` 이 갖는다 — 행을 닫는 것이 그 행의
마지막 갱신이므로 별도 컬럼이 필요 없다.

### 왜 `jobname` 을 지우지 않나

**지우면 그 잡이 남긴 SM37 로그를 다시 찾을 수 없다.** 로그는 `jobname` +
`jobcount` 로 붙는데, 그게 이 행 말고는 어디에도 없다. 취소했다고 비워 버리면
"그 잡이 돌았던 기록" 이 통째로 사라진다 — 조회가 목적인 테이블에서 모순이다.

그래서 취소는 `is_canceled` 를 세울 뿐, 포인터는 그대로 둔다.

### `changeJob` 은 행을 하나 더 만든다

APJ 에 잡 수정 API 가 없어 재스케줄이 **취소 + 재생성**이다. 그 결과 SM37 의
`jobname`/`jobcount` 가 **바뀐다** — 옛 잡과 새 잡은 서로 다른 잡이다.

같은 행을 제자리 갱신하면 옛 `jobname` 이 덮여서 옛 잡의 로그를 잃는다.
그래서 잡이 둘이면 행도 둘이다.

```
changeJob
  ├─ 옛 행:  is_canceled = 'X',  message = "Replaced by ZJT_X_0002/1234"
  └─ 새 행:  jobname  = ZJT_X_0002,  jobcount = 1234   ← 응답은 이 행
```

호출자는 응답에서 **새 `JobName`** 을 받아 자기 쪽 값을 갱신하면 된다.
한 잡의 이력을 따라가려면 `message` 의 `Replaced by` 를 타고 내려가면 된다.

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

## 2-2. APJ 호출은 자식 세션에서 한다

`CL_APJ_RT_API=>CANCEL_JOB` 은 내부에서 **`COMMIT CONNECTION`** 을 한다.
RAP 은 BO 가 활성인 동안 커밋을 금지하므로 덤프가 난다.

```
Execution took place in a transactional context: a BO implementation is
active ZCM_R_BATCH_SCHEDULE. Statement COMMIT CONNECTION is therefore
forbidden.
```

**"BO 활성" 은 save 단계만의 얘기가 아니다.** 액션 핸들러가 도는 동안에도
참이라, 인터랙션 단계로 옮겨도 똑같이 덤프난다. 호출은 BO 밖으로 나가야 한다.

### `save_modified` 는 LUW 를 분리하지 않는다

이름이 헷갈리지만 save 단계는 저장이 *끝난 뒤*가 아니라 **저장하는 중**이다.

```
인터랙션 단계 (버퍼)
  ↓
finalize → check_before_save → save_modified   ← DB 에 쓴다
  ↓
프레임워크가 COMMIT WORK                        ← LUW 는 여기서 끝
```

`save_modified` 는 커밋 **앞**이다. 여기서 커밋하면 BO 변경의 절반만 확정되어
원자성이 깨지므로 막는다. BO 활성 구간은 첫 EML 호출부터 프레임워크 커밋까지
통째로 이어져 있고, 그 안에 LUW 가 갈라지는 지점은 없다.

### 규칙이 두 개라 API 마다 걸리는 곳이 다르다

| | 인터랙션 단계 | save 단계 |
|---|---|---|
| DB 수정 | **금지** | 허용 |
| COMMIT / ROLLBACK | **금지** | **금지** |

`SCHEDULE_JOB` 은 DB 를 쓰기만 하고 커밋하지 않는다. 그래서 인터랙션 단계에서는
막혔고 save 단계에서는 통과했다. `CANCEL_JOB` 은 커밋하므로 두 단계 다 막힌다.

고전 배치 API 도 같다. `JOB_OPEN`/`JOB_SUBMIT`/`JOB_CLOSE` 는 커밋하지 않아
호출자가 커밋해야 잡이 보이고, 잡 취소는 다른 워크프로세스에 알려야 해서
커밋 없이는 성립하지 않는다.

그래서 APJ 호출만 `ZCL_BATCH_APJ_TASK` 에 담아 **`CL_ABAP_PARALLEL` 로 자식
세션**에 넘기고 결과를 기다린다. 자식은 자기 LUW 라 커밋이 합법이다.

```abap
DATA lt_task TYPE cl_abap_parallel=>t_in_inst.
APPEND NEW zcl_batch_apj_task( iv_mode = ... ) TO lt_task.

NEW cl_abap_parallel( )->run_inst( EXPORTING p_in_tab  = lt_task
                                   IMPORTING p_out_tab = DATA(lt_done) ).
```

입력과 출력이 **같은 인스턴스**에 실린다. `RUN_INST` 가 인스턴스를 직렬화해
자식으로 보내고 `DO( )` 가 채운 것을 돌려주기 때문이다. `%cid` 를 같이 실어
두고 그걸로 짝지어서, 결과 순서에 기대지 않는다.

### 덕분에 저장이 평범한 managed 다

결과가 **인터랙션 단계에서** 손에 들어오므로, 액션이 `jobname` 을 엔티티에
써 두면 managed 런타임이 그대로 저장한다.

| | 이전 (unmanaged save) | 지금 |
|---|---|---|
| APJ 호출 위치 | saver (RAP LUW 안) | **자식 세션** |
| 저장 | saver 가 직접 INSERT/UPDATE | **managed 런타임** |
| `CANCEL_JOB` | 덤프 | 정상 |
| 액션 응답의 `JobName` | 없음 | **있다** |
| `cancel_requested` 컬럼 | 필요 | **불필요 — 삭제** |

`cancel_requested` 는 인터랙션 단계에서 save 단계로 "취소해야 함" 을 나르려고
있던 플래그다. 취소가 액션 안에서 끝나므로 사라졌다. saver 클래스도 없다.

**액션 응답에 `JobName` 이 실린다** — AS-IS RFC 가 잡 정보를 동기로 돌려주던
것과 같은 모양이 됐다. 호출자가 한 번 더 GET 할 필요가 없다.

### `changeJob` 은 왕복이 한 번이다

APJ 에 잡 수정 API 가 없어 취소 + 재생성인데, 두 호출을 **한 작업 인스턴스**
(`gc_mode-change`)에 담아 자식 세션에서 이어서 돌린다. 세션 포크가 한 번이다.

### 자식 세션을 안 쓰는 것

`GET_JOB_STATUS` 는 읽기만 하고 커밋하지 않으므로 `refreshStatus` 는 액션에서
직접 부른다. 포크 비용을 낼 이유가 없다.

### 헬퍼 메서드를 두지 않는다

액션 핸들러도 어댑터도 **자기 메서드 안에서 끝난다.** 조회·매핑·변환을 별도
메서드로 빼면 한 호출이 무슨 일을 하는지 보려고 파일을 오르내려야 한다.

어댑터의 공개 메서드 셋(`schedule` / `get_status` / `cancel`)이 곧 APJ 호출
셋이고 그 아래로는 아무것도 없다. `schedule( )` 을 열면 타임존 → 시작 조건 →
반복 주기 → 종료 조건 → 제한 조건 → 파라미터 → 호출이 순서대로 읽힌다.

대가는 반복이다.

- 액션 3곳에 조회 `SELECT` 가 같은 모양으로 들어간다
- `schedule( )` 안에서 CHAR(15) 파싱이 시작/종료 두 번 나온다

읽기 쉬운 쪽을 택한 결과다. 이 반복 때문에 한쪽만 고쳐지는 일이 생기면
그때 다시 보면 된다.

### 확인 필요

- **`CL_ABAP_PARALLEL` 이 이 시스템에서 릴리스돼 있는지**
- `IF_ABAP_PARALLEL~DO` 의 파라미터, `RUN_INST` 의 파라미터명,
  `T_OUT_INST` 의 컴포넌트명(`inst`) — `ZCL_BATCH_APJ_TASK` 와 액션 4곳
### ⚠ 스케줄의 원자성을 잃었다

`SCHEDULE_JOB` 이 커밋하지 않는다는 것은 **우리 LUW 에 합류한다**는 뜻이다.
saver 에 있던 동안에는 스케줄이 이력 행과 원자적이었다 — RAP 이 롤백하면
APJ 잡도 같이 사라졌다.

자식 세션으로 옮기면서 그게 깨졌다. 자식은 자기 LUW 라 즉시 확정되고,
그 뒤 RAP 트랜잭션이 실패하면 **이력 행 없는 APJ 잡이 SM37 에 남는다.**

| | 스케줄 원자성 | `CANCEL_JOB` | 응답의 `JobName` |
|---|---|---|---|
| saver (unmanaged save) | **있음** | 덤프 | 없음 |
| 자식 세션 (지금) | **없음** | 정상 | **있음** |

액션 하나가 트랜잭션 전체라 커밋 실패 경로가 좁긴 하다(권한·저장 실패 정도).
그래도 공짜로 얻은 것은 아니다. 원자성이 더 중요하면 **스케줄만 saver 로
되돌리고 취소만 자식 세션에 두는 하이브리드**로 갈 수 있는데, 그러면
`unmanaged save` 와 "응답에 JobName 없음" 이 같이 돌아온다.

주인 없는 잡은 탐지는 된다 — SM37 잡 중 `ZTBATCH_SCHED` 에 대응 행이 없는 것.

### 확인 필요

---

## 3. 파일

| 파일 | 언어버전 | 내용 |
|------|---------|------|
| `ztbatch_sched.tabl.abap` | — | 테이블 (유일) |
| `zi_batch_schedule.ddls.abap` / `zc_batch_schedule.ddls.abap` | — | interface / projection view |
| `zi_batch_schedule.bdef.abap` / `zc_batch_schedule.bdef.abap` | — | **BDEF + 정적 액션 4종** |
| `zbp_i_batch_schedule.clas.abap` | ABAP Cloud | **정적 액션 4종.** saver 없음 |
| `zcl_batch_apj_task.clas.abap` | ABAP Cloud | 자식 세션에서 도는 APJ 호출 작업 |
| `zd_batch_schedule_in` / `_change_in` / `_cancel_in` / `_status_in` | — | 액션 파라미터 4종 |
| `zcl_batch_apj_adapter.clas.abap` | ABAP Cloud | `CL_APJ_RT_API` 래퍼 |
| `zcx_batch_job.clas.abap` | ABAP Cloud | 실행 클래스가 쓰는 예외 |
| `example_zcl_apj_batch_sample.clas.abap` | ABAP Cloud | **APJ 실행 클래스 작성 예시** (참고용) |
| `zif_batch_job.intf.abap` | ABAP Cloud | 상수/타입 (`gc_status`, `gc_restriction`, `ty_start_option`) |
| `zui_batch_schedule.srvd.abap` | — | service definition |

**전부 ABAP for Cloud Development 다.** Standard ABAP 오브젝트가 하나도 없고,
Local API release 도 필요 없다.

---

## 4. AS-IS 인터페이스 대응

| AS-IS RFC | 액션 |
|-----------|------|
| `ZBC_BATCH_JOB_CREATE` | **`scheduleJob`** |
| `ZBC_BATCH_JOB_CHANGE` | **`changeJob`** |
| `ZBC_BATCH_JOB_DELETE` | **`cancelJob`** — 잡만 끊고 이력은 남긴다 |
| `ZBC_BATCH_JOB_STATUS` | **`refreshStatus`** |

### 왜 CRUD 가 아니라 액션인가

**엔티티는 스케줄 이력이고, CRUD 는 그 이력에 대한 조작이지 APJ 잡에 대한
조작이 아니다.** 둘이 우연히 같이 일어날 뿐이라 하나로 묶으면 어긋난다.

| CRUD 로 노출하면 | 문제 |
|-----------------|------|
| `DELETE` | 잡을 끊으려다 **이력이 사라진다** — 조회가 목적인데 모순 |
| `PATCH` | `message` 한 필드만 고쳐도 **재스케줄된다** |
| `POST` | URL 만 봐서는 "기록 추가" 인지 "잡 생성" 인지 알 수 없다 |

그래서 projection 에서 표준 CRUD 를 노출하지 않는다.
`create`/`update`/`delete` 는 액션 핸들러가 내부적으로만 쓴다.

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

액션의 정규화 이름은 `$metadata` 에서 확인한다 — 네임스페이스는 바인딩마다 다르다.

### 잡 생성

```http
POST {base}/BatchSchedule/com.sap.gateway.srvd.zui_batch_schedule.v0001.scheduleJob
Content-Type: application/json
X-CSRF-Token: {token}

{
  "JobTemplateName":  "ZJT_BATCH_SAMPLE",
  "JobText":          "테스트 잡",
  "StartImmediately": true
}
```

응답으로 만들어진 행이 돌아온다. **여기서 `RunUuid` 를 받아 두는 것이
호출자가 해야 할 일**이다 — 이후 `changeJob` / `cancelJob` / `refreshStatus`
가 전부 이 키로 주소를 잡는다.

```json
{ "RunUuid": "5F3A...C2", "JobName": "", "JobCount": "", "Message": "" }
```

**`JobName` 은 이 응답에서 아직 비어 있다.** APJ 호출이 save 단계에서
일어나는데 액션 응답은 그 전에 만들어지기 때문이다. 스케줄 성공 여부와
SM37 잡 이름은 **행을 한 번 GET** 해서 확인한다.

```http
GET {base}/BatchSchedule(RunUuid={uuid})?$select=IsScheduled,JobName,JobCount,Message
```

AS-IS RFC 는 잡 정보를 동기로 돌려줬으므로 이 지점은 다르다. 다만 호출자가
후속 호출에 쓰던 핸들은 `RunUuid` 로 대체되므로, 기능이 빠지는 것은 아니다.

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
  "StartDateTime":    "20261001020000",
  "EndDateTime":      "20271001020000",
  "TimeZone":         "CET",
  "PeriodMonths":     1
}
```

`PeriodMinutes` / `PeriodHours` / `PeriodDays` / `PeriodWeeks` / `PeriodMonths` 중
**하나만** 채운다.

### 변경 / 취소 / 상태

**네 액션이 전부 정적 액션이다.** 키 없이 엔티티셋에 POST 하고, 어느 잡인지는
`JobName` + `JobCount` 파라미터로 준다.

```http
POST {base}/BatchSchedule/com...v0001.cancelJob
{ "JobName": "ZJT_SAMPLE_0001", "JobCount": "12345600" }

POST {base}/BatchSchedule/com...v0001.refreshStatus
{ "JobName": "ZJT_SAMPLE_0001", "JobCount": "12345600" }

POST {base}/BatchSchedule/com...v0001.changeJob
{ "JobName": "ZJT_SAMPLE_0001", "JobCount": "12345600",
  "StartDateTime": "20261101030000", "PeriodMonths": 1 }
```

`refreshStatus` 는 상태를 `messages` 로 돌려준다. `GET_JOB_STATUS` 가 읽기만
해서 인터랙션 단계에서 부를 수 있기 때문이다.

`cancelJob` 은 잡만 끊는다. **이력 행은 `IsCanceled = 'X'` 로 남는다** —
`JobName` 도 그대로라 그 잡의 SM37 로그를 계속 찾을 수 있다.

### `scheduleJob` 에 `factory` 를 붙이지 않는 이유

`factory` 액션은 **생성된 인스턴스를 `mapped` 로 내보내는 것이 계약**이라
`result` 를 같이 선언할 수 없다 — 활성화가 안 된다.

행 생성은 핸들러의 `MODIFY ... CREATE` 가 하므로 `factory` 없이도 그대로
만들어진다. 그래서 `result [1] $self` 를 택했고, 덕분에 응답을 우리가 직접
구성해 **`RunUuid` 와 `JobName` 을 같이 실어 보낸다.** 네 액션의 모양도 같아진다.

### 왜 전부 정적 액션인가

**외부 호출자는 `RunUuid` 를 모른다.** AS-IS 인터페이스가 `jobid`/`jobcount`
로 잡을 지목하고, 호출하는 쪽은 그 둘을 자기 DB 에 들고 있다. 인스턴스 액션은
키가 URL 에 있어야 하므로 주소를 잡을 방법이 없다.

각 액션이 `jobname` + `jobcount` 로 행을 찾는다. APJ 가 잡마다 다른 이름을
주므로 이 둘이 유일하다. 못 찾으면 그 `%cid` 만 `not_found` 로 실패시키고
나머지 요청은 계속 처리한다.

`changeJob` / `cancelJob` 은 **`is_canceled = abap_false`** 를 같이 건다. 이미 끝난
잡은 못 찾는 것이 맞고, 그래서 인스턴스 피처 컨트롤이 필요 없다 — "잡이 걸려
있을 때만 가능" 이라는 제약이 조회 조건으로 성립한다.

`refreshStatus` 만 그 조건을 빼서, **지나간 잡의 상태도 조회**할 수 있게 뒀다.

### `changeJob` 은 새 행의 잡 이름을 응답으로 준다

재스케줄이 취소 + 재생성이라 `jobname`/`jobcount` 가 바뀐다. 응답이 **새 행**
이므로 호출자는 거기서 새 `JobName` 을 받아 자기 쪽 값을 갱신하면 된다.

옛 잡의 행은 `IsCanceled = 'X'` 로 남아 있고, 그 `message` 에
`Replaced by <새 잡>` 이 적힌다.

### AS-IS 파라미터 중 안 받는 것

| AS-IS | 어디로 | |
|-------|-------|---|
| `reqid`(요청자사번) / `reqname` / `reqdatetime` | **안 받는다** | 확인 필요 — 아래 |
| `reqtype`(작업구분, delete) | **안 받는다** | 확인 필요 — 값 도메인 |
| `sinfo` CHAR(10) (status) | **안 받는다** | 확인 필요 — 용도 |
| `sdate`/`stime`/`edate`/`etime` (status) | **안 받는다** | 아래 |

**요청자 3종.** `CREATED_BY`/`CREATED_AT` 이 대신한다고 적어뒀는데, 그건
**OData 를 호출한 SAP 사용자**다. 외부 시스템이 서비스 사용자로 붙으면 실제
요청자(사번)가 기록되지 않는다. AS-IS 가 굳이 사번을 넘기는 이유가 이것일
가능성이 높다. 필요하면 컬럼 2개(`req_id`/`req_name`)를 되살려야 한다.

**status 의 기간 파라미터.** AS-IS 상태 조회는 잡 이름 + 기간으로 **검색**하는
인터페이스로 보인다 (SM37 선택화면과 같은 모양). 반면 APJ `GET_JOB_STATUS` 는
`jobname` + `jobcount` 로 **한 건**을 읽는다. 기간 검색이 필요하면 이력
테이블을 기간으로 조회한 뒤 건별로 상태를 읽는 방식이라 별도 설계가 필요하다.
`sinfo` CHAR(10) 도 SM37 의 상태 필터(Scheduled/Released/Active/Finished/
Cancelled)일 가능성이 있는데 확인 전에는 매핑하지 않는다.

### 목록 조회

```http
GET {base}/BatchSchedule?$orderby=CreatedAt desc
```

## 4-3. 일시는 AS-IS 형식(CHAR 15) 그대로 받는다

`StartDateTime` / `EndDateTime` 을 **`CHAR(15)`** 로 받는다.
AS-IS `ZBCS0011` 의 형식이라 호출자가 값을 그대로 던질 수 있다.

```json
"StartDateTime": "20261001020000",
"EndDateTime":   "20261231235959"
```

어댑터가 **숫자만 뽑아 앞 8자리를 날짜, 다음 6자리를 시각**으로
읽으므로 구분자가 있든 없든 동작한다.

| 입력 | 해석 |
|------|------|
| `20261001020000` | 2026-10-01 02:00:00 |
| `20261001 020000` | 〃 |
| `2026-10-01 02:00:00` | 〃 |
| `20261001` | 시작이면 2026-10-01 **00:00:00**, 종료면 2026-10-01 **23:59:59** |

### 날짜만 줄 때 시각 기본값이 다른 이유

시작 일시는 "그 날부터" 이므로 `00:00:00`, 종료 일시는 "그 날까지" 이므로
`23:59:59` 가 의도다. 종료를 `00:00:00` 으로 읽으면 `EndDateTime = 20260907`
이 **9월 6일까지**가 되어 하루가 잘린다.

시각까지 채워 보내면(AS-IS 는 그렇게 한다) 이 기본값은 쓰이지 않는다.

타임존은 `TimeZone` 필드로 따로 받고, 없으면 사용자 타임존으로 해석한다.

---

## 4-2. APJ 스케줄 구조

`SCHEDULE_JOB` 은 시작과 반복을 두 구조로 나눠 받는다.

### `TY_START_INFO` — 언제 처음 도나

| 필드 | 내용 |
|------|------|
| `start_immediately` | 즉시 시작 |
| `timestamp` | 최초 시작 시각 (UTC). CHAR(15) 를 파싱해서 넣는다 |

### `TY_SCHEDULING_INFO` — 어떻게 반복하나

| 필드 | 내용 | AS-IS |
|------|------|-------|
| `periodic_granularity` | 주기 **단위** (MINUTE/HOUR/DAY/WEEK/MONTH) | 반복주기(월) / 일반복주기(일) — **둘 중 하나만** |
| `periodic_value` | 주기 **값** (N) | 〃 |
| `timezone` | 반복 계산 기준 타임존 | 시스템 zone시간 |
| `end_info` | 종료 조건 | **배치잡 close시간** |
| `weekday_info` | 요일 지정 | — (SM36 보다 풍부) |
| `month_info` | 월 지정 | — |
| `exception` | 비작업일 처리 | **공장근무일이 여기로 갈 수 있는지 확인 필요** |
| `test_mode` | 테스트 모드 | — |

### `END_INFO` — 언제 멈추나

| `type` | 부가 필드 | 의미 | AS-IS |
|--------|----------|------|-------|
| `NONE` | — | 무한 반복 | (close시간 없음 → **`END_INFO` 를 통째로 비워서 보낸다**) |
| `AFTER` | `max_iterations` | N 회 실행 후 종료 | — **AS-IS 에 없어 쓰지 않는다** |
| `BY` | `timestamp` | 이 시각 이후로는 더 스케줄하지 않는다 | **배치잡 close시간** |

> `BY` 는 **실행 중인 잡을 중단시키지 않는다.** 그 시각을 넘겨 시작된 실행은
> 없지만, 그 전에 시작된 실행은 끝까지 돈다. SM36 의 `laststrtdt/tm`
> (최종 시작 시각)과 같은 의미라 AS-IS 와 어긋나지 않는다.

> AS-IS 의 `laststrt`(close시간)가 APJ 에 대응이 있다. 초기 판정에서
> "대응 없음" 으로 적었던 것을 정정한다.
>
> 어댑터는 close시간이 없을 때 `TYPE = 'NONE'` 을 명시하지 않고 `END_INFO`
> 를 초기값 그대로 둔다. 값 도메인이 미확인이라 검증되지 않은 리터럴을
> 하나 줄인 것이다. API 가 `TYPE` 을 필수로 검증하면 첫 무기한 반복 테스트
> 에서 바로 에러가 나므로, 그때 확인된 상수를 넣으면 된다.

### AS-IS 가 채우는 SM36 "제한 조건" 필드 — 확인됨

`ZBC_BATCH_JOB_CREATE` 의 BDC 가 채우는 것으로 확인된 필드다.
전부 SM36 반복 잡의 **제한 조건(Restrictions) 팝업** 필드고, 한 세트로 움직인다.

| BDC 필드 | 의미 | 확인 |
|---------|------|------|
| `PRDMONTHS` | 월 주기 | **확인됨** — ZBCS0011 반복주기 |
| `PRDDAYS` | 일 주기 | 추정 — ZBCS0011 일반복주기 |
| `CALENDARID` | **공장달력 ID** | **확인됨** |
| `BOFMONTH` | 매월 **1일** 실행 | **확인됨** |
| `EOFMONTH` | 매월 **말일** 실행 | **확인됨** |
| `EXECUTE_BEFORE` | 비근무일이면 **이전** 근무일로 당김 | **확인됨** |

`BOFMONTH`/`EOFMONTH` 가 따로 있는 이유는 **"말일"을 날짜로 표현할 수 없어서**다.
2월 28일 / 4월 30일 / 3월 31일이라 시작일의 일자를 반복하는 방식으로는 안 된다.

즉 AS-IS 는 **"매월 말일, 단 휴무일이면 앞당겨서"** 같은 조건을 건다.
월마감 배치의 전형적인 요구사항이라 안 쓰는 잡이 없을 가능성이 높다.

### APJ 대응 — 확인됨, 거의 전부 넘어간다

`TY_SCHEDULING_INFO` 안에 두 구조가 있다.

```
EXCEPTION  { calendar_id, start_restriction_code }
MONTH_INFO { day, use_working_days_ind, shift_direction, week_number }
```

### AS-IS 로직 — 확인됨

```abap
IF ls_info-공장시간 IS NOT INITIAL.        " 공장시간 = 공장달력 ID
  calendarid = 공장시간.
  wdayno     = 공장근무일수.
  sdlstrttm  = 공장근무시간.

  IF ls_info-실행관련시간 IS NOT INITIAL.
    bofmonth = 'X'.                       " 월초부터 센다
  ELSE.
    eofmonth = 'X'.                       " 월말부터 센다
  ENDIF.
ENDIF.
```

읽어야 할 것 세 가지.

1. **`공장시간` 은 시간이 아니라 공장달력 ID 다.** 이게 게이트고, 비어 있으면
   제한 조건 전체를 걸지 않는다.
2. **`BOFMONTH`/`EOFMONTH` 는 "월초/말일에 실행" 이 아니다.** `WDAYNO` 와 한
   세트로 도는 **세는 방향**이다. `WDAYNO = 3` + `EOFMONTH` = "말일에서 3번째
   작업일". 그래서 실행일은 매월 달라진다.
3. **`실행관련시간`(`excutbefore`) 은 시각이 아니라 방향 스위치다.** 값이 있으면
   월초 기준, 없으면 월말 기준. 비근무일 회피와는 무관하다.

| AS-IS | APJ | 판정 |
|-------|-----|------|
| `공장시간` 공장달력 | `exception-calendar_id` | **○ 이관** |
| `공장근무일수` → `WDAYNO` | `month_info-day` + `use_working_days_ind` | **○ 이관** |
| `실행관련시간` → `BOFMONTH`/`EOFMONTH` | `month_info-shift_direction` | **○ 이관** (의미 확인 필요) |
| `공장근무시간` → `SDLSTRTTM` | `StartDateTime` 의 **시각부** | **○ 이관** — 별도 필드 불필요 |
| — | `exception-start_restriction_code` | **AS-IS 미사용.** APJ 기능이라 열어만 둠 |
| — | `month_info-week_number` | AS-IS 에 대응 없음, 안 씀 |

**공장달력 3종이 전부 "APJ 못 함" 목록에서 빠진다.** 월말 우회책도 필요 없다 —
애초에 "말일 실행" 이 아니었다.

### `START_RESTRICTION_CODE` — 값 도메인 확인됨

| 값 | 의미 |
|----|------|
| `D` | 실행하지 않고 건너뛴다 (do not process) |
| `B` | 이전 근무일로 당긴다 (before) |
| `A` | 다음 근무일로 미룬다 (after holiday) |
| `N` | 제한 없이 그날 실행한다 (no) |

**4지선다지 플래그가 아니다.** 그래서 `StartRestriction` 을 `CHAR(1)` 로 받는다
(상수는 `ZIF_BATCH_JOB=>GC_RESTRICTION`). `abap_boolean` 으로는 `D`(건너뜀)와
`N`(제한없음)을 표현할 수 없다.

**AS-IS 는 이 값을 채우지 않는다.** BDC 로직에 대응 코드가 없어 SM36 기본 동작을
따른다. 그래도 필드를 여는 이유는 APJ 가 지원하는 기능이고, 이관 후 "휴일이면
건너뛴다" 같은 요구가 나오면 바로 쓸 수 있어서다.

### 어느 필드가 어느 구조로 가나

두 구조의 역할이 겹치지 않는다.

| | 답하는 질문 |
|---|---|
| `EXCEPTION` | 실행일이 **비근무일이면 어떻게 할지** |
| `MONTH_INFO` | 실행일을 **어떻게 고를지** (며칠째를, 어느 쪽에서부터) |

```abap
IF is_start-month_day > 0.
  rs_sched-month_info-day                  = is_start-month_day.
  rs_sched-month_info-use_working_days_ind = is_start-use_working_days.
  rs_sched-month_info-shift_direction      =
    COND #( WHEN is_start-count_from_end = abap_true
            THEN gc_restriction-before      " 월말에서 역순
            ELSE gc_restriction-after ).    " 월초에서 순서
ENDIF.
```

> **확인 필요:** `SHIFT_DIRECTION` 이 정말 **세는 방향**인가.
> 비근무일 회피 방향이라면 `EXCEPTION` 과 역할이 겹치므로 그럴 이유가 없지만,
> 확인은 필요하다. 월말 기준으로 걸고 SM37 에서 실행 예정일을 보면 판정된다.

### `WEEKDAY_INFO` / `WEEK_NUMBER` 는 받지 않는다

APJ 가 지원하지만 **AS-IS 가 안 쓴다.** 기준은 하나다 — AS-IS 에 대응이 없는
파라미터는 열지 않는다.

주 단위 반복은 이미 표현된다. `PeriodWeeks = 1` + 시작일이 화요일 = 매주 화요일.
SM36 도 같은 방식으로, **시작일이 요일을 결정한다.** `WEEKDAY_INFO` 가 실제로
필요한 것은 "매주 화요일과 목요일" 처럼 한 잡에 요일을 여럿 지정할 때인데,
SM36 으로도 안 되고 AS-IS 에도 없다. `WEEK_NUMBER` 와 조합한
"매월 둘째 주 화요일" 도 마찬가지다.

안 쓰는 파라미터를 여는 것은 중립이 아니다. 열면 호출자가 값을 보내고, 우리는
테스트한 적 없는 조합을 받는다. 반대로 나중에 추가하는 것은 비파괴적이라
기존 호출자가 깨지지 않는다 — 필요해지면 그때 넣는다.

### AS-IS 로직과의 차이 3가지

AS-IS 는 **공장시간(달력) 하나가 블록 전체를 여는 게이트**다.

```
IF 공장시간 <> ''.
  calendar / workday / time 을 넣고
  실행관련시간 유무로 BOFMONTH 또는 EOFMONTH
  workperiod
ENDIF.
```

**① 게이트가 우리는 둘로 나뉜다.** `calendar_id` 와 `month_day` 가 각각
`IF` 라, 달력 없이 `MonthDay` + `UseWorkingDays` 만 올 수 있다 — AS-IS 는
만들지 않는 조합이고, 기준 없이 작업일을 세면 APJ 가 기본 달력으로 조용히
돌아 요청과 다른 날에 걸린다. **어댑터가 이 조합을 실패시킨다.**

**② `use_working_days` 가 AS-IS 에는 없다.** 공장시간이 있으면 **항상**
작업일 기준이라 플래그가 따로 없다. AS-IS 데이터를 이관할 때 이 값은 언제나
`'X'` 여야 한다 — 이관 스크립트 쪽 주의사항이다.

**③ `workperiod` 도 `PRDMONTHS` 로 간다 — 확인됨.** `반복주기`와 **같은 BDC
필드**다. 즉 AS-IS 에서도 이미 하나의 슬롯이었고, 달력을 쓰느냐에 따라 어느
입력이 그 자리를 채우는지만 다르다.

그래서 APJ 쪽도 `periodic_value` + `granularity = MONTH` 하나로 충분하다.
**`PeriodMonths` 가 둘을 다 받는다 — 새 파라미터가 필요 없다.**

이관 규칙:

```
PeriodMonths = 공장시간 있으면 workperiod, 없으면 반복주기
```

> **주의:** AS-IS 는 달력 블록에서 `PRDMONTHS` 를 **덮어쓴다.** 공장시간이
> 있는데 `workperiod` 가 비어 있으면 앞서 넣은 `반복주기`가 0 으로 지워져
> 월 주기가 사라진다. 달력을 쓰는 잡에 `workperiod` 가 항상 채워져 있는지
> 운영 데이터로 확인해 둘 것 — 비어 있는 행이 있으면 그 잡들은 이관 시
> 주기를 다시 정해야 한다.

### 나머지 확인 필요

- **`SHIFT_DIRECTION` 의 값** — 의미는 확인됐다. 필드 설명이
  *"count direction for on workday start date of a job"* 이므로 **작업일 기준
  시작일을 어느 쪽에서 세는지**가 맞고, `EXCEPTION` 과 역할이 겹치지 않는다.
  타입은 **NUMC(2)** 이고 `START_RESTRICTION_CODE`(D/B/A/N)와 다른 도메인이다.
  **도메인 고정값이 없어 값은 확인할 곳이 없다** — `01`(월초부터) /
  `02`(월말부터)는 NUMC 열거의 관례를 따른 추측이라, 월초 기준으로 걸어
  SM37 실행일이 맞는지로 판정해야 한다 (`ZIF_BATCH_JOB=>GC_SHIFT`)
- `PERIODIC_GRANULARITY` 의 값 도메인 (상수 클래스가 있는지)
- `END_INFO` 가 `TY_SCHEDULING_INFO` 의 컴포넌트인지 별도 파라미터인지,
  `TYPE` 의 실제 값 (`NONE` / `AFTER` / `BY`)
- `WEEKDAY_INFO` 의 구조

---

## 5. APJ 로 못 넘어가는 것

| AS-IS | 처리 | 확인 필요 |
|-------|------|----------|
| **`jobuser` 실행 사용자** | **불가.** 잡은 스케줄한 사용자 컨텍스트로 실행 | AS-IS 에서 잡마다 사용자가 다른가? |
| **`jobclass` A/B/C** | **불가.** APJ 에 개념 없음. 컬럼에 보관만 | 실제로 A/B 를 쓰나? |
| **`pgtype` ≠ PROG** | **모델에서 제외.** 실행 클래스만 지원 | `PROG` 외 값이 쓰이나? |
| 다중 스텝 | **모델에서 제외.** 잡 1개 = 프로그램 1개 | 2스텝 잡을 어떻게 나눌지 |
| `jobname` 지정 | 논리명은 `jobtext`, SM37 이름은 `jobname` 으로 나란히 보관 | — |
| ~~팩토리 캘린더~~ (공장달력 3종) | **해결.** `EXCEPTION` + `MONTH_INFO` 로 전부 이관 | ○ |
| **합산 주기** (`PRDMONTHS` + `PRDDAYS` 동시) | **불가.** APJ 는 단위 1개 + 값 1개뿐. 어댑터가 실패시킨다 | 동시에 채운 잡이 실제로 있나? |
| ~~close 시각~~ (`laststrt`) | **해결.** `END_INFO` type `BY` 로 이관 | ○ |
| **요청자** (`reqid`/`reqname`) | **안 받는다.** `created_by` 는 OData 를 부른 서비스 사용자라 실제 요청자 사번이 안 남는다 | 요청자 추적을 쓰나? |
| 기존 배치 리포트 | **클래스로 이관 필요.** 배치마다 실행 클래스 + 카탈로그 + 템플릿 | 대상 리포트가 몇 개인가? |
| **타임존** | `TY_SCHEDULING_INFO-TIMEZONE` 으로 넘긴다 | ○ |

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

| AS-IS | BDC 필드 | `ty_start_option` | APJ `periodic_granularity` |
|-------|---------|-------------------|---------------------------|
| **반복주기** | `PRDMONTHS` (확인됨) | `prd_months` | `MONTH` |
| **일반복주기** | `PRDDAYS` (추정) | `prd_days` | `DAY` |
| — | `PRDMINS` / `PRDHOURS` / `PRDWEEKS` | `prd_mins` / `prd_hours` / `prd_weeks` | `MINUTE` / `HOUR` / `WEEK` |

AS-IS 는 **월과 일 두 단위만** 쓴다. 나머지 세 컬럼은 APJ 가 지원해서 열어둔 것이고
AS-IS 호출자는 채우지 않는다.

### 합산 주기는 표현할 수 없다 — **APJ 못 함 항목**

SM36 은 `PRDMONTHS`/`PRDDAYS`/… 를 **동시에 채우면 그 합을 주기로 삼는다.**
1개월 + 15일 = 45일 주기다.

APJ 의 `TY_SCHEDULING_INFO` 는 `periodic_granularity` + `periodic_value`
**한 쌍뿐**이라 단위를 하나만 고를 수 있다. 합산을 표현할 방법이 없다.

그래서 어댑터는 **둘 이상 채워지면 스케줄하지 않고 실패시킨다.** 조용히 하나를
고르면 요청과 다른 주기로 잡이 걸린다.

```
반복 주기는 한 단위만 지정할 수 있다.
APJ 는 합산 주기를 표현하지 못한다: DAY 15 + MONTH 1
```

> AS-IS 운영 데이터에 **반복주기와 일반복주기가 동시에 채워진 잡이 있는지**
> 확인이 필요하다. 있으면 그 잡들은 이관 시 주기를 하나로 정리해야 한다.

---

기능 비교 자료는 [`../zjob_test/COMPARISON.md`](../zjob_test/COMPARISON.md),
AS-IS 분석은 [`../zjob_test/TO_BE.md`](../zjob_test/TO_BE.md).
