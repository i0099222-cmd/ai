# 사용자 파라미터 (SU3) API · 초안

포털(HCP)에서 SU3 화면을 대신 쓰기 위한 **OData V4 Web API**입니다.
웹이 화면을 그리고, SAP는 아래 3가지를 제공합니다.

| # | 웹 화면 동작 | API | 내부 처리 |
| --- | --- | --- | --- |
| ① | 화면 열기 → default 값 채우기 | `GET UserSetting` | `BAPI_USER_GET_DETAIL` |
| ② | 검색 버튼 → 팝업 목록 | `GET ParamValueHelp(p_itemid='BUK')/Set` | 마스터 조회 (항목별) |
| ③ | 저장 | `POST UserSetting/SAP__self.saveSettings` (액션) | 검증 → 병합 → `BAPI_USER_CHANGE` |

- 환경: S/4HANA Cloud Private Edition
- API 계층은 **ABAP for Cloud Development**, BAPI·미공개 테이블은 **Tier 2 래퍼**(classic)로만 접근

## 흐름

```
웹 ──① GET UserSetting ─────────────▶ zcl_cmup_q_usersetting ─▶ 래퍼 get_settings ─▶ BAPI_USER_GET_DETAIL
웹 ──② GET ParamValueHelp('BUK') ───▶ zcl_cmup_q_paramvh ─────▶ zcl_cmup_value_help ─▶ I_CompanyCode …
웹 ──③ POST saveSettings (액션) ────▶ 액션 (검증 → 바로 저장) ─▶ 래퍼 change_settings
                                                                          ├─ BAPI_USER_GET_DETAIL (현재 파라미터)
                                                                          ├─ 병합 (보낸 항목만 교체)
                                                                          ├─ BAPI_USER_CHANGE
                                                                          └─ BAPI_TRANSACTION_COMMIT (에러면 ROLLBACK)
```

## 폴더 = 활성화 순서

| 폴더 | 패키지 | 내용 |
| --- | --- | --- |
| `01_tier2` | **classic** (Standard ABAP) | `zif_cmup_user_api`, `zcl_cmup_user_api`, `zcx_cmup_user_api`, `zcl_cmup_vh_tier2` → 4개 모두 **C1 release** |
| `02_cds` | ABAP Cloud | custom entity 2개 + 저장 액션 파라미터(추상 엔티티 2개 → **같이 활성화**) + 저장 결과(추상 엔티티 1개) |
| `03_class` | ABAP Cloud | Value Help 출처(+ 항목 목록), 쿼리 클래스 2개, 예외 |
| `04_bdef` | ABAP Cloud | 추상 BDEF `zd_cmup_saverequest` 먼저 → 본 BDEF (unmanaged, 저장 액션) + 행위 풀 **같이 활성화** |
| `05_service` | ABAP Cloud | 서비스 정의 `ZAPI_CMUP_USERPARAM` |
| `99_test` | ABAP Cloud | classrun 테스트: `zcl_cmup_test_user_api` (래퍼 조회 → 변경 → 확인 → 복구), `zcl_cmup_test_vh` (Value Help 목록), `zcl_cmup_test_save` (저장 액션 + 커밋, EML) |

마지막에 서비스 바인딩을 만듭니다. ADT에서 `ZAPI_CMUP_USERPARAM` 우클릭 → New Service Binding
→ 이름 `ZAPI_CMUP_USERPARAM_O4`, 유형 **OData V4 - Web API** → Publish.

**Tier 2 release 방법**: 클래스/인터페이스 열기 → Properties → API State →
Use System-Internally (Contract C1) 추가 → **Use in Cloud Development** 체크.

## 파일 구성

