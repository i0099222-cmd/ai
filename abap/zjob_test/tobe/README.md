# TO-BE — BDC 제거판 배치잡 스케줄러

AS-IS `ZBC_BATCH_JOB_CREATE` / `_DELETE` / `_STATUS` 의 **BDC(`CALL TRANSACTION 'SM36'`)를
표준 FM으로 대체**한 구현 뼈대. 기능은 하나도 잃지 않으면서 화면 의존을 없앤다.

판정 근거는 [../TO_BE.md](../TO_BE.md), 기능 비교는 [../COMPARISON.md](../COMPARISON.md) 참고.

## 파일

| 파일 | 언어버전 | 내용 |
|------|---------|------|
| `zif_bc_job.intf.abap` | ABAP Cloud | 헤더/스텝/결과 타입 + 상태 상수 |
| `z_bc_job_schedule.abap` | **Standard ABAP** | `JOB_OPEN` → `JOB_SUBMIT`(n회) → `JOB_CLOSE` |
| `z_bc_job_delete.abap` | **Standard ABAP** | `BP_JOB_DELETE` |
| `z_bc_job_status.abap` | **Standard ABAP** | TBTCO/TBTCP 조회 |
| `zcl_bc_job_scheduler.clas.abap` | ABAP Cloud | RAP 액션이 부르는 진입점 + 사전 검증 |

`JOB_*` FM 은 ABAP Cloud 언어버전에서 호출 불가라 Standard ABAP 패키지에 두고
**SE37 > Goto > API State > Use in Cloud Development (Local API)** 로 release 해야 한다.
기존 `ZCL_PARKED_DOC_POSTER` → `Z_FI_PARKED_DOC_POST_BDC` 와 같은 패턴이다.

## AS-IS 필드 → 표준 FM 매핑

### ZBCS0011 (헤더)

| AS-IS | 표준 FM | 파라미터 |
|-------|---------|---------|
| 배치잡 명 | `JOB_OPEN` | `JOBNAME` |
| 배치잡 클래스 | `JOB_OPEN` | `JOBCLASS` |
| 업무구분 | `JOB_OPEN` | `JOBGROUP` |
| 배치유저명 | `JOB_SUBMIT` | `AUTHCKNAM` 기본값 |
| 배치잡 시작시간 | `JOB_CLOSE` | `SDLSTRTDT` / `SDLSTRTTM` |
| 배치잡 close시간 | `JOB_CLOSE` | `LASTSTRTDT` / `LASTSTRTTM` |
| 반복주기 / 일반복주기 | `JOB_CLOSE` | `PRDMINS` / `PRDHOURS` / `PRDDAYS` / `PRDWEEKS` / `PRDMONTHS` |
| 공장시간 | `JOB_CLOSE` | `CALENDAR_ID` |
| 공장근무일수 | `JOB_CLOSE` | `START_ON_WORKDAY_NR`, `WORKDAY_COUNT_DIRECTION` |
| 공장근무시간 | `JOB_CLOSE` | `START_ON_WORKDAY_NOT_BEFORE` |
| **시스템 / 클라이언트** | — | 표준 대응 없음. RFC destination 선택용으로 추정 |
| **시스템 zone시간** | — | 표준 대응 없음. 호출 전 타임존 변환 |
| **요청사유** | — | 표준 대응 없음. 로그 테이블 컬럼으로 |

### ZBCS0012 (스텝, `lt_pg`)

| AS-IS | `JOB_SUBMIT` 파라미터 |
|-------|---------------------|
| `pgid` | `REPORT` |
| `pgvariant` | `VARIANT` |
| `jobuser` | `AUTHCKNAM` |
| `pglang` | `LANGUAGE` |
| `pgtype` | `REPORT` / `COMMANDNAME` / `EXTPGM_NAME` 분기 |

스텝 수만큼 `JOB_SUBMIT` 을 반복 호출한다.

## 표준 대응이 없는 3개

AS-IS 인터페이스가 SAP 잡 개념 위에 **추가로 얹은 필드**라 표준 FM 에 자리가 없다.
TO-BE 에서도 그대로 유지하되 처리 위치만 정해두면 된다.

| 필드 | TO-BE 처리 |
|------|-----------|
| **시스템 / 클라이언트** | 타 시스템 대상이면 `CALL FUNCTION ... DESTINATION` 으로 호출. destination 선택은 `ZCL_BC_JOB_SCHEDULER` 책임. 자기 시스템 전용이면 검증용으로만 사용 |
| **시스템 zone시간** | `Z_BC_JOB_SCHEDULE` 안에서 요청 타임존 → 시스템 타임존 변환 후 `SDLSTRTDT`/`SDLSTRTTM` 에 넣음. **Application Job 은 이 변환을 프레임워크가 해준다 (COMPARISON A4)** |
| **요청사유** + `reqid`/`reqname`/`reqdatetime` | `ZTJOB_RUN` 에 컬럼 추가해서 보관 |

## RAP/OData 연결

`../odata/` 의 RAP 계층을 그대로 쓰되 액션 내부만 바꾼다.

| RAP action | 호출 |
|-----------|------|
| `scheduleJob` | `ZCL_BC_JOB_SCHEDULER->schedule( )` |
| `deleteJob` | `ZCL_BC_JOB_SCHEDULER->delete( )` |
| `refreshStatus` | `ZCL_BC_JOB_SCHEDULER->get_status( )` |

`ZTJOB_RUN` 에 추가할 컬럼: `req_id`, `req_name`, `req_datetime`, `req_reason`,
`sys_id`, `client`, `biz_area`.

```
AS-IS:  화면 → Spring → (PI?) → RFC → BDC → SM36 화면
TO-BE:  화면 → OData V4 → RAP action → ZCL_BC_JOB_SCHEDULER
                                        → Z_BC_JOB_* (Standard ABAP)
                                        → JOB_OPEN / JOB_SUBMIT / JOB_CLOSE
```

## 미확인 지점

`TODO: 시그니처 확인` 주석이 붙은 곳은 SE37 에서 실제 파라미터/예외명을 보고 맞춰야 한다.

| 파일 | 확인할 것 |
|------|----------|
| `z_bc_job_schedule.abap` | `JOB_OPEN` / `JOB_SUBMIT` / `JOB_CLOSE` 파라미터·예외명, `GET_SYSTEM_TIMEZONE` 시그니처 |
| `z_bc_job_delete.abap` | `BP_JOB_DELETE` 예외 목록. jobcount 없이 잡명만으로 삭제하는 게 AS-IS 동작인지 |
| `z_bc_job_status.abap` | 반환용 딕셔너리 구조 `ZBC_JOB_STATUS` 생성 필요. TBTCO 필드명(`reaxserver` 등) 확인 |
| `zif_bc_job.intf.abap` | AS-IS 필드 길이/타입에 맞춰 조정 |

## 아직 확인 안 된 AS-IS 항목

- `ZBCS0011` 의 **"시스템"** 이 (a) 대상 SAP 시스템 SID 인지 (b) `TARGETSERVER`(실행 서버)인지
- `ZBCS0011` 의 **"실행관련시간"** 이 어떤 값인지 (`JOB_CLOSE` 대응 미정)
- **change 인터페이스**의 시그니처 (`BP_JOB_MODIFY` 로 갈지, delete + 재생성으로 갈지)
