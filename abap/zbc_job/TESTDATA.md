# 테스트 데이터

전부 `scheduleJob` 페이로드다. `JobTemplateName` 은 실제 잡 템플릿으로 바꿀 것.

```http
POST {base}/BatchSchedule/com.sap.gateway.srvd.zui_batch_schedule.v0001.scheduleJob
Content-Type: application/json
X-CSRF-Token: {token}
```

**기대 실행일은 2026년 10월 기준**이고, 공장달력이 주말만 제외한다고 가정한 값이다.
공휴일이 더 들어 있으면 그만큼 밀린다.

```
10월  1(목) 2(금) [3토 4일] 5(월) 6 7 8 9 ... 30(금) [31토]
작업일  1     2            3     4 5 6 7 ...  22
```

---

## 1. 기본 동작

### T01 즉시 실행

```json
{ "JobTemplateName": "ZJT_BATCH_SAMPLE", "JobText": "T01 즉시",
  "StartImmediately": true }
```
→ 바로 실행. 응답의 `JobName` 으로 SM37 대조.

### T02 예약 1회

```json
{ "JobTemplateName": "ZJT_BATCH_SAMPLE", "JobText": "T02 예약",
  "StartDateTime": "20261005020000" }
```
→ **10/5 02:00** 1회. 반복 없음.

### T03 매월 같은 날짜

```json
{ "JobTemplateName": "ZJT_BATCH_SAMPLE", "JobText": "T03 매월15일",
  "StartDateTime": "20261015090000", "PeriodMonths": 1 }
```
→ **매월 15일 09:00.** 달력을 안 쓰므로 휴일이어도 그대로 돈다.

---

## 2. 공장달력

### T04 날짜 지정 + 휴일이면 앞당김

```json
{ "JobTemplateName": "ZJT_BATCH_SAMPLE", "JobText": "T04 매월3일 앞당김",
  "StartDateTime": "20261003090000", "PeriodMonths": 1,
  "CalendarId": "01", "MonthDay": 3, "StartRestriction": "B" }
```
→ 10/3 은 **토요일**이므로 앞당겨 **10/2(금)**.
`StartRestriction` 을 `"A"` 로 바꾸면 **10/5(월)**, `"D"` 면 **이번 달은 안 돎**.

**달력은 있지만 작업일 카운트는 안 하는 조합**이다. `UseWorkingDays` 가 없다.

### T05 n번째 작업일

```json
{ "JobTemplateName": "ZJT_BATCH_SAMPLE", "JobText": "T05 3번째작업일",
  "StartDateTime": "20261001020000", "PeriodMonths": 1,
  "CalendarId": "01", "MonthDay": 3, "UseWorkingDays": true }
```
→ **10/5.** 1(목)=1, 2(금)=2, 3·4 주말 건너뜀, 5(월)=**3**

### T06 말일에서 n번째 작업일

```json
{ "JobTemplateName": "ZJT_BATCH_SAMPLE", "JobText": "T06 말일에서3번째",
  "StartDateTime": "20261001020000", "PeriodMonths": 1,
  "CalendarId": "01", "MonthDay": 3,
  "UseWorkingDays": true, "CountFromMonthEnd": true }
```
→ **10/28.** 30(금)=1, 29(목)=2, 28(수)=**3**

### T07 말일 (마지막 작업일)

```json
{ "JobTemplateName": "ZJT_BATCH_SAMPLE", "JobText": "T07 말일",
  "StartDateTime": "20261001020000", "PeriodMonths": 1,
  "CalendarId": "01", "MonthDay": 1,
  "UseWorkingDays": true, "CountFromMonthEnd": true }
```
→ **10/30(금).** 31일이 토요일이라 마지막 **작업일**은 30일이다.

> **T05/T06 이 `SHIFT_DIRECTION` 값(01/02)을 검증하는 케이스다.**
> T05 가 10/28 로, T06 이 10/5 로 나오면 두 값이 반대다 —
> `ZIF_BATCH_JOB=>GC_SHIFT` 의 두 줄을 바꾸면 된다.

---

## 3. 종료 조건 · 타임존

### T08 종료일시

```json
{ "JobTemplateName": "ZJT_BATCH_SAMPLE", "JobText": "T08 종료있음",
  "StartDateTime": "20261001020000", "PeriodMonths": 1,
  "EndDateTime": "20270331" }
```
→ **2027/3/31 23:59:59 까지만** 새 회차를 건다. 날짜만 주면 그 날 끝으로 본다.

### T09 타임존

```json
{ "JobTemplateName": "ZJT_BATCH_SAMPLE", "JobText": "T09 KOREA",
  "StartDateTime": "20261005020000", "TimeZone": "KOREA" }
```
→ SM37 에 **02:00**. `"TimeZone": "UTC"` 로 바꾸면 같은 값이 **11:00** 으로 뜬다
(SM37 은 사용자 타임존으로 표시). 이 둘의 차이가 안 나면 타임존 변환이 안 되고
있는 것이다.

---

## 4. 거부되어야 하는 것

응답의 `IsScheduled` 가 비고 `Message` 에 사유가 적혀야 한다. **SM37 에 잡이
생기면 안 된다.**

