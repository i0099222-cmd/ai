# ZJOB_TEST — Application Job vs SM36/37 비교 테스트 스캐폴드

S/4HANA **PCE** 환경에서 배치잡 두 방식을 같은 로직으로 돌려보고 차이를 정리하기 위한 뼈대.

- 비교 항목과 테스트 시나리오: **[COMPARISON.md](COMPARISON.md)**
- Application Job 카탈로그/템플릿 생성 절차: **[apj/CATALOG_TEMPLATE.md](apj/CATALOG_TEMPLATE.md)**
- OData 서비스 호출 예시: **[odata/SERVICE_BINDING.md](odata/SERVICE_BINDING.md)**

## 잡이 하는 일

업무 로직은 일부러 없다. **잡 로그에 메시지를 찍는 게 전부**다.
DB 도, 마스터데이터도 건드리지 않으니 어느 시스템에서도 바로 돌아간다.

메시지에 실행 컨텍스트를 담아서, 비교하고 싶은 게 로그에 그대로 남게 했다:

```
[TC01-BASE-C] START mode=C user=SAPUSER date=20260904 time=101530 tz=CET job=ZJOBTEST01/12345600 host=s4host01 batch=X
[TC01-BASE-C] #1 at 2026-09-04T10:15:30.123456
[TC01-BASE-C] #2 at 2026-09-04T10:15:40.234567
[TC01-BASE-C] END written=2/2
```

`mode=A`(Application Job) 로그와 `mode=C`(SM36) 로그를 나란히 놓고 보면
실행 사용자 / 타임존 / 서버 / 잡 이름이 어떻게 다른지 바로 보인다.
`job=` `host=` `batch=` 는 Cloud 언어버전에서 못 읽는 값이라 **`mode=C` 에만 찍힌다** —
그 자체가 티어 차이의 증거다.

파라미터:

| 이름 | 의미 |
|------|------|
| `P_TAG` | 테스트 케이스 태그 (로그 검색 키) |
| `P_COUNT` | 찍을 메시지 건수 |
| `P_SLEEP` | 메시지 간 지연(초) — "실행 중" 관찰 / 취소 테스트용 |
| `P_FAIL` | 강제 오류 종료 — 상태 표기 비교용 |

## 오브젝트 구성

```
core/     ZIF_JOB_TEST          공통 타입/상수 (파라미터·상태·모드)
          ZCX_JOB_TEST          테스트 예외 (강제 오류용)
          ZCL_JOB_TEST_CORE     코어 — 양쪽이 공유. 메시지만 찍는다  [ABAP Cloud]

apj/      ZCL_APJ_JOB_TEST      Application Job 실행 오브젝트         [ABAP Cloud]
                                IF_APJ_DT_EXEC_OBJECT + IF_APJ_RT_EXEC_OBJECT
          CATALOG_TEMPLATE.md   잡 카탈로그 엔트리 / 템플릿 생성 절차

classic/  ZR_JOB_TEST           SM36/37 용 리포트                     [Standard ABAP]

```

> 이 디렉토리는 **SM36/37 과 APJ 를 비교하는 테스트 전용**이다.
> 실제 컨버전 산출물은 [`../zbc_job/`](../zbc_job/) 에 있다.

## 언어버전 배치 (PCE 3-tier)

| 오브젝트 | 언어버전 | 이유 |
|----------|---------|------|
| `ZCL_JOB_TEST_CORE`, `ZCL_APJ_JOB_TEST`, RAP/OData 일체 | **ABAP for Cloud Development** | APJ 와 RAP 은 Cloud 티어가 정석 |
| `ZR_JOB_TEST` | **Standard ABAP** | `WRITE`(스풀), 배리언트, `sy-batch`/`sy-host` 가 Cloud 에서 금지 |

`Standard ABAP → ABAP Cloud` 방향 호출은 허용되므로, 클래식 리포트가 Cloud 코어를
그대로 부르면 된다. (반대 방향이면 Local API release 가 필요하다 —
기존 `ZCL_PARKED_DOC_POSTER` → `Z_FI_PARKED_DOC_POST_BDC` 케이스가 그 예)

## 생성 순서

1. 패키지 2개
   - `ZJOB_TEST` (ABAP for Cloud Development)
   - `ZJOB_TEST_CLASSIC` (Standard ABAP) — `ZR_JOB_TEST` 만 들어간다
2. `core/` → `apj/` → `classic/` 순으로 오브젝트 생성 (의존 순서)
3. `apj/CATALOG_TEMPLATE.md` 대로 잡 카탈로그 엔트리 + 잡 템플릿 생성
4. `COMPARISON.md` 의 TC01~TC08 실행

## 미확인 지점 (시스템에서 확인 필요)

이 코드는 시스템에 붙지 않은 상태로 작성했다. **`TODO: 시그니처 확인`** 주석이
붙은 곳은 ADT 에서 F2 로 실제 시그니처를 보고 맞춰야 한다.

| 파일 | 확인할 것 |
|------|----------|
| `apj/ZCL_APJ_JOB_TEST` | `IF_APJ_DT_EXEC_OBJECT~GET_PARAMETERS` / `CHECK_PARAMETERS` 의 파라미터명, `IF_APJ_RT_EXEC_OBJECT~EXECUTE` 의 파라미터명, `CX_APJ_DT_CONTENT` 의 textid |
| `odata/ZCL_JOB_APJ_ADAPTER` | `CL_APJ_RT_API=>TY_START_INFO` 구조 필드명, `SCHEDULE_JOB`/`GET_JOB_STATUS`/`CANCEL_JOB` 시그니처, 상태값 도메인 |
| `core/ZCL_JOB_TEST_CORE` | `WAIT UP TO n SECONDS` 가 Cloud 언어버전에서 통과하는지 / `MESSAGE ... TYPE 'I'` 가 APJ 잡 로그에 실제로 수집되는지 |

APJ API 호출은 전부 `ZCL_JOB_APJ_ADAPTER` 한 파일에 격리해뒀으므로,
시그니처가 달라도 그 파일만 고치면 나머지는 그대로 쓸 수 있다.

> `MESSAGE ... TYPE 'I'` 는 백그라운드에서만 로그로 간다.
> `ZR_JOB_TEST` 를 SE38 에서 F8 로 돌리면 메시지마다 팝업이 뜬다 —
> 비교 테스트는 어차피 배치로 돌리는 게 목적이니 SM36 으로 실행할 것.
