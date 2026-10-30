# DRM 엑셀 공통 메서드 (`zcl_cm_excel_drm`)

DRM이 걸린 엑셀 파일을 외부 파싱 API로 해제하고, 엑셀 데이터를 **호출하는 쪽이 넘긴 itab**에 채워서 돌려주는 공통 메서드입니다.

- 환경: S/4HANA Cloud Private Edition, **ABAP for Cloud Development** 언어 버전
- 파싱 API는 `returntype = json`만 지원하므로 **DRM이 해제된 원본 파일은 받을 수 없음** → 데이터(itab)만 제공
- 하루 **300건** 호출 한도 (한국 시간 00시 기준)

## 처리 흐름

```
zcl_cm_excel_drm=>read_drm_excel
  ├─ 입력값 체크 (파일, 시작 행 > 헤더 행)
  ├─ check_daily_limit       일일 300건 체크 (인터페이스 로그 COUNT)
  ├─ upload_cdn_file         CDN 업로드 (multipart/form-data)
  ├─ call_excel_parse_api    파싱 API 호출 → headers / datas
  ├─ fill_target_table       호출자의 itab에 컬럼 순서대로 채우기
  └─ delete_cdn_file         CDN 파일 삭제 (성공/실패 모두, 실패 시 CLEANUP에서)

zcl_cm_excel_drm=>convert_itab_to_excel   itab → xlsx 바이너리 (필요할 때만)
```

## 파일 구성

| 파일 | 내용 |
|---|---|
| `zcl_cm_excel_drm.clas.abap` | DRM 엑셀 공통 클래스 (본체) |
| `zif_cm_excel_drm.intf.abap` | 상수 (API ID, 업로드 필드명, 성공 코드, 한도, 타임존) |
| `zcx_cm_drm.clas.abap` | 예외 클래스 |
| `zcl_cm_multipart_util.clas.abap` | multipart 파트 타입(`tt_part`), 확장자로 MIME 판단 |
| `zcl_cm_if_communication_multipart.snippet.abap` | 기존 공통 래퍼 `zcl_cm_if_communication=>run`에 추가할 multipart 처리 부분 |

## 공개 메서드

### `read_drm_excel`

| 파라미터 | 구분 | 설명 |
|---|---|---|
| `iv_file` | IMPORTING | DRM 걸린 엑셀 파일 (xstring) |
| `iv_filename` | IMPORTING | 파일명 (MIME 판단, multipart filename) |
| `iv_empno` | IMPORTING | 요청자 사번 |
| `iv_key` | IMPORTING | CDN 키 |
| `iv_sheet_no` | IMPORTING | 읽을 시트 번호 (기본 1) |
| `iv_header_row` | IMPORTING | 헤더 행 (기본 1) |
| `iv_start_row` | IMPORTING | 데이터 시작 행 (기본 2, 헤더 행보다 커야 함) |
| `iv_skip_empty` | IMPORTING | 빈 행 건너뛰기 (기본 true) |
| `et_data` | EXPORTING | 호출하는 쪽의 itab (구조체 테이블) |
| `et_header` | EXPORTING | 엑셀 헤더 (string_table) |
| `zcx_cm_drm` | RAISING | 한도 초과, 업로드/파싱 실패, 값 변환 오류 등 |

### `convert_itab_to_excel`

itab을 xlsx 바이너리로 만듭니다 (`XCO_CP_XLSX` 사용).
**원본 파일이 아니라 값만 들어간 1시트짜리 새 파일**입니다. 서식/수식/병합 셀/그림은 없고, **DRM도 없으므로** 다운로드나 첨부 기능에 쓰기 전에 보안 확인이 필요합니다.

## 사용 방법 (다른 개발자용)

```abap
TYPES: BEGIN OF ty_item,     " A열, B열, C열 순서
         matnr TYPE string,
         menge TYPE string,
         netpr TYPE string,
       END OF ty_item.
DATA lt_items TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

TRY.
    zcl_cm_excel_drm=>read_drm_excel( EXPORTING iv_file     = lv_file
                                                iv_filename = lv_filename
                                                iv_empno    = lv_empno
                                                iv_key      = lv_key
                                      IMPORTING et_data     = lt_items
                                                et_header   = DATA(lt_header) ).

    " (필요할 때만) 읽은 데이터로 xlsx 다시 만들기
    DATA(lv_xlsx) = zcl_cm_excel_drm=>convert_itab_to_excel( it_data   = lt_items
                                                             it_header = lt_header ).
  CATCH zcx_cm_drm INTO DATA(lx).
    " lx->get_text( )
ENDTRY.
```

### 사용 시 주의

1. 구조의 **필드 순서 = 엑셀 컬럼 순서** (A열 → 1번째 필드). 구조보다 엑셀 컬럼이 많으면 나머지는 무시됨
2. 필드는 **`string`으로 받는 것을 권장**
   - `1,000`처럼 콤마가 있는 금액은 숫자 필드에서 변환 오류 발생 (몇 행 몇 열인지 예외 메시지로 알려줌)
   - **날짜(`d`) 필드는 오류 없이 잘못된 값이 들어갈 수 있음** (`2026/10/28` 등)
   - `CHAR` 필드는 길이를 넘는 값이 오류 없이 잘림
