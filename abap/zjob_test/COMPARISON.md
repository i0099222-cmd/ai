# SM36/SM37 vs Application Job — 기능 비교 & 테스트 매트릭스

> 대상: **S/4HANA Private Cloud Edition (PCE)**
> PCE 는 클래식 배치(SM36/SM37)와 Application Job Framework(APJ)가 **둘 다 살아 있는**
> 유일한 구간이다. Public Cloud 는 SM36/37 자체가 없고, 순수 온프렘은 APJ 를 잘 안 쓴다.
> 그래서 "둘을 같은 로직으로 돌려보고 차이를 적는" 이 테스트가 의미가 있다.

---

## 0. 테스트 설계

같은 코어(`ZCL_JOB_TEST_CORE`)를 두 경로로 실행한다.

```
                        ┌──────────────────────────────┐
  Fiori "Application    │  ZCL_APJ_JOB_TEST            │
  Jobs" / OData 서비스 →│  IF_APJ_DT/RT_EXEC_OBJECT    │─┐
                        └──────────────────────────────┘ │   ┌────────────────────┐   Application
                                                          ├──→│ ZCL_JOB_TEST_CORE  │→  Jobs 로그
                        ┌──────────────────────────────┐ │   │  (메시지만 찍는다)  │   SM37 Job log
  SM36 / SM37         →│  ZR_JOB_TEST (Standard ABAP)  │─┘   └────────────────────┘   (+ SM37 Spool)
                        └──────────────────────────────┘
```

잡은 DB 를 안 쓴다. 메시지 한 줄에 실행 컨텍스트를 다 담아서 로그로 보낸다:

```
[TC01-BASE-C] START mode=C user=SAPUSER date=20260904 time=101530 tz=CET job=ZJOBTEST01/12345600 host=s4host01 batch=X
[TC01-BASE-C] #1 at 2026-09-04T10:15:30.123456
[TC01-BASE-C] END written=1/1
```

- `mode=A` = Application Job / `mode=C` = Classic(SM36)
- `job=` `host=` `batch=` 는 **Cloud 언어버전에서 못 읽는 값**이라 `mode=C` 에만 찍힌다
- 비교는 "Application Jobs 앱의 로그" vs "SM37 > Job log" 를 나란히 놓고 본다

---

## 1. SM36/37 에서만 되는 것 (Application Job 미지원/제한)

각 항목은 **직접 확인해서 O/X 를 채우는 용도**다. 릴리스·SP·FPS 에 따라 APJ 쪽이
개선된 항목이 있을 수 있으니, "예상" 열은 가설로 보고 실제 결과를 옆에 적을 것.

| #  | 기능 | SM36/37 | APJ (예상) | 확인 방법 |
|----|------|---------|-----------|-----------|
| 1  | **다중 스텝 잡** (한 잡에 스텝 N개, 순차 실행) | O | X — 실행 오브젝트 1개 | SM36 > Step 에 `ZR_JOB_TEST` 를 2번 등록하고 태그를 다르게. APJ 는 템플릿 1개 = 클래스 1개 |
| 2  | **스텝별 실행 사용자** 지정 | O | X | SM36 Step 화면의 "User" 필드. APJ 는 스케줄한 사용자 컨텍스트로 실행 → 로그의 `user=` 비교 |
| 3  | **외부 커맨드 / 외부 프로그램** 스텝 (SM49/SM69) | O | X | SM36 > Step > External command. APJ 는 ABAP 클래스만 |
| 4  | **잡 클래스(우선순위) A/B/C** | O | X | SM36 > Job class. APJ 스케줄 UI/`CL_APJ_RT_API` 에 대응 파라미터 없음 |
| 5  | **실행 대상 서버 / 서버 그룹** 지정 | O | X | SM36 > Exec. target. 로그의 `host=` 로 실제 실행 서버 비교 |
| 6  | **이벤트 기반 시작** (SM62/SM64, `BP_EVENT_RAISE`) | O | X | SM36 > Start condition > After event. APJ 에 이벤트 개념 없음 |
| 7  | **선행 잡 종료 후 시작** (After job) | O | X | SM36 > Start condition > After job |
| 8  | **오퍼레이션 모드 전환 시 시작** | O | X | SM36 > Start condition > At operation mode |
| 9  | **스풀 리스트 출력** (`WRITE` → SP01) | O | X | `ZR_JOB_TEST` 는 WRITE 로 리스트를 남긴다 → SM37 > Spool. APJ 는 잡 로그만 |
| 10 | **리포트 배리언트** (동적 날짜 배리언트 포함) | O | X — `GET_PARAMETERS` 로 대체 | SE38 에서 배리언트 저장 후 SM36 스텝에 지정. APJ 는 배리언트 개념 자체가 없음 |
| 11 | **코드에서 잡 생성** (`JOB_OPEN`/`JOB_SUBMIT`/`JOB_CLOSE`, `SUBMIT ... VIA JOB`) | O | X — `CL_APJ_RT_API` 로 대체 | ABAP Cloud 언어버전에서 `SUBMIT` 자체가 금지 |
| 12 | **팩토리캘린더 기반 주기** (작업일에만 실행) | O | X / 제한적 | SM36 > Period values > Other period / Restrictions |
| 13 | **타 사용자 잡 조회·관리, 대량 관리** (릴리즈/중지/삭제/복사/반복) | O | 제한적 | SM37 에서 User `*` 로 전체 조회. Application Jobs 앱은 권한 범위 내 |
| 14 | **실행 중 잡 중지 시점** | O (즉시 중단 시도) | ? | `p_sleep=10, p_count=5` 로 돌리고 중간에 취소 → 로그에 `#n` 이 몇 번까지 찍혔는지 비교 |
| 15 | **오류 종료 시 상태 표기** | Canceled | ? | `p_fail='X'` 로 실행 → SM37 상태 vs Application Jobs 앱 상태 문구 비교 |
| 16 | **잡 이름 직접 지정** | O | X — 자동 생성 | SM36 은 Job name 자유 입력. APJ 는 프레임워크가 생성 → SM37 에서 어떤 이름으로 보이는지 확인 |
| 17 | **잡 인터셉션 / 병렬처리 그룹** (SM61, BTCTRNS1/2) | O | X | 운영 통제용. APJ 에 대응 개념 없음 |
| 18 | **스텝 로그 / 런타임 통계 상세** | O | 제한적 | SM37 > Job log, Step list |

