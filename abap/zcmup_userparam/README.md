# 사용자 파라미터 (SU3) API · 초안

포털(HCP)에서 SU3 화면을 대신 쓰기 위한 **OData V4 Web API**입니다.
웹이 화면을 그리고, SAP는 아래 3가지를 제공합니다.

| # | 웹 화면 동작 | API | 내부 처리 |
| --- | --- | --- | --- |
| ① | 화면 열기 → default 값 채우기 | `GET UserSetting` | `BAPI_USER_GET_DETAIL` |
| ② | 검색 버튼 → 팝업 목록 | `GET ParamValueHelp(p_itemid='BUK')/Set` | 마스터 조회 (항목별) |
| ③ | 저장 | `PATCH UserSetting(...)` | 병합 → `BAPI_USER_CHANGE` |

- 환경: S/4HANA Cloud Private Edition
- API 계층은 **ABAP for Cloud Development**, BAPI·미공개 테이블은 **Tier 2 래퍼**(classic)로만 접근

## 흐름

```
웹 ──① GET UserSetting ─────────────▶ zcl_cmup_q_usersetting ─▶ 래퍼 get_settings ─▶ BAPI_USER_GET_DETAIL
웹 ──② GET ParamValueHelp('BUK') ───▶ zcl_cmup_q_paramvh ─────▶ zcl_cmup_value_help ─▶ I_CompanyCode …
웹 ──③ PATCH UserSetting ($batch) ──▶ 행위 update (검증·버퍼) ─▶ save ─▶ 래퍼 change_settings
                                                                          ├─ BAPI_USER_GET_DETAIL (현재 파라미터)
                                                                          ├─ 병합 (보낸 항목만 교체)
                                                                          └─ BAPI_USER_CHANGE
```

## 폴더 = 활성화 순서

| 폴더 | 패키지 | 내용 |
| --- | --- | --- |
| `01_tier2` | **classic** (Standard ABAP) | `zif_cmup_user_api`, `zcl_cmup_user_api`, `zcx_cmup_user_api` → 3개 모두 **C1 release** |
| `02_cds` | ABAP Cloud | custom entity 2개 |
| `03_class` | ABAP Cloud | 항목 설정, Value Help 출처, 쿼리 클래스 2개, 예외 |
| `04_bdef` | ABAP Cloud | BDEF (unmanaged, update만) + 행위 풀 → **같이 활성화** |
| `05_service` | ABAP Cloud | 서비스 정의 `ZAPI_CMUP_USERPARAM` |
| `99_test` | ABAP Cloud | 래퍼 테스트 classrun `zcl_cmup_test_user_api` (조회 → 변경 → 확인 → 복구) |

마지막에 서비스 바인딩을 만듭니다. ADT에서 `ZAPI_CMUP_USERPARAM` 우클릭 → New Service Binding
→ 이름 `ZAPI_CMUP_USERPARAM_O4`, 유형 **OData V4 - Web API** → Publish.

**Tier 2 release 방법**: 클래스/인터페이스 열기 → Properties → API State →
Use System-Internally (Contract C1) 추가 → **Use in Cloud Development** 체크.

## 파일 구성

| 파일 | 역할 |
| --- | --- |
| `01_tier2/zif_cmup_user_api` | 래퍼 인터페이스. 타입(항목 ID, 값, 코드+텍스트)과 기본값 항목 상수 |
| `01_tier2/zcl_cmup_user_api` | BAPI 호출, 파라미터 병합 |
| `02_cds/zce_cmup_usersetting` | ① 현재 설정 (root custom entity, 키: UserId + ItemId) |
| `02_cds/zce_cmup_paramvh` | ② Value Help (파라미터 `p_itemid`, 검색 가능) |
| `03_class/zcl_cmup_config` | **포털 항목 목록**(업무영역·항목명·순서)과 **본인만 허용** 설정 |
| `03_class/zcl_cmup_value_help` | `read_source` 하나. 파라미터별 고를 수 있는 값 → ② 목록, ①의 값 텍스트, ③의 검증이 같이 쓴다 |
| `03_class/zcl_cmup_q_usersetting` | ① 쿼리 |
| `03_class/zcl_cmup_q_paramvh` | ② 쿼리 |
| `04_bdef/zce_cmup_usersetting` | ③ BDEF |
| `04_bdef/zbp_ce_cmup_usersetting` | ③ 검증 → 버퍼 → 저장 (locals_imp) |

## 웹팀 전달용 호출 예시

서비스 URL (바인딩 이름 기준):
`/sap/opu/odata4/sap/zapi_cmup_userparam_o4/srvd_a2x/sap/zapi_cmup_userparam/0001/`

### ① 현재 설정

```
GET UserSetting?$filter=UserId eq 'HONG'
GET UserSetting                              ← UserId 없으면 로그온 사용자
```

```json
{ "value": [
  { "UserId": "HONG", "ItemId": "DATFM", "Category": "USERINFO", "AreaName": "사용자정보",
    "ItemName": "날짜 형식", "ParamValue": "4", "ValueText": "", "SortOrder": 20 },
  { "UserId": "HONG", "ItemId": "BUK", "Category": "PARAM", "AreaName": "재무",
    "ItemName": "회사코드", "ParamValue": "1000", "ValueText": "서울 본사", "SortOrder": 110 }
] }
```

