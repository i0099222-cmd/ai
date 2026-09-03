# HTTP 서비스 호출 테스트 클래스 (SAP RAP / PCE)

이미 만들어져 있는 **HTTP Service + HTTP Handler 클래스**(`IF_HTTP_SERVICE_EXTENSION`)를
ABAP 안에서 실제로 HTTP 호출해서 확인하기 위한 테스트용 클래스 묶음입니다.
엑셀 다운로드/업로드 서비스처럼 바이너리 응답을 주는 서비스도 검증할 수 있습니다.

| 파일 | 내용 |
| --- | --- |
| `zcl_http_service_tester.clas.abap` | 호출 클래스 본체. `IF_OO_ADT_CLASSRUN` 구현 → ADT 에서 **F9** 로 바로 실행 |
| `zcl_http_service_tester.clas.testclasses.abap` | 같은 클래스의 Test Classes 인클루드(ABAP Unit 통합 테스트) |

ABAP Cloud 언어버전에서 릴리즈된 API만 사용합니다
(`CL_HTTP_DESTINATION_PROVIDER`, `CL_WEB_HTTP_CLIENT_MANAGER`, `IF_WEB_HTTP_REQUEST/RESPONSE`).

## 1. 준비: 호출 URL 확인

ADT 에서 HTTP Service 오브젝트를 열면 상단에 URL 이 표시됩니다. 그 값을 그대로 복사합니다.

```
https://<host>:<port>/sap/bc/http/sap/z_excel_service?sap-client=100
```

## 2. 실행 방법 A — 콘솔 실행 (가장 빠름)

`ZCL_HTTP_SERVICE_TESTER` 의 `IF_OO_ADT_CLASSRUN~MAIN` 맨 위 블록(`lv_url`, `lv_method`,
`lv_user`, `lv_body`)만 바꾸고 **F9**. 콘솔에 아래가 출력됩니다.

- HTTP 상태코드 / reason / 응답시간(ms)
- 응답 헤더 전체, `Content-Type`
- 본문 크기, xlsx(ZIP `PK` 시그니처) 여부
- 텍스트 응답이면 본문(기본 3000자까지)

## 3. 실행 방법 B — ABAP Unit

`zcl_http_service_tester.clas.testclasses.abap` 의 `CO_URL`(필요하면 `CO_USER`/`CO_PASSWORD`)을
채우고 클래스에서 **Ctrl+Shift+F10**.

- `excel_download_returns_ok` : GET 호출이 200 인지
- `excel_download_is_xlsx` : 응답이 실제 xlsx 인지(ZIP 시그니처 + MIME + 최소 크기)
- `unknown_path_is_not_ok` : 없는 경로가 200 을 주지 않는지(핸들러 경로 분기 확인)
- `post_json_returns_ok` : JSON 본문 POST 가 200 인지

`CO_URL` 이 비어 있으면 네 테스트 모두 조용히 통과(스킵)하므로, 다른 사람이 전체 테스트를
돌려도 깨지지 않습니다. 실제 시스템을 호출하므로 `RISK LEVEL DANGEROUS` / `DURATION LONG`
으로 선언되어 있고, 기본 테스트 실행 프로파일에서는 제외됩니다.

## 4. 다른 코드에서 직접 사용

```abap
DATA(ls_result) = zcl_http_service_tester=>create_by_url( lv_url
                    )->set_method( zcl_http_service_tester=>co_method-post
                    )->add_header( iv_name = 'Accept' iv_value = 'application/json'
                    )->set_body_text( `{ "bukrs": "1000" }`
                    )->use_csrf_token( )->execute( ).

IF ls_result-status_code <> 200.
  " ls_result-body_text 에 핸들러가 내려준 에러 메시지가 들어 있다
ENDIF.
```

엑셀 업로드(POST) 테스트는 `set_body_binary( iv_data = lv_xstring )` 을 사용합니다.

## 5. 인증

- **권장**: `create_by_comm_arrangement( iv_comm_scenario = 'Z_SCENARIO' iv_service_id = 'Z_SERVICE' )`
  → 인증정보를 소스가 아니라 Communication Arrangement 에 둡니다.
- 임시 확인용으로만 `set_basic_auth( )`. **운영 계정/암호를 소스에 넣고 커밋하지 마세요.**

## 6. 자주 걸리는 것

| 증상 | 원인/해결 |
| --- | --- |
| `403` + `CSRF token validation failed` | POST/PUT 인데 토큰이 없음 → `use_csrf_token( )` 사용(같은 client 로 fetch 후 재사용) |
| `401` | 인증 없음 → basic auth 또는 Communication Arrangement 설정 |
| `404` | URL 경로 오타 또는 HTTP Service 미활성화 |
| SSL 오류 | 호출 대상 시스템 인증서가 `STRUST` 의 SSL Client(Anonymous/Standard)에 없음 |
| 본문이 깨져 보임 | 엑셀 응답 → 텍스트 변환하지 않고 `body_binary`/`body_size`/`is_xlsx` 로 확인 |
| 응답 본문이 0 byte | 핸들러에서 `response->set_binary( )` 후 `set_status( 200 )` / `Content-Disposition` 설정 여부 확인 |

## 7. HTTP 없이 핸들러만 단위 테스트하려면

`ZCL_..._HTTP_HANDLER` 의 비즈니스 로직(엑셀 생성/파싱)을 별도 클래스로 빼고
`handle_request` 는 그 클래스를 호출만 하도록 두면, 로직 쪽은 HTTP 없이 순수 ABAP Unit 으로
테스트할 수 있습니다. 이 클래스는 그 위에서 "실제로 HTTP 로 붙었을 때"를 확인하는 용도입니다.
