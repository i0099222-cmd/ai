# 동적 테이블 업로드 (SAP RAP / PCE)

CBO 테이블 구조를 런타임에 읽어 **엑셀 템플릿 다운로드 → 업로드 → JSON 변환 → 마이그레이션**까지 처리.
기존 TADIR 래핑 오브젝트 조회 RAP 앱(draft 사용)에 액션으로 붙이는 것을 전제로 한다.

---

## 새로 만들 오브젝트 = 5개

| # | 오브젝트 | 종류 | 파일 |
|---|---|---|---|
| 1 | `ZCL_DYNAMIC_TABLE_UPLOAD` | 클래스 | `zcl_dynamic_table_upload.clas.abap` ★ |
| 2 | `ZTB_DYN_UPLOAD_STG` | 테이블 | `ztb_dyn_upload_stg.tabl.asddls` |
| 3 | `ZTB_DYN_UPL_STG_D` | 테이블(draft) | `ztb_dyn_upl_stg_d.tabl.asddls` |
| 4 | `ZI_DYNUPLOADSTAGING` | CDS 뷰 | `zi_dynuploadstaging.asddls` |
| 5 | `ZC_DYNUPLOADSTAGING` | CDS 뷰(projection) | `example_tadirobject_view_additions.asddls` 안에 있음 |

**로직은 1번 클래스 하나에 다 있다.** 2~5번은 "TADIR이 읽기 전용이라 업로드 파일을 담을 데가
없다"는 문제 때문에 생긴 부속이다.

### 기존 오브젝트 수정 (신규 아님)

| 대상 | 무엇을 | 참고 파일 |
|---|---|---|
| `ZI_TadirObject` | composition 1줄 추가 | `example_tadirobject_view_additions.asddls` |
| `ZC_TadirObject` | redirected 1줄 추가 | 〃 |
| BDEF | 액션 2개 + association 추가 | `example_tadir_upload.bdef.asbdef` |
| behavior 구현 클래스 | 메서드 4개 추가 | `example_lhc_tadir_upload.clas.abap` |

루트 draft 테이블은 **이미 draft를 쓰고 계시므로 기존 것을 그대로 씁니다.** 신규 생성 불필요.

---

## 처음이면 이것만

`zcl_dynamic_table_upload.clas.abap` — 핵심 로직 전부. 나머지는 이걸 앱에 꽂기 위한 배선이다.

RAP 의존성이 0이라 BO를 건드리기 전에 단독 테스트가 된다:

```abap
DATA(lo) = NEW zcl_dynamic_table_upload( ).
DATA(ls) = lo->create_excel_template( 'ZCBO_XXX' ).   " ls-file 이 나오면 성공
```

---

## 더 줄이고 싶다면 (5개 → 1개)

2~5번은 전부 **업로드 파일을 DB에 저장하기 위한** 것이다. Fiori Elements가
`@Semantics.largeObject` 필드에만 파일 업로더를 그려주기 때문이다.

파일을 저장하지 않고 **UI5 커스텀 코드로 base64 인코딩해서 액션 파라미터로 넘기면**
2~5번이 전부 사라지고 클래스 1개만 남는다. 대신 UI5 컨트롤러 익스텐션을 직접 짜야 한다.

| | 오브젝트 | UI5 커스텀 코드 | 파일 이력 |
|---|---|---|---|
| 현재 방식 (스테이징) | 5개 | 불필요 | 남음 |
| 파일 미저장 방식 | 1개 | **필요** | 안 남음 |

---

## ADT 작업 순서

```
1. 클래스 생성 → 단독 테스트로 템플릿이 나오는지 확인   ← 여기까지 먼저
2. 테이블 2개 생성 (스테이징 + draft)
3. CDS 뷰 2개 생성 (ZI / ZC)
4. 기존 뷰에 composition 추가
5. 기존 BDEF에 액션 추가
6. 기존 핸들러에 메서드 추가
```

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