### T10 달력 없이 작업일 카운트

```json
{ "JobTemplateName": "ZJT_BATCH_SAMPLE", "JobText": "T10 달력없음",
  "StartDateTime": "20261001020000", "PeriodMonths": 1,
  "MonthDay": 3, "UseWorkingDays": true }
```
→ `작업일 기준으로 세려면 공장달력(CalendarId)이 필요하다.`

### T11 주기 두 단위

```json
{ "JobTemplateName": "ZJT_BATCH_SAMPLE", "JobText": "T11 합산주기",
  "StartDateTime": "20261001020000",
  "PeriodMonths": 1, "PeriodDays": 15 }
```
→ `반복 주기는 한 단위만 지정할 수 있다. ... DAY 15 + MONTH 1`

---

## 4-1. 중복 실행 방지 (잠금)

우리 API 로 **같은 시각에 2건**을 걸어 겹치게 만든다.

### 준비 - 실행 클래스에 시간을 태운다

배치가 순식간에 끝나면 몇 건을 걸어도 안 겹친다.
`ZCL_APJ_BATCH_SAMPLE` 에 자리를 잡아뒀으니 **주석만 풀면 된다.**

```abap
*   잠금 테스트용 지연. 테스트할 때만 주석을 푼다 (TESTDATA.md 4-1).
    DO 50000000 TIMES.
    ENDDO.
```

한 번 돌려보고 **3분쯤 걸리게** 횟수를 맞춘다. 짧으면 안 겹치고, 길면 기다린다.
테스트가 끝나면 다시 주석 처리한다.

### 거는 방법 - 같은 예약 시각으로 2건

즉시실행 2번보다 확실하다. 호출 사이 시간차가 없어 **둘이 같은 순간에 릴리스**된다.
지금부터 5분쯤 뒤로 잡으면 SM12 를 열어놓고 기다릴 여유도 생긴다.

```json
{ "JobTemplateName": "ZJT_BATCH_SAMPLE", "JobText": "락1",
  "StartDateTime": "20260910143000" }

{ "JobTemplateName": "ZJT_BATCH_SAMPLE", "JobText": "락2",
  "StartDateTime": "20260910143000" }
```

### 기대 결과

**SM37 에 잡 2건, 둘 다 `Finished`.** 두 번째가 실패가 아니라 **건너뛴 것**이라서다.
로그가 갈린다.

| | 잡 로그 |
|---|---|
| 먼저 잡은 쪽 | `잠금 BATCH_SAMPLE 획득=X` → `처리 시작` → `처리 건수 …` |
| 나중 | `잠금 BATCH_SAMPLE 획득=` → **`이미 실행 중이라 건너뜁니다`** |

배치가 도는 동안 **SM12** 에 `EZBATCH_LOCK` 이 보여야 한다.

### 안 되면 - 원인 가르기

**먼저 두 잡의 실제 시작 시각을 본다.** 차이가 나면 잠금 문제가 아니다.

| 관찰 | 원인 |
|------|------|
| 시작 시각이 **다름** | 안 겹쳤다. 지연을 늘리거나 배치 워크프로세스 여유 확인 |
| 둘 다 `획득=X` | 잠금이 안 걸린다. SM12 에 잠금이 보이는지 확인 |
| 잡이 **오류 종료** | 잠금 오브젝트 이름·활성화 확인. 이름이 맞으면 `acquire` 의 CATCH 절 |
| 로그가 아예 없음 | 실행 클래스가 안 불렸다. 카탈로그·템플릿 연결 확인 |

배치 워크프로세스가 1개뿐이면 잡이 직렬화되어 **잠금과 무관하게** 안 겹친다.
그 경우 테스트가 아무것도 증명하지 못한다.

---

## 5. 후속 액션

`scheduleJob` 응답의 `JobName` / `JobCount` 로 부른다.

```json
// 상태 조회
POST .../refreshStatus
{ "JobName": "...", "JobCount": "..." }

// 취소 - 행은 남고 IsCanceled 가 'X' 가 된다
POST .../cancelJob
{ "JobName": "...", "JobCount": "..." }

// 변경 - 옛 행이 닫히고 새 행이 생긴다. 응답의 JobName 이 바뀐다
POST .../changeJob
{ "JobName": "...", "JobCount": "...",
  "StartDateTime": "20261101030000", "PeriodMonths": 2 }
```

**`changeJob` 확인 포인트:** 응답의 `JobName` 이 요청과 **달라야** 한다.
옛 행은 `IsCanceled = 'X'`, `Message = "Replaced by ..."` 로 남는다.

```http
GET {base}/BatchSchedule?$filter=IsCanceled eq ''&$orderby=CreatedAt desc
```

---

## 확인 순서

| | 무엇 | 막히면 |
|---|---|---|
| 1 | T01 | `CL_ABAP_PARALLEL` / `RUN_INST` 시그니처 |
| 2 | T02, T03 | 타임스탬프 변환 |
| 3 | T05, T06 | **`SHIFT_DIRECTION` 값(01/02)** |
| 4 | T04 | `START_RESTRICTION_CODE` 값 |
| 5 | T08 | `END_INFO-TYPE` 값 |
| 6 | T10, T11 | 가드 동작 |