## 2. Application Job 쪽이 나은 것 (역방향 비교)

| # | 기능 | APJ | SM36/37 |
|---|------|-----|---------|
| A1 | 업무 담당자용 Fiori UI ("Application Jobs") | O | X (SM36 은 GUI/기술 트랜잭션) |
| A2 | 파라미터 **검증을 코드로** (`CHECK_PARAMETERS`) | O | X — 배리언트 저장 시 업무 검증 불가 |
| A3 | 스케줄 시점 **권한 체크를 코드로** | O | 제한적 (S_BTCH_*) |
| A4 | **사용자 타임존** 기준 스케줄 | O | X — 시스템 타임존 기준 |
| A5 | **ABAP Cloud 언어버전** 호환 → 업그레이드 안정, RAP 과 동일 티어 | O | X — Standard ABAP 필요 |
| A6 | **잡 카탈로그 엔트리 단위 권한** | O | 프로그램/배리언트 단위 |
| A7 | 잡 템플릿 = 재사용 가능한 파라미터 세트 | O | 배리언트로 유사하나 UI 없음 |

## 3. 공통 / 확인 필요

- **APJ 잡도 결국 백그라운드 잡으로 실행된다.** → SM37 에서 조회는 가능할 것으로 예상.
  잡 이름이 무엇으로 보이는지, 로그가 SM37 잡 로그로도 보이는지 **테스트 항목 #16 에서 확인**.
- `sy-batch` / `sy-host` 는 ABAP Cloud 언어버전에서 못 읽는다.
  → `mode=A` 로그에는 `host=`/`batch=` 가 아예 안 찍히고 `mode=C` 에만 찍힌다.
    이 자체가 티어 차이의 증거.
- `MESSAGE ... TYPE 'I'` 가 APJ 잡 로그에 실제로 수집되는지 **먼저 확인**할 것.
  안 되면 애플리케이션 로그(BAL)로 바꿔야 하고, 그것도 비교 결과 중 하나다.

---

## 4. 실행 시나리오

| TC | 태그 | 실행 방법 | 파라미터 | 확인할 것 |
|----|------|----------|---------|----------|
| TC01 | `TC01-BASE-A` | Application Jobs 앱 > 즉시 실행 | count=3 | 로그에 메시지 3건, `user=`, `tz=` |
| TC01 | `TC01-BASE-C` | SM36 > 즉시 시작 | p_count=3 | 위와 동일 항목 비교 |
| TC02 | `TC02-PERIOD-A` | APJ 반복(예: 10분) | count=1 | 실제 반복 간격 (`exec_stamp` 차이) |
| TC02 | `TC02-PERIOD-C` | SM36 주기 10분 | p_count=1 | 위와 비교 |
| TC03 | `TC03-EVENT-C` | SM36 > After event (SM64 로 이벤트 발생) | — | **APJ 에는 대응 없음** 확인 |
| TC04 | `TC04-MULTI-C` | SM36 > 스텝 2개 등록 | — | **APJ 에는 대응 없음** 확인 |
| TC05 | `TC05-CANCEL-A/C` | count=5, sleep=10 후 취소 | — | 로그에 `#n` 이 몇까지 찍혔나 (#14) |
| TC06 | `TC06-FAIL-A/C` | force_fail = X | — | 상태 표기 비교 (#15) |
| TC07 | `TC07-SPOOL-C` | SM36 실행 후 SM37 > Spool | — | **APJ 에는 대응 없음** 확인 (#9) |
| TC08 | `TC08-ODATA-A` | OData `scheduleJob` 액션 | — | API 로 스케줄 가능 범위 (#11 역방향) |

각 TC 후 로그를 캡처해서 태그별로 나란히 붙여둘 것:

- Application Job → "Application Jobs" 앱 > 해당 잡 > Log
- Classic → SM37 > 잡 선택 > Job log (그리고 Spool)

---

## 5. 결론 템플릿 (테스트 후 채울 것)

- SM36/37 로만 가능한 것: #___, #___, ...
- APJ 로 대체 가능하지만 방식이 다른 것: #___
- APJ 가 더 나은 것: A___
- **PCE 에서의 권고**: (예) 업무 담당자가 직접 돌리는 잡은 APJ, 이벤트/다중 스텝/외부 커맨드가
  필요한 기술 잡은 SM36 유지 — 실제 테스트 결과로 확정할 것