| 파일 | 역할 |
| --- | --- |
| `01_tier2/zif_cmup_user_api` | 래퍼 인터페이스. 타입(항목 ID, 값, 코드+텍스트)과 기본값 항목 상수 |
| `01_tier2/zcl_cmup_user_api` | BAPI 호출, 파라미터 병합 |
| `01_tier2/zcl_cmup_vh_tier2` | 사용자정보 Value Help 중 로그온 언어(T002)·타임존(TTZZ) 목록 → **C1 release** |
| `02_cds/zce_cmup_usersetting` | ① 현재 설정 (root custom entity, 키: UserId + ItemId, 값: ParamValue + ValueText) |
| `02_cds/zce_cmup_paramvh` | ② Value Help (파라미터 `p_itemid`, 검색 가능) |
| `02_cds/zd_cmup_saverequest`, `zd_cmup_saveitem` | ③ 저장 액션 파라미터 (요청 1 : 항목 N, deep parameter) |
| `02_cds/zd_cmup_saveresult` | ③ 저장 액션 결과 (항목마다 상태·메시지) |
| `03_class/zcl_cmup_value_help` | `get_item_ids` = 이 API 가 다루는 항목 (① 조회 대상 = ③ 수정 허용 대상), `read_source` = 항목별 고를 수 있는 값 → ② 목록, ①의 값 텍스트, ③의 검증 |
| `03_class/zcl_cmup_q_usersetting` | ① 쿼리 |
| `03_class/zcl_cmup_q_paramvh` | ② 쿼리 |
| `04_bdef/zd_cmup_saverequest` | ③ 액션 파라미터의 계층 (추상 BDEF, `with hierarchy`) |
| `04_bdef/zce_cmup_usersetting` | ③ BDEF — 정적 액션 `saveSettings` |
| `04_bdef/zbp_ce_cmup_usersetting` | ③ 검증 → 현재값과 다른 항목만 바로 저장 (locals_imp). RAP 저장 단계는 비움 |

## 웹팀 전달용 호출 예시

서비스 URL (바인딩 이름 기준):
`/sap/opu/odata4/sap/zapi_cmup_userparam_o4/srvd_a2x/sap/zapi_cmup_userparam/0001/`

### ① 현재 설정

```
GET UserSetting                              ← 로그온 사용자 본인 것 (필터·정렬·페이징 없음)
```

```json
{ "value": [
  { "UserId": "HONG", "ItemId": "DATFM", "ParamValue": "4",    "ValueText": "YYYY.MM.DD" },
  { "UserId": "HONG", "ItemId": "BUK",   "ParamValue": "1000", "ValueText": "서울 본사" },
  { "UserId": "HONG", "ItemId": "VKO",   "ParamValue": "",     "ValueText": "" }
] }
```

- 이 API 가 다루는 항목(`get_item_ids`)마다 한 줄씩, 설정 안 한 항목도 `ParamValue: ""` 로 나옵니다.
- 항목 이름·순서·묶음 같은 화면 구성은 웹이 정합니다.
- 키로 한 건 조회(`UserSetting(UserId=…,ItemId=…)`)는 지원하지 않습니다.

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

- `p_itemid` 에는 파라미터 ID(BUK, WRK …)와 사용자정보 항목(LANGU, DATFM, DCPFM, TIMEFM, TZONE) 모두 됩니다.
- `$search` 는 코드·텍스트에 포함된 것 (대소문자 무시).

### ③ 수정

```
POST UserSetting/SAP__self.saveSettings
Content-Type: application/json
x-csrf-token: <GET 할 때 x-csrf-token: fetch 로 받은 값>

{ "UserId": "",
  "_Items": [ { "ItemId": "BUK", "ParamValue": "2000" },
              { "ItemId": "WRK", "ParamValue": "" } ] }
```

- **바꿀 항목만** `_Items` 에 담습니다. 목록에 없는 항목은 손대지 않습니다.
- `UserId` 는 비우면 로그온 사용자입니다 (다른 사용자는 안 됨).
- 한 번 호출 = BAPI 1번 + 커밋. **하나라도 틀리면 전부 저장하지 않습니다.**
- 저장 액션은 `$batch` 로 다른 변경과 묶지 않고 단독으로 호출합니다 (액션 안에서 바로 커밋하므로).
- 현재값과 같은 항목은 BAPI 대상에서 빠집니다 (다 같으면 BAPI 를 부르지 않음).
- 파라미터(BUK 등)에 `""` 를 보내면 그 파라미터를 지웁니다.
- 성공 응답 (200): 보낸 항목마다 한 줄. 값은 **저장 후 다시 읽은 실제 값**이고, 바꾼 항목이 반영 안 됐으면 400 에러

```json
{ "value": [
  { "ItemId": "BUK", "ParamValue": "2000", "ValueText": "부산 공장", "Status": "CHANGED",   "Message": "변경했습니다" },
  { "ItemId": "WRK", "ParamValue": "1100", "ValueText": "서울 1공장", "Status": "UNCHANGED", "Message": "현재값과 같아서 변경하지 않았습니다" }
] }
```

- 실패 응답 (400): 첫 에러가 `error.message`, 나머지는 `error.details`
  - 검증·BAPI 에러 → 아무것도 저장되지 않음
  - 에러 없이 끝났는데 반영 안 된 항목 → 그 항목 에러 + "다음 항목은 반영되었습니다: …" (이미 커밋돼 되돌릴 수 없음)
  - 저장 후 확인 조회 실패 → "다시 조회해서 확인하세요" (①로 다시 조회)