3. include나 중첩 구조 대신 **단순(flat) 구조** 사용
4. 헤더 행은 `et_data`에 들어가지 않고 **`et_header`**로 받음. 양식 확인이 필요하면 `et_header`를 비교
5. 하루 **300건 한도**가 있고, 초과하면 예외 발생

## 주요 설계 결정

| 항목 | 결정 | 이유 |
|---|---|---|
| 매핑 방식 | 호출자 구조의 **필드 순서**로 매핑 | 공통 메서드가 양식을 몰라도 되고, 호출자는 itab만 넘기면 됨 |
| CDN 파일 삭제 | `TRY ... CLEANUP` | 파싱/채우기 어디서 에러가 나도 파일이 남지 않음 |
| 오류 전달 | 예외(`zcx_cm_drm`)로만 | `ev_msg`와 예외를 같이 두면 호출자가 헷갈림 |
| 일일 한도 기준 | `starttimestamp` (호출 시작 시각, UTC) | "오늘 몇 번 호출했나"에 맞고 타입 변환 불필요 |
| 한국 00시 계산 | 비교 값을 UTC로 변환해서 넘김 | DB 타임스탬프는 UTC. WHERE 절에서 컬럼을 변환하면 인덱스를 못 씀 |
| multipart | 래퍼에서 `set_multipart`로 파트 구성 | boundary를 프레임워크가 자동 생성. 로그도 래퍼에서 일관되게 남음 |
| 엑셀 생성 | `XCO_CP_XLSX` | ABAP Cloud에서는 SALV 사용 불가 (released API 아님) |

### 타임존 관련

- SAP 타임스탬프(`GET TIME STAMP`, RAP `createdat`)는 **항상 UTC로 저장**됨
- 한국 시간 = UTC + 9시간 → 한국 `10/29 00:00` = UTC `10/28 15:00` (`20261028150000`)
- SELECT는 타임존 변환 없이 숫자 비교만 하므로, 비교 값을 미리 UTC로 바꿔서 넘겨야 함
- `CONVERT`가 실패하면(`sy-subrc <> 0`) 결과가 0으로 남아 **전체 로그를 세게 되므로** 반드시 예외 처리

### multipart 관련

- multipart는 Content-Type 헤더에 **boundary**가 반드시 필요
- `it_headers`에 `Content-Type: multipart/form-data`를 직접 넣으면 boundary가 빠짐 → 사용하지 말 것
- `set_multipart`로 파트를 추가하면 boundary/구분선을 프레임워크가 자동 생성
- 파트 이름(`key`, `empno`, `file`)은 API 문서와 정확히 같아야 함 (대소문자 구분)

## 남은 확인 사항

| # | 확인할 것 | 어디서 | 완료 |
|---|---|---|---|
| 1 | `set_multipart` 시그니처 (파트 객체를 돌려주는지) | ADT에서 F2 | ☐ |
| 2 | 래퍼에 `it_multipart` 추가 협의 | 공통 담당자 | ☐ |
| 3 | 업로드 폼 필드명 (`key`, `empno`, `file`) | API 문서 | ☐ |
| 4 | `c_limit_tz` 타임존 키 (`cl_abap_context_info=>get_user_time_zone( )`로 확인) | 콘솔 클래스 | ☐ |
| 5 | `starttimestamp`가 UTC로 저장되는지 (`createdat`과 비교) | 로그 테이블 | ☐ |
| 6 | 300건에 실패 호출 포함 여부, 한도 초기화 기준 시각 | API 제공사 | ☐ |
| 7 | 로그 테이블명, apiid 필드명, 인덱스(`apiid + starttimestamp`) | 로그 테이블 | ☐ |
| 8 | `CATCH cx_root` 세 군데 → `run`이 실제로 던지는 예외 클래스로 | 래퍼 | ☐ |
| 9 | `zcl_cm_if_communication`, `zcl_cm_inf_header_util`이 ABAP Cloud 버전인지 | 래퍼 Properties | ☐ |
| 10 | 한글 파일명 업로드 시 깨지지 않는지 | 테스트 | ☐ |
| 11 | `XCO_CP_XLSX` 메서드명(`move_right`, `simple_from_to` 등) 릴리스 확인 | ADT | ☐ |
| 12 | 업로드 성공 코드 `'300'`, 파싱 성공 코드 `200`, 완료 상태 `3`이 맞는지 | API 문서 | ☐ |

## 참고: 동시 호출

299건인 상태에서 두 사용자가 동시에 실행하면 둘 다 체크를 통과해 301건이 될 수 있습니다.
제공사가 300건에서 어차피 차단한다면 현재 체크로 충분하고, 정확히 300건에서 끊어야 한다면 Lock Object(`cl_abap_lock_object_factory`)로 체크~호출 구간을 잠가야 합니다.
