# ZJOB_TEST — Application Job vs SM36/37 비교 테스트 스캐폴드

S/4HANA **PCE** 환경에서 배치잡 두 방식을 같은 로직으로 돌려보고 차이를 정리하기 위한 뼈대.

- 비교 항목과 테스트 시나리오: **[COMPARISON.md](COMPARISON.md)**
- Application Job 카탈로그/템플릿 생성 절차: **[apj/CATALOG_TEMPLATE.md](apj/CATALOG_TEMPLATE.md)**
- OData 서비스 호출 예시: **[odata/SERVICE_BINDING.md](odata/SERVICE_BINDING.md)**

## 잡이 하는 일

업무 로직은 일부러 없다. 실행될 때 **실행 컨텍스트를 `ZTJOB_PROBE` 에 기록**할 뿐이다.

기록 항목: 실행 사용자 / UTC 타임스탬프 / 시스템 일자·시각 / 사용자 타임존 /
애플리케이션 서버 / 백그라운드 여부 / 잡 이름·카운트 / 스케줄 방식(A|C).

마스터데이터 의존이 0이라 어느 시스템에서도 바로 돌아가고,
비교하고 싶은 것들이 전부 데이터로 남는다.

파라미터:

| 이름 | 의미 |
|------|------|
| `P_TAG` | 테스트 케이스 태그 (프로브 조회 키) |
| `P_COUNT` | 남길 프로브 건수 |
| `P_SLEEP` | 건별 지연(초) — "실행 중" 관찰 / 취소 테스트용 |
| `P_FAIL` | 강제 오류 종료 — 상태 표기 비교용 |

## 오브젝트 구성

```
core/     ZIF_JOB_TEST          공통 타입/상수 (파라미터·상태·모드)
          ZCX_JOB_TEST          테스트 예외 (강제 오류용)
          ZCL_JOB_TEST_CORE     코어 로직 — 양쪽이 공유           [ABAP Cloud]
          ZTJOB_PROBE           프로브 테이블
          ZI_JOB_PROBE          프로브 인터페이스 뷰

apj/      ZCL_APJ_JOB_TEST      Application Job 실행 오브젝트     [ABAP Cloud]
                                IF_APJ_DT_EXEC_OBJECT + IF_APJ_RT_EXEC_OBJECT
          CATALOG_TEMPLATE.md   잡 카탈로그 엔트리 / 템플릿 생성 절차

classic/  ZR_JOB_TEST           SM36/37 용 리포트                 [Standard ABAP]

odata/    ZTJOB_RUN             스케줄 이력 테이블
          ZI_JOB_RUN            인터페이스 뷰 (+ _Probe 연결)
          ZC_JOB_RUN            프로젝션 뷰
          ZC_JOB_PROBE          프로브 프로젝션 뷰
          ZD_JOB_SCHEDULE       scheduleJob 액션 파라미터 (abstract entity)
          ZI_JOB_RUN.bdef       behavior definition (managed)
          ZBP_I_JOB_RUN         behavior implementation — APJ 액션 3종
          ZCL_JOB_APJ_ADAPTER   CL_APJ_RT_API 래퍼
          ZUI_JOB_TEST          service definition
          SERVICE_BINDING.md    서비스 바인딩 + 호출 예시
```

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
2. `core/` → `apj/` → `odata/` → `classic/` 순으로 오브젝트 생성 (의존 순서)
3. `apj/CATALOG_TEMPLATE.md` 대로 잡 카탈로그 엔트리 + 잡 템플릿 생성
4. `odata/SERVICE_BINDING.md` 대로 서비스 바인딩 생성 후 Publish
5. `COMPARISON.md` 의 TC01~TC08 실행

## 미확인 지점 (시스템에서 확인 필요)

이 코드는 시스템에 붙지 않은 상태로 작성했다. **`TODO: 시그니처 확인`** 주석이
붙은 곳은 ADT 에서 F2 로 실제 시그니처를 보고 맞춰야 한다.

| 파일 | 확인할 것 |
|------|----------|
| `apj/ZCL_APJ_JOB_TEST` | `IF_APJ_DT_EXEC_OBJECT~GET_PARAMETERS` / `CHECK_PARAMETERS` 의 파라미터명, `IF_APJ_RT_EXEC_OBJECT~EXECUTE` 의 파라미터명, `CX_APJ_DT_CONTENT` 의 textid |
| `odata/ZCL_JOB_APJ_ADAPTER` | `CL_APJ_RT_API=>TY_START_INFO` 구조 필드명, `SCHEDULE_JOB`/`GET_JOB_STATUS`/`CANCEL_JOB` 시그니처, 상태값 도메인 |
| `core/ZCL_JOB_TEST_CORE` | `WAIT UP TO n SECONDS` 가 Cloud 언어버전에서 통과하는지 |

APJ API 호출은 전부 `ZCL_JOB_APJ_ADAPTER` 한 파일에 격리해뒀으므로,
시그니처가 달라도 그 파일만 고치면 나머지는 그대로 쓸 수 있다.