- 설정 안 한 항목도 `ParamValue: ""`로 한 줄씩 나옵니다 (화면 칸이 항상 다 나오게).
- `ValueText`(코드 옆 이름)는 파라미터만 채워집니다. 사용자정보는 빈 값입니다.
- `AreaName` / `ItemName` / `SortOrder` 로 웹 3-1 업무영역, 3-2 파라미터명, 배치 순서를 그릴 수 있습니다.

### ② Value Help

```
GET ParamValueHelp(p_itemid='BUK')/Set?$search=서울&$top=50&$skip=0&$count=true
```

```json
{ "@odata.count": 2, "value": [
  { "ItemId": "BUK", "ParamValue": "1000", "ValueText": "서울 본사" },
  { "ItemId": "BUK", "ParamValue": "1100", "ValueText": "서울 연구소" }
] }
```

- `p_itemid` 에는 파라미터 ID(BUK, WRK …)만 됩니다. 사용자정보(언어·타임존 등)는 팝업 대상이 아닙니다.
- `$search` 는 코드·텍스트에 포함된 것 (대소문자 무시).

### ③ 수정

```
PATCH UserSetting(UserId='HONG',ItemId='BUK')
Content-Type: application/json
x-csrf-token: <GET 할 때 x-csrf-token: fetch 로 받은 값>

{ "ParamValue": "2000" }
```

- 여러 항목을 한 번에 저장할 때는 **`$batch` 의 changeset 하나**로 묶습니다 → 한 트랜잭션 → 사용자당 BAPI 1번.
- 파라미터(BUK 등)에 `""` 를 보내면 그 파라미터를 지웁니다.
- 언어는 ISO 코드(`KO`, `EN`)로 주고받습니다.
- 잘못된 값이면 PATCH 가 에러(400)와 메시지를 돌려줍니다 (목록에 없는 값, 포털 대상이 아닌 항목, 다른 사용자 등).

## 항목 추가하는 법 (확정 목록 23개가 오면)

1. `zcl_cmup_config=>get_items` 에 한 줄 추가 (항목 ID, 구분, 업무영역, 항목명, 순서)
2. 파라미터면 `zcl_cmup_config=>c_param` 에 상수 추가
3. `zcl_cmup_value_help=>read_source` 에 VH 출처 추가 (릴리스된 CDS 우선, 없으면 Tier 2 래퍼에 메서드 추가)
4. 사용자정보 중 기본값 5개 외의 필드(출력장치 SPLD 등)는 `zif_cmup_user_api=>c_default` 와 래퍼의 get/change 둘 다 추가

## 가정 — 다르면 고칠 곳

| 가정 | 고칠 곳 |
| --- | --- |
| 포털 사용자가 그대로 SAP 에 로그온 (본인 것만) | `zcl_cmup_config=>c_self_only` → 기술 사용자 + UserId 방식이면 `abap_false`, 기술 사용자에 `S_USER_GRP` 03/02 (보안 검토) |
| 항목은 초안 10개 (사용자정보 5 + 파라미터 5) | `zcl_cmup_config=>get_items` |
| 파라미터 VH 출처 = `I_CompanyCode`, `I_ControllingArea`, `I_PurchasingOrganization`, `I_SalesOrganization`(+`Text`), `I_Plant` | `zcl_cmup_value_help=>read_source` |
| 사용자정보 값은 웹이 정해서 보내고 검증은 BAPI 에 맡김 | `check_value` (행위 클래스) |
| "신청" = 즉시 반영 (승인 없음) | 승인이 있으면 신청 내역 Z테이블 + 승인 후 반영 로직 추가 |

## 실제 시스템에서 꼭 확인할 것

- [ ] **`BAPI_USER_CHANGE` 안에 COMMIT WORK 가 있는지** — RAP 저장 단계에서는 COMMIT 이 금지라 있으면 런타임 에러.
      있으면 bgPF 등 백그라운드 처리로 분리해야 함 (디버깅으로 확인)
- [ ] BAPI 구조 필드명: `BAPIDEFAUL-TIMEFM`, `BAPIDEFAX-TIMEFM`, `BAPIPARAX-PARID/PARVA`, `BAPILOGONX-TZONE` (SE11)
- [ ] 저장 단계 `save` 에서 `reported` 를 쓸 수 있는 릴리스인지 (안 되면 그 줄을 로그 기록으로 바꿈)
- [ ] 위 CDS 들의 릴리스 상태(C1)·필드명, 그리고 DCL 때문에 포털 사용자에게 목록이 비어 보이지 않는지
- [ ] SU3·BAPI 가 파라미터 값을 마스터와 대조하지 않는지 (없는 값 `ZZZZ` 로 테스트 → 그대로 저장되면 `check_value` 검증 유지)

## 일부러 안 넣은 것 (다음 단계)

- 사전 잠금 — 지금은 BAPI 가 저장할 때 잠근다 (SU01 에서 같은 사용자를 열고 있으면 그때 에러)
- 권한 오브젝트 — `get_global_authorizations` 는 전부 허용
- 종속 VH — 저장위치(LAG)처럼 플랜트별로 다른 값은 VH 에 추가 조건이 필요
- 건수가 많은 마스터 — 지금은 전체를 읽고 ABAP 에서 검색. 자재·거래처 같은 건 검색어를 SQL 조건으로
- 설치된 언어만 보여주기