```json
{ "error": { "code": "…", "message": "LANGU: KO 는 고를 수 없는 값입니다",
             "details": [ { "message": "ZZZ 는 수정할 수 없는 항목입니다" } ] } }
```
- 액션 이름 앞의 네임스페이스(`SAP__self`)는 `$metadata` 에서 확인합니다.
- 언어는 SAP 언어 키(`3` = 한국어, `E` = 영어)로 주고받습니다. Value Help 코드도 같습니다.
- 잘못된 값이면 에러(400)와 메시지를 돌려줍니다 (Value Help 목록에 없는 값, 이 API 가 다루지 않는 항목, 다른 사용자).

## 항목 추가하는 법 (확정 목록 23개가 오면)

모두 `zcl_cmup_value_help` 에서 합니다.
1. 상수 추가: 파라미터면 `c_param`, 사용자정보면 `c_userinfo`
2. `get_item_ids` 에 한 줄 추가
3. `read_source` 에 VH 출처 추가 (릴리스된 CDS 우선, 없으면 Tier 2 `zcl_cmup_vh_tier2` 에 메서드 추가)
4. 사용자정보 중 기본값 5개 외의 필드(출력장치 SPLD 등)는 `zif_cmup_user_api=>c_default` 와 래퍼의 get/change 도 추가

## 가정 — 다르면 고칠 곳

| 가정 | 고칠 곳 |
| --- | --- |
| 포털 사용자가 그대로 SAP 에 로그온 (본인 것만) | ① 쿼리는 로그온 사용자 고정, ③ `savesettings` 와 `read` 는 본인만 허용 → 기술 사용자 + UserId 방식이 되면 ① 에 UserId 필터 추가, 기술 사용자에 `S_USER_GRP` 03/02 (보안 검토) |
| 항목은 초안 10개 (사용자정보 5 + 파라미터 5) | `zcl_cmup_value_help=>get_item_ids` |
| 파라미터 VH 출처 = `I_CompanyCode`, `I_ControllingArea`, `I_PurchasingOrganization`, `I_SalesOrganization`(+`Text`), `I_Plant` | `zcl_cmup_value_help=>read_source` |
| 빈 값은 검증 없이 BAPI 로 (파라미터 = 삭제, 기본값 항목 = BAPI 판단) | `savesettings` (행위 클래스) |
| "신청" = 즉시 반영 (승인 없음) | 승인이 있으면 신청 내역 Z테이블 + 승인 후 반영 로직 추가 |

## 실제 시스템에서 꼭 확인할 것

- [ ] **래퍼(ACO 프록시)가 BAPI 를 RFC 목적지(별도 세션)로 호출하는지** — 저장은 액션 안에서 바로 하고
      `BAPI_TRANSACTION_COMMIT` 까지 하므로, 같은 세션 로컬 호출이면 COMMIT 때문에 RAP LUW 덤프.
      `BAPI_USER_CHANGE` 와 `BAPI_TRANSACTION_COMMIT` 이 **같은 목적지**로 가야 같은 세션이 커밋된다
- [ ] **deep parameter**(`static action … deep parameter`)와 추상 BDEF `with hierarchy` 를 지원하는 릴리스인지 (SAP_BASIS 7.58 무렵부터로 알고 있음)
- [ ] BAPI 구조 필드명: `BAPIDEFAUL-TIMEFM`, `BAPIDEFAX-TIMEFM`, `BAPIPARAX-PARID/PARVA`, `BAPILOGONX-TZONE` (SE11)
- [ ] 위 CDS 들의 릴리스 상태(C1)·필드명, 그리고 DCL 때문에 포털 사용자에게 목록이 비어 보이지 않는지
- [ ] SU3·BAPI 가 파라미터 값을 마스터와 대조하지 않는지 (없는 값 `ZZZZ` 로 테스트 → 그대로 저장되면 `savesettings` 의 값 검증 유지)

## 일부러 안 넣은 것 (다음 단계)

- 사전 잠금 — 지금은 BAPI 가 저장할 때 잠근다 (SU01 에서 같은 사용자를 열고 있으면 그때 에러)
- 권한 오브젝트 — `get_global_authorizations` 는 전부 허용
- 종속 VH — 저장위치(LAG)처럼 플랜트별로 다른 값은 VH 에 추가 조건이 필요
- 건수가 많은 마스터 — 지금은 전체를 읽고 ABAP 에서 검색. 자재·거래처 같은 건 검색어를 SQL 조건으로
- 설치된 언어만 보여주기
