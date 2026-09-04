# Application Job 카탈로그 엔트리 / 템플릿 생성

## 구조

```
Job Catalog Entry (ZJC_JOB_TEST)          "이 클래스를 잡으로 돌릴 수 있다"
        │  └─ Execution Class: ZCL_APJ_JOB_TEST
        ▼
Job Template (ZJT_JOB_TEST)               "이 파라미터 세트로 돌린다"
        │  └─ Catalog Entry: ZJC_JOB_TEST
        ▼
Job (런타임)                               "언제/얼마나 자주 돌린다"
        └─ Fiori "Application Jobs" 앱 또는 CL_APJ_RT_API=>SCHEDULE_JOB
```

SM36 과 대응시키면:

| APJ | SM36/37 |
|-----|---------|
| Job Catalog Entry | (대응 없음 — 아무 리포트나 스텝에 넣을 수 있음) |
| Job Template | 리포트 + 배리언트 |
| Job | SM36 으로 만든 잡 |
| Application Jobs 앱 | SM37 |

카탈로그 엔트리라는 **화이트리스트 계층이 하나 더 있다는 것**이 APJ 의 구조적 차이다.
SM36 은 실행 권한만 있으면 아무 리포트나 스케줄할 수 있다.

## 1) Job Catalog Entry

ADT: 패키지 우클릭 → New → Other ABAP Repository Object →
`Application Job Catalog Entry`

- Name: `ZJC_JOB_TEST`
- Description: `배치잡 비교 테스트`
- Execution Class: `ZCL_APJ_JOB_TEST`
- (선택) Authorization Object / Package 지정

> 저장 시 실행 클래스가 `IF_APJ_DT_EXEC_OBJECT` + `IF_APJ_RT_EXEC_OBJECT` 를
> 구현하고 있는지 검사한다. 검사에 걸리면 인터페이스 구현부터 확인할 것.

## 2) Job Template

ADT: New → Other ABAP Repository Object → `Application Job Template`

- Name: `ZJT_JOB_TEST`
- Job Catalog Entry: `ZJC_JOB_TEST`

템플릿을 열면 `GET_PARAMETERS` 의 `et_parameter_def` 대로 파라미터 화면이 뜨고,
`et_parameter_val` 이 기본값으로 채워져 있다. 여기서 값을 바꾸면
`CHECK_PARAMETERS` 가 호출된다 → **SM36 배리언트에는 없는 검증 계층**.

## 3) 스케줄

### Fiori 앱
"Application Jobs" 앱 → New → Job Template 선택 → 파라미터/스케줄 입력 → Schedule

### 코드 (OData 서비스 경유)
`odata/SERVICE_BINDING.md` 의 `scheduleJob` 액션 참고.

## 4) 확인

- 스케줄된 잡이 **SM37 에도 보이는지** 확인 (COMPARISON.md #16)
  - 잡 이름이 무엇으로 생성되는지 기록할 것
  - `ZTJOB_PROBE-job_name` 이 비어 있는지 (APJ 런타임에서 잡 이름을 못 읽는 경우)
- 잡 로그: Application Jobs 앱의 로그 vs SM37 > Job log 내용 비교 (#18)
- `EXECUTE` 안의 `MESSAGE ... TYPE 'I'` 가 어느 로그에 남는지 확인
