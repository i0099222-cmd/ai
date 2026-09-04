# OData 서비스 — Application Job 기능 테스트

## 서비스 바인딩 생성

ADT: New → Other ABAP Repository Object → `Service Binding`

- Name: `ZUI_JOB_TEST_O4`
- Binding Type: **OData V4 - UI**
- Service Definition: `ZUI_JOB_TEST`

생성 후 **Activate → Publish**. Publish 하면 로컬 서비스 엔드포인트가 잡히고,
`Preview` 버튼으로 Fiori Elements 화면이 바로 뜬다.

노출 엔티티: `JobRun` — 이 서비스로 스케줄한 잡의 이력 + APJ 제어 액션.

잡 자체는 DB 를 안 쓴다. `ZTJOB_RUN` 은 `refreshStatus` / `cancelJob` 을 부르려면
잡 이름·카운트를 들고 있어야 해서 서비스가 기억용으로 쓰는 테이블이다.
**실행 결과는 잡 로그에서 본다** (Application Jobs 앱의 Log / SM37 > Job log).

## 액션 = 테스트 대상 APJ 기능

| 액션 | 내부 호출 | SM37 대응 |
|------|----------|----------|
| `scheduleJob` (static factory) | `CL_APJ_RT_API=>SCHEDULE_JOB` | SM36 잡 생성 |
| `refreshStatus` | `CL_APJ_RT_API=>GET_JOB_STATUS` | SM37 잡 개요 |
| `cancelJob` | `CL_APJ_RT_API=>CANCEL_JOB` | SM37 > Job 중지 |

**이 세 개가 API 로 할 수 있는 전부**라는 점이 그대로 비교 결과가 된다.
SM36 의 이벤트 시작 / 선행 잡 / 대상 서버 / 잡 클래스 / 다중 스텝에는
대응하는 API 파라미터가 없다. (COMPARISON.md #4, #5, #6, #7, #1)

## 호출 예시

베이스 경로는 Publish 후 서비스 바인딩 화면의 URL 을 그대로 쓴다.
(`/sap/opu/odata4/sap/zui_job_test_o4/srvd/sap/zui_job_test/0001/`)

### 1) 즉시 실행 스케줄

```http
POST {base}/JobRun/com.sap.gateway.srvd.zui_job_test.v0001.scheduleJob
Content-Type: application/json
X-CSRF-Token: {token}

{
  "JobTemplateName":   "ZJT_JOB_TEST",
  "RunTag":            "TC08-ODATA-A",
  "MessageCount":      3,
  "SleepSeconds":      0,
  "ForceFail":         false,
  "StartImmediately":  true
}
```

> 액션의 정규화 이름(`com.sap.gateway.srvd...`)은 서비스 메타데이터
> (`{base}$metadata`)에서 확인해서 쓸 것 — 네임스페이스는 바인딩마다 다르다.

### 2) 예약 + 반복 스케줄

```json
{
  "JobTemplateName":   "ZJT_JOB_TEST",
  "RunTag":            "TC02-PERIOD-A",
  "MessageCount":      1,
  "StartImmediately":  false,
  "StartDate":         "2026-09-05",
  "StartTime":         "09:00:00",
  "TimeZone":          "CET",
  "RecurrenceMinutes": 10,
  "EndDate":           "2026-09-06"
}
```

`TimeZone` 은 **APJ 우위 항목**(COMPARISON.md A4). SM36 은 시스템 타임존 기준이다.
여기에 넣은 타임존이 잡 로그의 `tz=` / 실제 실행 시각에 어떻게 반영되는지 확인할 것.

### 3) 상태 폴링

```http
POST {base}/JobRun(RunUuid={uuid})/com.sap.gateway.srvd.zui_job_test.v0001.refreshStatus
```

### 4) 취소

```http
POST {base}/JobRun(RunUuid={uuid})/com.sap.gateway.srvd.zui_job_test.v0001.cancelJob
```

`SleepSeconds=10, MessageCount=5` 로 돌려놓고 취소한 뒤
잡 로그에 `#n` 이 몇 번까지 찍혔는지 확인 → SM37 의 잡 중지와 비교 (#14).

### 5) 스케줄 이력 조회

```http
GET {base}/JobRun?$filter=startswith(RunTag,'TC') &$orderby=ScheduledAt desc
```

`JobName` / `JobCount` 를 확인해서 **SM37 에서 같은 잡이 보이는지** 대조한다 (#16).
실행 결과 자체는 잡 로그에서 본다:

- Application Job → "Application Jobs" 앱 > 해당 잡 > Log
- Classic → SM37 > 잡 선택 > Job log (그리고 Spool)

## 주의

`scheduleJob` 은 액션 핸들러 안에서 `CL_APJ_RT_API` 를 직접 호출한다.
RAP 정석은 외부 시스템 호출을 save 시퀀스(`additional save`)로 미루는 것이지만,
여기서는 "누르면 바로 결과 확인" 이 목적이라 인터랙션 단계에서 호출한다.
운영성 코드로 승격할 때는 saver 로 옮길 것. (`ZBP_I_JOB_RUN` 헤더 주석 참고)
