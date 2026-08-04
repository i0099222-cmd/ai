# 동적 테이블 업로드 (SAP RAP / PCE)

CBO 테이블 구조를 런타임에 읽어 **엑셀 템플릿 다운로드 → 업로드 → JSON 변환 → 마이그레이션**까지 처리하는 프로그램.
기존 TADIR 래핑 오브젝트 조회 RAP 앱(draft 사용)에 액션으로 붙이는 것을 전제로 한다.

---

## 처음이면 이 3개만 보세요

| 순서 | 파일 | 왜 |
|---|---|---|
| 1 | `zif_dynamic_table_upload.intf.abap` | 엔진이 뭘 할 수 있는지 한 눈에. 109줄, 주석 위주 |
| 2 | `zcl_dynamic_table_upload.clas.abap` | **핵심 로직 전부.** 템플릿 생성 / JSON 변환 / 마이그레이션 |
| 3 | `example_lhc_tadir_upload.clas.abap` | 기존 앱에 붙이는 방법. 액션 게이팅 + EML |

나머지 9개는 위 3개를 돌리기 위한 부속(테이블 DDL, CDS 뷰, BDEF)이다.

---

## 전체 파일 지도

### ① 엔진 — 그대로 만들면 됨 (UI/BO 무관, 재사용 가능)

| 파일 | 내용 |
|---|---|
| `zif_dynamic_table_upload.intf.abap` | 인터페이스 |
| `zcl_dynamic_table_upload.clas.abap` | 구현 ★ |
| `zcx_dynamic_table_upload.clas.abap` | 예외 클래스 |

RAP 의존성이 0이라 리포트/HTTP 서비스/다른 BO에서도 그대로 부를 수 있다.

### ② 신규 DDIC/CDS 오브젝트 — 그대로 만들면 됨

| 파일 | 내용 |
|---|---|
| `ztb_dyn_upload_stg.tabl.asddls` | 업로드 스테이징 테이블 (파일 보관) |
| `ztb_dyn_upl_stg_d.tabl.asddls` | 위 테이블의 draft 테이블 |
| `ztb_tadirobj_d.tabl.asddls` | 루트(TADIR) 엔터티의 draft 테이블 ※필드는 기존 뷰에 맞춰 조정 |
| `zi_dynuploadstaging.asddls` | 스테이징 인터페이스 뷰 (스트림 필드 정의) |

### ③ 기존 앱에 반영 — 통째로 쓰지 말고 필요한 부분만 발췌

| 파일 | 내용 |
|---|---|
| `example_tadirobject_view_additions.asddls` | 기존 CDS 뷰에 **추가할 줄만** 모음 + 신규 projection 뷰 |
| `example_tadir_upload.bdef.asbdef` | BDEF. 기존 BDEF에 액션/association/draft 선언 추가 |
| `example_lhc_tadir_upload.clas.abap` | behavior 구현. 기존 핸들러 클래스에 메서드 추가 |

`example_` 접두어 = 기존 오브젝트에 병합해야 하는 것. 파일명 그대로 만드는 게 아니다.

### ④ 선택 / 참고

| 파일 | 내용 |
|---|---|
| `zcl_dyn_upload_http_service.clas.abap` | **안 만들어도 됨.** 템플릿을 스트림 필드 대신 URL로 받고 싶을 때만 |
| `example_lhc_dynamic_upload.clas.abap` | TADIR과 무관한 **일반 BO용** 예시. 다른 앱에 엔진을 붙일 때 참고 |

---

## ADT 작업 순서

```
1. 엔진 3개 생성           → zif / zcl / zcx           (독립적으로 바로 테스트 가능)
2. 스테이징 테이블 생성     → ztb_dyn_upload_stg
3. draft 테이블 2개 생성    → ztb_dyn_upl_stg_d, ztb_tadirobj_d
4. 스테이징 CDS 뷰 생성     → zi_dynuploadstaging + zc_dynuploadstaging
5. 기존 뷰에 composition 추가 (+ LastChangedAt)
6. 기존 BDEF에 액션/draft 선언 추가
7. 기존 핸들러 클래스에 메서드 추가
```

1번까지만 해도 엔진은 단위 테스트가 가능하다. 먼저 거기까지 만들어서
`create_excel_template( 'ZCBO_XXX' )` 가 제대로 나오는지 확인하고 넘어가는 것을 권장.

---

## 꼭 기억할 것 3가지

**1. draft 상태에서 업로드 실행 금지**
`uploadData`는 대상 테이블에 직접 Open SQL MODIFY를 날린다. RAP 트랜잭션 버퍼를 안 거치므로
draft에서 실행 후 Discard해도 데이터가 남는다. → 활성 인스턴스에서만 실행되도록 막아둠.
사용자 흐름: 편집 → 파일 첨부 → **저장** → 업로드 실행.

**2. 액션 게이팅 필수**
TADIR은 대부분 PROG/CLAS/DDLS이고, `OBJECT = 'TABL'` 중에도 구조체(INTTAB)가 섞여 있다.
3단 필터(TABL → CBO 네임스페이스 → `is_uploadable`)로 막아둠. UI뿐 아니라 액션 내부에서도
다시 검사한다(OData 직접 호출 방어).

**3. 업로드 파일 포맷**
템플릿은 SpreadsheetML(.xls). 사용자가 Excel에서 채운 뒤 **"CSV UTF-8(세미콜론 구분)"으로
저장**해서 올리는 흐름이다. 진짜 .xlsx(zip) 파싱은 스코프 밖.

---

## 실 시스템에서 확인이 필요한 부분

러프 프로토타입이므로 아래는 ADT 코드 컴플리션으로 검증할 것.

- `xco_cp_json` / `xco_cp_abap_dictionary` 메서드 시그니처 (버전차 있음)
- `sych_bdl_draft_admin_inc` include 이름
- `abp_lastchange_tstmpl` 등 ETag 타입명
- 기존 CDS 뷰의 실제 필드명 (여기서는 `PgmId`/`Object`/`ObjName`으로 가정)
- 대상 CBO 테이블이 실행 컨텍스트에서 동적 Open SQL로 접근 가능한지

## 아직 안 만든 것

- 행 단위 오류 격리 (현재는 배치 전체 성공/실패)
- 업로드 파일 보관 정책 (DB에 계속 쌓임 — 주기 삭제 필요)
- Fiori Elements UI 어노테이션 (업로더/다운로드 링크 배치)
