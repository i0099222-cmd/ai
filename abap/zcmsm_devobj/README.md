# 개발 오브젝트 통합관리 · CDS (I → R → C)

딕셔너리 1차 기준. 테이블 7+1개에 대해 인터페이스(I) → 루트 BO(R) → 프로젝션(C) 3단 구성.

## 폴더 = 활성화 순서

| 폴더 | 내용 | 개수 |
| --- | --- | --- |
| `01_vh` | 고정값 도메인 VH 12개, 사용자 VH, 시스템 ID | 14 |
| `02_interface` | `ZI_CMSM_*` 테이블 1:1 뷰 (라벨·텍스트용 연관) + 요청번호 VH | 8 |
| `03_root` | `ZR_CMSM_*` BO 뷰 (composition, 관리 필드 semantics, LOB) | 7 |
| `04_projection` | `ZC_CMSM_*` 프로젝션 (텍스트 필드, VH, 검색) | 7 |
| `05_bdef` | BDEF — `ZR_CMSM_*` (managed + draft) 5개, `ZC_CMSM_*` (projection) 5개 | 10 |
| `06_class` | 행위 풀 `ZBP_R_CMSM_*` (전역 클래스 + 로컬 핸들러) | 5 |
| `07_service` | 서비스 정의 `ZUI_CMSM_DEVOBJ` | 1 |
| `08_mde` | 메타데이터 익스텐션 — `ZC_CMSM_*` 7개 (이름 = CDS 이름) | 7 |
| `09_app` | Fiori 앱 manifest의 routing 예시 (탭 + 상세 화면), annotation.xml 예시 | 2 |
| `10_mail` | 메일 HTML 템플릿 (SMW0 업로드용) | 1 |
| `11_excel` | 탭별 엑셀 업로드 템플릿 5개 + 생성 스크립트 | 6 |

ADT에서 폴더 순서대로 만들고, 루트와 자식(Req↔ReqHist, Vh↔VhSrc)은 서로 참조하니 **같이 선택해서 한 번에 활성화**한다. 전부 만든 뒤 한꺼번에 활성화해도 된다.

## BO 구성

| BO | 루트 | 자식 | 테이블 |
| --- | --- | --- | --- |
| 요청 | `ZR_CMSM_Req` / `ZC_CMSM_Req` | `ZR_CMSM_ReqHist` / `ZC_CMSM_ReqHist` | ztcmsm00170 / 00180 |
| 매핑 | `ZR_CMSM_Map` / `ZC_CMSM_Map` | — | ztcmsm00190 |
| Value Help | `ZR_CMSM_Vh` / `ZC_CMSM_Vh` | `ZR_CMSM_VhSrc` / `ZC_CMSM_VhSrc` | ztcmsm00200 / 00210 |
| OData 서비스 | `ZR_CMSM_Sb` / `ZC_CMSM_Sb` | — | ztcmsm00220 |
| 기술부채 | `ZR_CMSM_Debt` / `ZC_CMSM_Debt` | — | ztcmsm00230 |

## 가정 — 다르면 고칠 곳

| 가정 | 고칠 곳 |
| --- | --- |
| 테이블 번호는 딕셔너리 3장 순서: REQ 170, REQ_HIST 180, MAP 190, VH 200, VH_SRC 210, SB 220, DEBT 230 | `02_interface` 각 파일의 `select from` 한 줄 (테이블 이름은 I 뷰에만 나온다) |
| 시스템 ID 설정 테이블 = `ztcmsm00240` | `01_vh/zi_cmsm_sysid` 한 줄 |
| 도메인 이름은 딕셔너리 이름 그대로 (`ZDO_DM_*`) | `01_vh` 각 VH 파일의 도메인 이름 3곳 |
| 도메인 고정값 텍스트는 한국어(원본)로만 있음 | 도메인 VH 12개는 로그온 언어 텍스트가 없으면 한국어(언어 키 `'3'`)로: `coalesce( Txt.text, TxtKo.text )` — 영어 로그온에서도 상태·모듈 등이 빈 값이 안 된다. 영어 번역을 넣으면 영어 로그온엔 영어가 나온다 |
| 필드명 = 딕셔너리 필드명에서 `_`만 뺀 것 | I 뷰 |
| 사용자 이름은 `I_BusinessUserBasic` (BP 연결된 비즈니스 사용자만 나옴) | `01_vh/zi_cmsm_uservh` 하나 |

데이터 엘리먼트 이름은 CDS 어디에도 안 쓴다. 라벨은 I 뷰에서 `@EndUserText.label`로 직접 주고 R·C로 전파된다 (abap 타입으로 만든 필드도 라벨이 나오게).

## 레이어별로 넣은 것

- **VH**: 도메인 고정값은 `DDCDS_CUSTOMER_DOMAIN_VALUE` 기준 + 텍스트 left outer join → 로그온 언어 번역이 없어도 코드는 나온다 (텍스트만 빈칸). 전부 `#XS` 드롭다운.
- **I**: 테이블 필드 전부 + 라벨 + 텍스트/VH용 `[0..1]` 연관. `testat`(dec 21,7)는 `timestampl`로 cast — 안 하면 Fiori에서 숫자로 보인다. 등록 탭의 `created_by` 라벨은 "오브젝트 생성자"와 안 겹치게 "등록자", 요청은 "요청자".
- **R**: `composition` / `association to parent`, 관리 필드 `@Semantics.user.*`·`@Semantics.systemDateTime.*` (이력의 changedat/changedby도 createdAt/createdBy로 자동 채움), 테스트 파일 `@Semantics.largeObject`.
- **C**: `transactional_query`, 코드 옆 텍스트 필드(`…Text`, 사람은 `…Name`), `@Consumption.valueHelpDefinition`, `@ObjectModel.semanticKey`(표시 번호), 검색, `@Metadata.allowExtensions: true`.

## 일부러 안 넣은 것 (다음 단계)

- 조건부 숨김 (예: To-Be가 T-code일 때만 UI 섹션, UI 종류별 입력 필드) — 계산 필드 + `@UI.hidden` 참조로 다음 단계에서
- 권한 → 지금은 전부 `#NOT_REQUIRED`. DCL 만들 때 C 뷰를 `#CHECK`로
- 액션, determination, validation (표시 번호 채번, 기본값, 상태 변경, 이력 기록 등)
- 서비스 바인딩 (ADT에서 `ZUI_CMSM_DEVOBJ` 우클릭 → OData V4 - UI)
- 기술부채 여부 뷰, SB 기능 목록 custom entity (UNION 오브젝트 뷰는 `ZI_CMSM_DevObject`로 완료)
- `ZDO_SYSID` 유지보수 → 비즈니스 설정 유지보수 오브젝트 생성기를 쓰면 CDS·BDEF가 따로 생긴다

## BDEF

### 만드는 순서 (ADT)

1. `ZR_CMSM_*` 우클릭 → New Behavior Definition (managed) → 소스 붙여넣고 **저장만** (활성화 X)
2. `draft table ztcmsm00170_d` 줄에서 Ctrl+1 → 드래프트 테이블 생성. 자식 포함 7개 (`ztcmsm00170_d` ~ `ztcmsm00230_d`). 필드는 CDS에서 자동으로 만들어지니 손대지 않는다
3. `implementation in class zbp_r_cmsm_*` 줄에서 Ctrl+1 → 클래스 생성. 만들어진 로컬 핸들러를 `06_class` 내용으로 맞춘다 (quick fix 결과와 거의 같음)
4. BDEF + 클래스 같이 활성화
5. `ZC_CMSM_*` 우클릭 → New Behavior Definition (projection) → 붙여넣고 활성화
6. 서비스 정의 → 서비스 바인딩 (OData V4 - UI) → Publish → Preview

### 들어간 것

| 항목 | 내용 |
| --- | --- |
| 공통 | `strict ( 2 )`, `with draft`, UUID `numbering : managed`, `etag master LocalLastChangedAt`, `lock master total etag LastChangedAt`, `mapping … corresponding` |
| 권한 | 루트 `authorization master ( global )`, 자식 `dependent`. 핸들러는 빈 메서드 = 전부 허용 (strict 모드라 선언 필수) |
| 읽기 전용 | UUID 키, 부모 키, 표시 번호, 관리 필드, `DoneDate`, `VhImpl`, `TestBy`/`TestAt` |
| 필수 표시 | 요청: 제목·모듈·담당자 / 매핑: 구분·To-Be 유형·To-Be 오브젝트·모듈 / VH: VH 이름·모듈 / 데이터 소스: 유형·이름 / SB: Service Binding·모듈 / 기술부채: 개발 오브젝트·Debt Level·모듈 — 화면 별표 + FE 저장 시 체크. 서버 체크는 validation 단계에서 |
| 요청 이력 | `association _Hist { internal create; }` — BO 안에서만 만든다. 이력 엔티티에 update/delete 없음 → 화면에서 읽기 전용 |
| VH 데이터 소스 | 상세 화면에서 행 추가·수정·삭제 가능 |

### 다음 단계에서 채울 것

- 표시 번호 채번: 요청(RQ-)은 완료 (아래 "요청 트랜잭션"). MP-/VH-/SB-/TD-는 `ZCL_CMSM_DISPLAY_ID`에 구간만 잡아 둠
- 기본값: 개선상태 `T`, 시스템 ID (요청 상태 `R`은 완료)
- `DoneDate`, `VhImpl`, `TestBy`/`TestAt` 자동 채움
- `mapping … corresponding;`에서 문법 에러가 나면 `corresponding { }` 형태로 바꾼다

## MDE

ADT: `ZC_CMSM_*` 우클릭 → New Metadata Extension → 이름은 CDS와 같게 → 붙여넣고 활성화. 레이어는 `#CORE`.

### 목록 (탭) 컬럼

| 탭 | 컬럼 | 필터 |
| --- | --- | --- |
| 요청 | 요청번호, 제목, 모듈, 상태, 담당자, 요청자, 요청 일시, 완료일 | 모듈, 상태, 담당자, 요청자 |
| As-Is/To-Be | 등록번호, 구분, As-Is 오브젝트, To-Be 유형, To-Be 오브젝트, UI 종류, 모듈, 담당자 | 모듈, 구분, To-Be 유형, UI 종류, 담당자 |
| Value Help | 등록번호, VH 이름, 구현 방식, 모듈, 설명, 담당자, 요청번호 | 모듈, 구현 방식, 담당자 |
| OData 서비스 | 등록번호, Service Binding, 모듈, 설명, 담당자, 요청번호 | 모듈, 담당자 |
| 기술부채 | ID, 모듈, 개발 오브젝트, Debt Level, 래핑 여부, 개선상태, 업무담당자 | 모듈, Debt Level, 개선상태, 래핑 여부, 업무담당자 |

- 정렬: 등록 일시 내림차순. 탭마다 `@UI.selectionPresentationVariant` `#Tab` (탭 이름 포함)
- 고정값 코드(상태·모듈·유형 등)는 텍스트만 (`#TEXT_ONLY`), 사람·시스템은 "이름 (ID)"
- 텍스트 보조 필드(`…Text`, `…Name`)와 UUID, 마임 타입·파일명은 숨김 → 테이블 설정에서도 안 보인다

### 상세 화면 섹션

| 엔티티 | 제목 / 부제 | 헤더 | 섹션 |
| --- | --- | --- | --- |
| 요청 | 제목 / 요청번호 | 상태, 담당자, 요청자, 요청 일시 | 요청 내용 · 처리 · 변경 이력(표) · 관리 정보 |
| 매핑 | To-Be 오브젝트 / 등록번호 | 구분, 모듈, 담당자 | 기본 정보 · 매핑 (As-Is \| To-Be 나란히) · UI 연결 (T-code일 때) · 사용처 (같은 패키지 CDS) · 관리 정보 |
| Value Help | VH 이름 / 등록번호 | 구현 방식, 모듈, 담당자 | 기본 정보 · 데이터 소스(표) · 테스트 · 관리 정보 |
| OData 서비스 | Service Binding / 등록번호 | 모듈, 담당자 | 기본 정보 · 테스트 · 관리 정보 |
| 기술부채 | 개발 오브젝트 / ID | Debt Level, 개선상태, 업무담당자 | 대상 오브젝트 · 비released 사용(비released 사용 내역) · 판단·개선 · 관리 정보 |

헤더는 요약이라 같은 필드가 섹션에도 있다. 그래서 **manifest에서 Object Page마다 `editableHeaderContent: false`** 로 둔다 (안 그러면 편집 모드에서 헤더에도 입력칸이 생겨 같은 필드가 두 번 나온다).

### 앱 (manifest)

`09_app/manifest.routing.sample.json`은 Fiori 생성기(List Report, 서비스 `ZUI_CMSM_DEVOBJ`, 메인 엔티티 `Request`)로 만든 앱의 `sap.ui5.routing`을 바꿔 넣는 예시.

- List Report 하나에 탭 5개 (`views.paths`, 탭마다 `entitySet`), 탭별 건수 표시
- 탭마다 상세 화면 route (`navigation`)
- 변경 이력·데이터 소스 행은 상세로 안 넘어간다 (route 없음). 데이터 소스는 표에서 바로 추가 (`creationMode: Inline`)
- 필터바는 탭 전체가 하나를 쓴다 (메인 엔티티 `Request` 기준). 모듈은 다섯 엔티티 모두 같은 이름이라 공통으로 걸리고, 나머지 필터는 그 필드가 있는 탭에만 해당. 탭마다 필터를 따로 두려면 FPM 커스텀 페이지로

## 요청 트랜잭션

### 상태 흐름

| 지금 상태 | 버튼 | 누가 | 다음 상태 | 조건 |
| --- | --- | --- | --- | --- |
| 요청 R | 접수 | 담당자 | 진행 중 I | |
| 진행 중 I | 완료 | 담당자 | 완료 C | 처리 내용이 저장돼 있어야 함. 완료일 = 오늘 |
| 요청 R / 진행 중 I | 반려 | 담당자 | 반려 J | 사유 입력 (팝업) |
| 요청 R | 요청 취소 | 요청자 | 취소 X | 사유 입력 (팝업) |

- 버튼은 목록 툴바(행 선택)와 상세 화면 헤더에 있다. 조건이 안 맞으면 비활성
- 상태 변경은 저장된 건에서만 된다. 편집 중(드래프트)에는 버튼이 꺼진다
- 완료·반려·취소 후에는 수정·삭제 불가

### 누가 무엇을 고치나 (instance feature control)

| | 요청 R | 진행 중 I | 종료 C/J/X |
| --- | --- | --- | --- |
| 요청자 (`CreatedBy`) | 제목·요청 내용·모듈·담당자 수정, 삭제 | 읽기 | 읽기 |
| 담당자 (`Assignee`) | 읽기 | 처리 내용·관련 등록번호 수정 | 읽기 |
| 그 외 | 읽기 | 읽기 | 읽기 |

제목·모듈·담당자는 수정 가능할 때 필수 표시. 상태·사유·완료일은 항상 읽기 전용(액션으로만 바뀜).

### 자동 처리

| 이름 | 시점 | 내용 |
| --- | --- | --- |
| `setInitialValues` | 생성 | 상태 = R |
| `setReqId` | 저장 (생성) | 요청번호 RQ-nnnn 채번 (`ZCL_CMSM_DISPLAY_ID`). 실패하면 경고만 내고 번호 없이 저장 |
| `recordHistory` | 저장 | 생성 C 1줄 / 상태 변경 S (반려·취소면 사유를 '사유'에) / 제목·요청 내용·모듈·담당자·처리 내용·관련 등록번호 수정 U. 긴 텍스트는 1333자에서 자름 |
| `validateMandatory` | 저장, Prepare | 제목·모듈·담당자 필수 |

### 만드는 순서

1. **번호 범위 오브젝트** (SNRO)
   - 오브젝트 `ZCMSM_DOID`, 번호 길이 도메인은 NUMC 도메인 아무거나 (예: 길이 10)
   - 구간: `01` 요청 1–9999 / `02` 매핑 / `03` Value Help / `04` OData 서비스 (각 1–9999) / `05` 기술부채 1–999
   - 구간은 이관이 안 되니 시스템마다 만든다
2. `ZA_CMSM_CloseReason` (abstract entity, `03_root`) 활성화
3. `ZCL_CMSM_DISPLAY_ID` (`06_class`) 활성화
4. `ZR_CMSM_Req` BDEF 교체 → 클래스 `ZBP_R_CMSM_REQ` 로컬 핸들러 교체 → 같이 활성화
5. `ZC_CMSM_Req` BDEF 교체 → 활성화
6. MDE `ZC_CMSM_Req` 교체 → 활성화 (버튼 추가)
7. 앱 새로고침. 이미 만든 요청은 요청번호가 비어 있으니 테스트 데이터는 지우고 새로 만든다

## 매핑 트랜잭션

### 입력 규칙 (instance feature control + 검증)

| 조건 | 열리는 칸 (필수 = *) | 잠기고 비워지는 칸 |
| --- | --- | --- |
| 구분 = 매핑 (기본값) | 소스 시스템*, As-Is 유형*, As-Is 오브젝트* | |
| 구분 = 신규 | | 소스 시스템, As-Is 유형, As-Is 오브젝트 |
| To-Be 유형 = T-code | UI 종류* | |
| To-Be 유형 ≠ T-code | | UI 종류, URI, Fiori 앱 ID, Semantic Object-Action, React 앱 이름 |
| UI 종류 = Fiori | Semantic Object-Action*, Fiori 앱 ID, URI | React 앱 이름 |
| UI 종류 = React | React 앱 이름*, URI* | Fiori 앱 ID, Semantic Object-Action |
| UI 종류 = WebGUI | URI | Fiori 앱 ID, Semantic Object-Action, React 앱 이름 |

항상 필수: 구분, To-Be 유형, To-Be 오브젝트, 모듈.

### 자동 처리·검증

| 이름 | 시점 | 내용 |
| --- | --- | --- |
| `setInitialValues` | 생성 | 구분 = 매핑, 담당자 = 등록한 사람 |
| `clearUnusedFields` | 구분·To-Be 유형·UI 종류 변경 | 위 표의 "잠기고 비워지는 칸"을 비움. side effects로 화면에 바로 반영 |
| `setMapId` | 저장 (생성) | MP-nnnn 채번 (번호 범위 구간 02) |
| `validateMandatory` | 저장, Prepare | 위 표의 필수 |
| `validateObjectType` | 저장, Prepare | As-Is 유형은 `ZI_CMSM_AsisTypeVH`(RFC·FM·PROXY·TABLE·TCODE·CLASS·CDS), To-Be 유형은 `ZI_CMSM_TobeTypeVH`(VH·SRVB 제외)에 있는 값만. 드롭다운도 같은 뷰 |
| `validateDuplicate` | 저장, Prepare | 구분·소스 시스템·As-Is 유형·As-Is·To-Be 유형·To-Be가 모두 같은 저장된 매핑이 있으면 에러 (N:1, 1:N은 허용) |

수정·삭제는 누구나 가능 (요청처럼 사람별 제한 없음).

### 만드는 순서

1. 번호 범위 `ZCMSM_DOID` 구간 `02`가 있는지 확인
2. `ZI_CMSM_AsisTypeVH`, `ZI_CMSM_TobeTypeVH` (`01_vh`) 새로 만들고 활성화
3. `ZC_CMSM_Map` (`04_projection`) — As-Is·To-Be 유형 VH 이름 두 줄 교체
4. `ZR_CMSM_Map` BDEF 교체 → `ZBP_R_CMSM_MAP` 로컬 핸들러 교체 → 같이 활성화
5. `ZC_CMSM_Map` BDEF 교체 (`use side effects;` 추가) → 활성화
6. side effects에서 문법 에러가 나면 (S/4 버전에 따라 미지원) BDEF의 `side effects { … }` 블록과 프로젝션의 `use side effects;`를 지운다. 그러면 비워진 값과 잠금 상태는 저장 후 다시 열 때 반영된다

## Value Help 트랜잭션

| 이름 | 시점 | 내용 |
| --- | --- | --- |
| `setInitialValues` | 생성 | 담당자 = 등록한 사람 |
| `detectVhImpl` | 생성, VH 이름 변경 | 구현 방식 자동 판별: CDS(데이터 정의)면 C, Search Help면 S, 못 찾으면 빈 값. side effects로 바로 표시 |
| `setTestInfo` | 테스트 파일 올림·삭제 | 올린 사람·일시 채움 / 파일 지우면 비움 |
| `setVhId` | 저장 (생성) | VH-nnnn 채번 (번호 범위 구간 03) |
| `validateMandatory` | 저장, Prepare | VH 이름·모듈·담당자 필수 (BDEF `field ( mandatory )`. `mandatory : create`는 FE 생성에서 'was not provided' 에러가 나서 안 씀) |
| `validateVhName` | 저장, Prepare | 같은 시스템 ID·같은 VH 이름이 이미 저장돼 있으면 에러. 시스템에 없는 VH(CDS·Search Help 둘 다 못 찾음)도 에러 — 개발(활성화)한 뒤 등록 |
| `validateTestFile` | 저장, Prepare | 테스트 파일 10MB 초과 에러 |
| `ValueHelpSource~validateSource` | 저장, Prepare | 데이터 소스 유형·이름 필수 (메시지는 VH 화면 데이터 소스 행에 표시) |

구현 방식 판별 (`detect_impl` 메서드 하나에 모아 둠)
- CDS: XCO `xco_cp_abap_repository=>object->ddls->for( 이름 )->exists( )`
- Search Help: released 뷰 `I_CustABAPObjDirectoryEntry` (고객 오브젝트 TADIR)에서 SHLP 조회. 이 뷰가 없거나 권한으로 막히면 S 판별만 안 되고 나머지는 동작. 이 메서드만 고치면 된다
- `validateVhName`의 존재 확인도 이 메서드를 쓴다. Search Help 조회를 지우면 Search Help VH는 등록이 막힌다

VH 이름 입력: `ZI_CMSM_SysVhVH` (`01_vh`) 값 도움말
- `I_CustABAPObjDirectoryEntry`에서 Z로 시작하고 이름에 `_VH_`가 들어간 DDLS + Search Help(SHLP) (`like 'Z%#_VH#_%' escape '#'`). 이름 규칙이 다르면 where만 고친다
- 이미 VH 탭에 등록된 건 '등록번호'가 같이 보인다
- 화면에서는 목록에서 고르고, 업로드 등 화면 밖 입력은 `validateVhName`이 막는다

### 만드는 순서

1. 번호 범위 `ZCMSM_DOID` 구간 `03` 확인
2. `ZR_CMSM_Vh` BDEF 교체 → `ZBP_R_CMSM_VH` 로컬 핸들러 교체 (부모·자식 핸들러 둘 다) → 같이 활성화
3. `ZC_CMSM_Vh` BDEF 교체 (`use side effects;` 추가) → 활성화
4. `setTestInfo`·`validateTestFile` 트리거에 `TestFile`(RAWSTRING)이 있다. 활성화 에러가 나면 트리거에서 `TestFile`을 빼고 `TestFileName`만 남긴다 (side effects의 `field TestFile`도 같이)

## OData 서비스 트랜잭션

| 이름 | 시점 | 내용 |
| --- | --- | --- |
| `setInitialValues` | 생성 | 담당자 = 등록한 사람 |
| `setTestInfo` | 테스트 파일 올림·삭제 | 올린 사람·일시 채움 / 파일 지우면 비움 |
| `setSbId` | 저장 (생성) | SB-nnnn 채번 (번호 범위 구간 04) |
| `validateMandatory` | 저장, Prepare | Service Binding·모듈 필수 |
| `validateSrvbName` | 저장, Prepare | 같은 시스템 ID·같은 바인딩이 이미 있으면 에러 / 시스템에 없는 바인딩도 에러 (`I_CustABAPObjDirectoryEntry`, 유형 SRVB) |
| `validateTestFile` | 저장, Prepare | 테스트 파일 10MB 초과 에러 |

Service Binding 입력: `ZI_CMSM_SysSrvbVH` (`01_vh`) — Z로 시작하는 SRVB 목록, 이미 등록된 건 등록번호 표시.

모듈 자동 입력: VH 목록에 이름에서 뽑은 모듈 칸이 있고(Z 다음부터 첫 `_` 앞까지, 2·3글자 — `ZCM_0000` → CM, `ZEWM_01` → EWM), VH에서 바인딩을 고르면 `additionalBinding`으로 모듈에 들어간다. 모듈 고정값에 있는지는 보지 않는다(`ZUI_…` → UI). 모듈은 그 뒤에 사용자가 바꿀 수 있다.

테스트 데이터: 시스템에 있는 Z 서비스 바인딩을 앞에서부터 최대 5개 골라 SB-T001~ 이름으로 쓴다 (모자라면 나머지는 예시 이름 — 그 행은 수정 후 저장하면 존재 검증에 걸린다).

### 만드는 순서

1. 번호 범위 `ZCMSM_DOID` 구간 `04` 확인
2. `ZI_CMSM_SysSrvbVH` (`01_vh`) 새로 만들고 활성화
3. `ZC_CMSM_Sb` (`04_projection`) — Service Binding VH 한 줄 추가
4. `ZR_CMSM_Sb` BDEF 교체 → `ZBP_R_CMSM_SB` 로컬 핸들러 교체 → 같이 활성화
5. `ZC_CMSM_Sb` BDEF 교체 (`use side effects;` 추가) → 활성화
6. (선택) `ZCL_CMSM_TEST_DATA` 교체 후 F9

## 기술부채 트랜잭션

### 입력 규칙

| 조건 | 열리는 칸 (필수 = *) | 잠기고 비워지는 칸 |
| --- | --- | --- |
| Debt Level = C (비released 사용) | 래핑 여부* | |
| Debt Level = D (표준 수정·금지) | | 래핑 여부 |
| 개선상태 = E (예외등록) | 부채판단 사유* | |

항상 필수: 모듈, 오브젝트 유형, 개발 오브젝트, 비released 사용 내역, Debt Level.

개발 오브젝트당 한 건. 쓰는 비released 오브젝트는 '비released 사용 내역'(`DebtDesc`, 전 'Technical Debts')에 적는다 — 툴팁에 입력 예시, 검색 대상. '부채판단 사유'는 라벨을 '판단 사유·개선 계획'으로 바꿨다. (비released 대상 유형·이름 필드 2개, 대상 유형 VH, 복사 버튼은 삭제)

### 자동 처리·검증

| 이름 | 시점 | 내용 |
| --- | --- | --- |
| `setInitialValues` | 생성 | 개선상태 = 개선대상(T) |
| `clearWrapType` | Debt Level 변경 | C가 아니면 래핑 여부 비움 (side effects로 바로 반영) |
| `setDebtId` | 저장 (생성) | TD-nnn 채번 (번호 범위 구간 05) |
| `validateMandatory` | 저장, Prepare | 위 필수 + 조건부 필수 |
| `validateDevObj` | 저장, Prepare | 개발 오브젝트가 시스템에 있는지 (`I_CustABAPObjDirectoryEntry`). 유형 → CLASS=CLAS, TABLE=TABL, CDS=DDLS, BO=BDEF, ACTION=BDEF(BO 부분만), VH=DDLS/SHLP, SRVB=SRVB, TCODE=TRAN. FM·RFC·PROXY는 확인 안 함 |
| `validateDuplicate` | 저장, Prepare | 같은 유형·같은 개발 오브젝트의 부채가 이미 있으면 에러 (기존 건의 사용 내역에 추가하라고 안내) |

개발 오브젝트 입력: `ZI_CMSM_DevObjectVH` — 통합 목록 `ZI_CMSM_DevObject`(`02_interface`, 딕셔너리의 오브젝트 UNION 뷰)에서 As-Is를 뺀 것. 통합 목록의 등록 구분(`SourceTab`): TOBE(매핑 To-Be) / ASIS(매핑 As-Is, 신규 매핑은 없음) / VH / SB / TD(기술부채, 부채마다 한 줄). 매핑 한 건은 TOBE·ASIS 두 줄이고 등록번호가 같다. 시스템 칸은 ASIS면 소스 시스템, 나머지는 타겟·등록 시스템. 기술부채 줄의 '설명'은 설계서 개발 ID. 고르면 오브젝트 유형·모듈도 채워진다 (`additionalBinding`). 어디에도 없는 오브젝트는 직접 입력.

### 만드는 순서

1. 번호 범위 `ZCMSM_DOID` 구간 `05` 확인 (1–999)
2. `ZI_CMSM_DevObject` (`02_interface`) 새로 만들고 활성화
3. `ZC_CMSM_Debt` (`04_projection`) — 개발 오브젝트 VH 추가
4. `ZR_CMSM_Debt` BDEF 교체 → `ZBP_R_CMSM_DEBT` 로컬 핸들러 교체 → 같이 활성화
5. `ZC_CMSM_Debt` BDEF 교체 (`use side effects;` 추가) → 활성화
6. (선택) `ZCL_CMSM_TEST_DATA` 교체 후 F9 — 기술부채 개발 오브젝트를 이 프로그램의 실제 오브젝트로 바꿈

## 통합 조회 탭

| 오브젝트 | 내용 |
| --- | --- |
| `ZI_CMSM_SourceTabVH` (`02_interface`) | 등록 구분 텍스트·드롭다운 (TOBE 매핑 To-Be / ASIS 매핑 As-Is / VH / SB OData 서비스 / TD 기술부채). 데이터가 있는 구분만 |
| `ZC_CMSM_DevObject` (`04_projection`) | `ZI_CMSM_DevObject` 위 읽기 전용 C 뷰. 모듈·유형·시스템·등록 구분 텍스트, 검색(등록번호·개발 오브젝트·설명) |
| `ZC_CMSM_DevObject` MDE (`08_mde`) | 목록: 등록 구분, 등록번호, 개발 오브젝트, 유형, 시스템, 모듈, 설명 / 필터: 등록 구분, 모듈, 유형, 시스템 / 정렬: 오브젝트 이름 → 구분 / 탭 variant `#Tab` "통합 조회" |
| 서비스 정의 | `expose ZC_CMSM_DevObject as DevObject;` 추가 |
| manifest | `views.paths`에 `{ "key": "all", "entitySet": "DevObject", … }` + `navigation.DevObject` + 상세 route `DevObjectObjectPage` |

저장된 건만 나온다 (UNION 뷰가 활성 테이블을 읽음). 편집 중인 드래프트는 저장 후 보인다.

### 통합 조회 상세 화면 (읽기 전용)

- UNION 뷰에 공통 컬럼 추가: 담당자(기술부채는 업무담당자), 오브젝트 생성자, 요청번호, 등록자·등록 일시·최종 변경자·최종 변경 일시
- `ZC_CMSM_DevObject`가 원본 탭 I 뷰에 `[0..1]` 연관 (`_Map` / `_Vh` / `_Sb` / `_Debt`, `SourceUuid` 기준)을 걸고 상세 필드를 경로 필드로 꺼낸다. TOBE·ASIS는 둘 다 `_Map`
- 섹션: 기본 정보 · 매핑 · UI · 테스트 · 기술부채 · 관리 정보 (MDE)
- 행마다 해당 없는 섹션 숨김: C 뷰에서 `CASE`로 `MapHidden` / `UiHidden`(T-code 매핑만) / `TestHidden`(VH·SB) / `DebtHidden`(TD) 계산 → 앱 `annotation.xml`의 `UI.Facets`에서 섹션마다 `UI.Hidden Path`로 연결 (`09_app/annotation.devobject.sample.xml`). 이 XML이 백엔드 섹션 정의를 대신하므로 섹션을 바꾸면 MDE와 XML 둘 다 고친다. XML이 없으면 섹션이 전부 보일 뿐 화면은 동작
- 고치는 건 원래 탭에서 (이 화면은 Edit 없음)


### 관련 요청 섹션 (custom section)

통합 조회 상세의 '관련 요청' 섹션 (기술부채 뒤). 요청번호 / 상태 / 제목 / 요청 내용을 세로로 보여 준다 (읽기 전용).

| 오브젝트 | 내용 |
| --- | --- |
| `09_app/ext/fragment/DevObjectRequest.fragment.xml` | 윗줄 '요청번호 : …' \| '상태 : …' — `Grid` 칸 두 개(`XL3 L3 M6 S12`, 칸 폭 고정이라 열이 맞음. HBox는 내용 폭대로라 들쭉날쭉), 아래 제목·요청 내용 세로. 상태는 `ObjectStatus`(완료 초록·반려 빨강·취소 주황·진행 중 파랑), 요청 내용은 전체 폭·줄바꿈 유지. 요청이 없으면(`ReqHidden`) '연결된 요청이 없습니다.' |
| manifest `DevObjectObjectPage` | `content.body.sections.ReqSection` — `template` `<앱 ID>.ext.fragment.DevObjectRequest`, 제목 '관련 요청', 위치 `After` `Debt` |
| `ZC_CMSM_DevObject` | `association [0..1] to ZI_CMSM_Req as _Req on $projection.ReqId = _Req.ReqId` + `ReqStatus`·`ReqStatusText`·`ReqText`, 숨김 플래그 `ReqHidden`. 제목은 기존 `ReqTitle` |
| MDE `ZC_CMSM_DevObject` | '관련 요청' facet·필드그룹 없음 (custom section이 대신). 위 필드와 `ReqId`는 `@UI.hidden` — 화면 바인딩엔 그대로 쓰인다 |
| 앱 annotation.xml (쓰는 경우) | `Req` Record를 넣었다면 뺀다 (안 빼면 섹션이 두 번) |

- 요청은 저장된 것만 연결된다 (드래프트 아님)

## 요청 생성 알림 메일

새 요청이 저장되면 담당자에게 메일을 보낸다.

| 항목 | 내용 |
| --- | --- |
| 시점 | BDEF `managed with additional save with full data` → saver `lsc_zr_cmsm_req`의 `save_modified` (`ZBP_R_CMSM_REQ` 로컬 타입 맨 아래). 저장이 확정된 뒤 한 번만 돈다. `setReqId`가 먼저 채번해서 요청번호가 들어간다 |
| 대상 | 이번 저장에서 새로 생긴 요청(`create-request`), 담당자가 있는 것만 |
| 메일 주소 | `ZCM_VH_USER_EMAIL` (`get_email` 메서드의 SELECT — 필드명 `userid`·`emailaddress`는 가정, 다르면 여기만 고친다) |
| 본문 | SMW0 `ZCMSM_REQ_CREATED_MAIL` ← `10_mail/zcmsm_req_created_mail.html` (UTF-8). `ZCL_HTML_TEMPLATE`로 요청번호·제목·모듈·요청자·담당자·요청 일시·요청 내용·링크를 채운다 (값은 HTML 이스케이프, 요청 내용 줄바꿈은 CSS `pre-wrap`) |
| 발송 | `CL_BCS_MAIL_MESSAGE` (HTML). 보내는 사람 `gc_mail_sender`, 앱 링크 `gc_app_url` 상수를 시스템에 맞게 바꾼다. PCE에서는 SCOT(SMTP) 설정 필요 |
| 실패 | 메일 주소 없음·템플릿 없음·발송 실패여도 요청 저장은 그대로 |

`setReqId`(저장 시 determination)에 넣지 않은 이유: determination은 저장 검증보다 먼저 돌아서, 검증에 걸려 저장이 안 돼도 메일이 나가고 다시 저장하면 또 나간다. RAP는 determination 안에서 외부 발송 같은 동작을 막기도 한다.

## 매핑 상세 화면: As-Is | To-Be 나란히 (custom section)

FE 기본 폼(MDE 필드그룹)은 넓은 화면에서 칸을 3~4개로 잡는다. 필드그룹이 2개(As-Is·To-Be)뿐이면 한 그룹이 칸 여러 개를 차지해서 필드가 옆으로 퍼진다. 컬렉션을 3단으로 둬도 칸 수는 못 바꾼다. 그래서 매핑 섹션은 custom section으로 2칸 폼을 직접 만든다.

| 오브젝트 | 내용 |
| --- | --- |
| `09_app/ext/fragment/Mapping.fragment.xml` | `sap.ui.layout.Grid` 두 칸 (`XL6 L6 M6 S12`, 폰은 한 칸) + 칸마다 `VBox`에 `Label` / `macros:Field`를 위아래로: As-Is·To-Be 각각 시스템 / 유형 / 오브젝트. (처음엔 `Form` + `ColumnLayout` 2칸이었는데 칸 하나가 두 열로 퍼져서 '시스템·유형 \| 오브젝트'로 나와 바꿈) |
| manifest `MappingObjectPage` | `content.body.sections.MapSection` — `template` `<앱 ID>.ext.fragment.Mapping`, 제목 '매핑', 위치 `After` `General` |
| MDE `ZC_CMSM_Map` | `Mapping`·`MappingSub`·`AsIs`·`ToBe` facet과 As-Is·To-Be `fieldGroup` 항목을 뺀다 (안 빼면 두 번 나옴) |

- 섹션 순서: 기본 정보 → 매핑(custom) → UI 연결 (T-code일 때) → 사용처 (같은 패키지 CDS) → 관리 정보
- `macros:Field`라서 수정 권한(구분이 신규면 As-Is 잠김)·값 도움말·텍스트 표시가 기본 폼과 같다
- 필수 별표는 라벨 `required`로 직접: As-Is 세 칸 = 편집 중 + 구분 ≠ 신규(`N`), To-Be 유형·오브젝트 = 편집 중이면 항상 (`ui>/isEditable`). 필수 검증 자체는 BO validation 그대로
- 구분(`MapKind`)은 기본 정보 맨 위
- 폰처럼 좁으면 두 칸이 위아래로 내려간다

## To-Be 데이터 소스 (최하위까지, custom entity + XCO)

매핑 상세의 'To-Be 데이터 소스' 섹션. To-Be CDS의 메인 데이터 소스(`select from`)를 XCO로 읽고, 그게 CDS면 또 그 CDS의 메인 소스를… 테이블이 나올 때까지 따라 내려간다 (최대 10단계, 순환이면 멈춤). 예: `ZC_…` → `ZR_…` → `ZI_…` → `ZTABLE`.

| 오브젝트 | 내용 |
| --- | --- |
| `ZCE_CMSM_TobeSource` (`04_projection`) | custom entity: 단계, 유형(CDS / 테이블 / 테이블·기타 / 도메인 고정값), 이름, 읽는 오브젝트. 키 = To-Be 이름 + 순번(숨김) |
| `ZCL_CMSM_TOBESRC_QUERY` (`06_class`) | 쿼리 클래스. 로직은 `select` 하나에 (필터 `TobeName` → `DO 10 TIMES` 메인 소스 따라가기 → 페이징) |
| `ZC_CMSM_Map` | `association [0..*] to ZCE_CMSM_TobeSource as _TobeSource on $projection.TobeName = _TobeSource.TobeName` + 노출 |
| 서비스 정의 | `expose ZCE_CMSM_TobeSource as MappingSource;` |
| MDE `ZC_CMSM_Map` | 섹션 `{ id: 'TobeSrc', type: #LINEITEM_REFERENCE, label: 'To-Be 데이터 소스', targetElement: '_TobeSource', position: 35 }` |

- 메인 소스만 따라간다. join 대상·연관은 안 나온다 (XCO가 join을 안 준다)
- view entity가 아닌 CDS(DDIC 기반 `define view`)에서 멈춘다
- 표준 SAP 오브젝트: ABAP Cloud에서 안 보이는 것(릴리즈 안 된 뷰·테이블)은 이름까지만 나오거나(`테이블·기타`) 거기서 멈춘다. 예: `I_Product`가 `select from mara`면 `MARA`는 이름은 나오지만 릴리즈 안 된 테이블이라 유형은 `테이블·기타`
- To-Be가 CDS가 아니면 빈 표. As-Is는 다른 시스템(ECC) 오브젝트라 못 읽는다

## To-Be 사용처 (같은 패키지 CDS, custom entity + XCO)

매핑 상세의 '사용처 (같은 패키지 CDS)' 섹션. To-Be 오브젝트와 **같은 패키지의 CDS만** 열 때 XCO로 읽어서, To-Be를 데이터 소스(`select from`)나 연관 대상으로 쓰는 CDS를 보여준다 (저장 안 함).

범위를 좁힌 이유: ABAP Cloud에는 where-used 릴리즈 API가 없어서, 누가 쓰는지 알려면 후보 CDS를 하나씩 XCO로 읽어야 한다. 시스템 Z CDS 전부(1만 개 이상)를 읽으면 화면이 너무 늦게 뜬다. 배치 잡으로 미리 쌓는 방법도 있지만 쓰지 않기로 했다. 같은 앱의 R·C·VH 뷰는 보통 같은 패키지라 수십 개만 읽으면 된다.

| 오브젝트 | 내용 |
| --- | --- |
| `ZCE_CMSM_TobeUsage` (`04_projection`) | custom entity: 사용하는 CDS, 사용 방식(데이터 소스 / 연관 / 데이터 소스·연관). 키 = To-Be 이름(숨김) + 사용하는 CDS |
| `ZCL_CMSM_TOBEUSE_QUERY` (`06_class`) | 쿼리 클래스. 로직은 `select` 하나에: 필터 `TobeName` → `I_CustABAPObjDirectoryEntry`에서 To-Be의 패키지(DDLS·TABL만) → 같은 패키지 DDLS → XCO로 메인 소스·연관 대상 → 페이징 |
| `ZC_CMSM_Map` | `association [0..*] to ZCE_CMSM_TobeUsage as _Usage on $projection.TobeName = _Usage.TobeName` + 노출 |
| 서비스 정의 | `expose ZCE_CMSM_TobeUsage as MappingUsage;` |
| MDE `ZC_CMSM_Map` | 섹션 `{ id: 'Usage', type: #LINEITEM_REFERENCE, label: '사용처 (같은 패키지 CDS)', targetElement: '_Usage' }` |

- 못 찾는 것: 다른 패키지에서 쓰는 곳, join 대상, view entity가 아닌 CDS(DDIC 기반 `define view`, custom entity 등), 컴포지션 대상
- To-Be가 클래스·FM·T-code거나 표준 오브젝트(고객 오브젝트 목록에 없음)면 빈 표
- CDS 하나를 못 읽어도(비활성 등) 건너뛰고 계속 본다
- 범위를 넓히고 싶으면 3)의 `ABAPPackage = @lv_package`를 패키지 앞부분 `LIKE` 조건(예: `ZFI%`)으로 바꾼다. 넓힐수록 느려진다

배치 잡 버전(`ztcmsm00250`, `ZI_CMSM_CdsUsage`, `ZCL_CMSM_USAGE_JOB`)은 뺐다. 시스템에 만들었다면 지운다.

시험: 서비스 바인딩 Preview에서 MappingUsage를 `TobeName eq 'ZR_CMSM_REQ'` 필터로 열면 같은 패키지의 `ZC_CMSM_Req`(데이터 소스), `ZR_CMSM_ReqHist`(연관) 등이 나와야 한다.

## VH 데이터 소스 (자동, custom entity + XCO)

VH 상세의 '데이터 소스 (자동)' 섹션. VH 이름의 CDS view entity 정의를 열 때마다 XCO로 읽는다 (저장 안 함). 손으로 넣는 '데이터 소스' 표는 그대로 둠 — 자동 결과가 쓸 만하면 그때 손 입력 표를 뺀다.

| 오브젝트 | 내용 |
| --- | --- |
| `ZCE_CMSM_VhSource` (`04_projection`) | custom entity: 유형(CDS/테이블/도메인 고정값/확인 불가), 이름. 키 = VH 이름 + 순번(둘 다 숨김, 행마다 키가 달라야 해서 순번). 메인 소스 먼저, 같은 이름은 한 번만. UI 어노테이션 포함 |
| `ZCL_CMSM_VHSRC_QUERY` (`06_class`) | 쿼리 클래스. 로직은 `select` 하나에 (필터 `VhName` → XCO로 메인 소스·연관 대상 → 유형 → 페이징) |
| `ZC_CMSM_Vh` | `association [0..*] to ZCE_CMSM_VhSource as _SysSource on $projection.VhName = _SysSource.VhName` + 노출 |
| 서비스 정의 | `expose ZCE_CMSM_VhSource as ValueHelpSystemSource;` |
| MDE `ZC_CMSM_Vh` | 섹션 `{ id: 'SysSrc', type: #LINEITEM_REFERENCE, targetElement: '_SysSource' }` |

XCO로 읽는 것 (SAP abap-cheat-sheets 예제로 확인한 API)
- 연관 대상: `xco_cp_cds=>view_entity( 이름 )->associations->all->get( )` → `assoc->content( )->get( )-target`
- 소스 유형: `xco_cp_abap_repository=>object->ddls->for( )->exists( )` = CDS, `xco_cp_abap_dictionary=>database_table( )->exists( )` = 테이블, `DDCDS_CUSTOMER_DOMAIN_VALUE*` = 도메인 고정값
- 메인 소스: `view_entity( )->content( )->get( )` 결과에서 `DATA_SOURCE` 항목을 동적으로 찾는다 (항목 이름이 XCO 버전마다 달라 컴파일 에러 대신 빈 값이 되게). 메인 소스가 비어 나오면 ADT에서 `content( )->get( )-` 뒤 Ctrl+Space로 항목 이름을 확인해서 `select` 안 `lt_component` 후보 목록에 넣는다

도메인 고정값 VH(`DDCDS_CUSTOMER_DOMAIN_VALUE( p_domain_name: '…' )`)는 엔터티 이름 대신 **도메인 이름**을 보여 준다 — XCO `DATA_SOURCE-PARAMETERS[]-VALUE`(식 오브젝트, `IF_XCO_DDL_EXPRESSION`)를 공개 인터페이스 `IF_XCO_TEXT`로 캐스트해서 `get_lines( )->value`(DDL 텍스트), 따옴표 제거. (`MV_VALUE`는 비공개, 실제 클래스는 릴리즈 안 돼서 RTTI 불가) 못 읽으면 엔터티 이름 그대로.

못 읽는 것: join 대상, Search Help VH, DDIC 기반 CDS 뷰(`define view`). 표준 테이블은 XCO가 존재 확인을 못 하면 '확인 불가'.

시험: 서비스 바인딩 Preview에서 ValueHelpSystemSource를 `VhName eq 'ZI_CMSM_REQVH'` 필터로 열거나, 앱 VH 상세의 '데이터 소스 (자동)' 표.

## 요청: 새로 만들 때 '처리' 섹션 숨김

- MDE `ZC_CMSM_Req`의 `Process` 섹션에 `hidden: #( ProcessHidden )` (CDS 문법은 SAP abap-platform-fiori-feature-showcase `#HidingContent` 기준)
- `ProcessHidden`: `ZC_CMSM_Req`의 가상 필드(`virtual … : abap_boolean`), 계산 클래스 `ZCL_CMSM_REQ_CALC` — 요청번호가 비어 있으면(저장 전 = 새로 만드는 중) X
- `IsActiveEntity`로 숨기면 기존 요청 편집(담당자가 처리 내용 입력) 때도 숨겨져서 쓰지 않음
- BDEF는 그대로 (feature control은 잠금·필수만, 숨김은 UI 어노테이션)

## 요청 내용 custom section

`09_app/ext/fragment/Request.fragment.xml` — 제목(섹션 폭 50%)·요청 내용(전체 폭)을 세로로 쌓는 `macros:Field`. manifest `template`: `<앱 ID>.ext.fragment.Request`. MDE에서 두 필드의 `Request` fieldGroup 항목은 뺀다.

## 기술부채 부채 구분 (도메인)

도메인 `ZDO_DM_DEBT_CAT` CHAR 4 고정값 → VH `ZI_CMSM_DebtCatVH` (`01_vh`).

| 값 | 내역 | 권장 Debt Level |
| --- | --- | --- |
| TAB | 미릴리즈 테이블 조회 | C |
| TABW | 표준 테이블 직접 변경 | D |
| CDS | 미릴리즈 CDS | C |
| FM | 미릴리즈 함수 모듈 (BAPI 외) | C |
| BAPI | BAPI 호출 | C (SAP Clean Core 기준으로는 classic API = B) |
| CLAS | 미릴리즈 클래스·인터페이스 | C |
| BDC | BDC (CALL TRANSACTION·배치 인풋) | C |
| EXIT | User Exit·암시적 확장 | D |
| MOD | 표준 수정 (Modification) | D |
| ETC | 기타 | — |

## 엑셀 업로드 템플릿 (`11_excel`)

탭마다 파일 하나: `ZCMSM_업로드_1_요청` / `2_매핑` / `3_ValueHelp` / `4_OData서비스` / `5_기술부채` (.xlsx). 업로드 기능은 아직 없음 — 이 템플릿 기준으로 만든다.

| 시트 | 내용 |
| --- | --- |
| 업로드 | 1행 = 컬럼명 (필수 `*` 노랑, 조건부 `(*)` 주황, 선택 회색, 머리글 메모에 규칙·예시), **2행 = 필드명 (CDS 요소 이름, 업로드 프로그램이 칸을 찾는 키)**, 3~502행 = 데이터. 데이터 칸은 텍스트 서식, 코드 칸은 드롭다운, 글자 수 제한 |
| 작성 안내 | 작성 방법, 색 범례, 칸 설명 (필수·형식·규칙·예시 — 예시 열이 한 건을 채운 예), 저장할 때 자동으로 채워지는 값, 주의할 점 |
| 코드값 | 드롭다운 원본 (딕셔너리 1차 도메인 고정값). 시스템 도메인과 다르면 여기 값을 고친다 |

엑셀에 없는 칸: UUID, 등록번호(번호 범위), 등록자·일시, 요청 상태·처리 칸(액션으로만), VH 구현 방식(자동), 테스트 파일(화면에서). 기술부채 '부채 구분'(`DebtCat`)은 필드를 테이블에 추가한 뒤 쓴다.

업로드 프로그램 쪽 규칙: 첫 시트 '업로드'의 2행 필드명으로 칸을 찾고(칸 순서 무관), 3행부터 빈 줄 전까지 읽는다. 값 검증은 BO validation을 그대로 태운다.

다시 만들기: `python3 11_excel/gen_excel_templates.py 11_excel` (openpyxl). 컬럼·코드값은 스크립트 맨 위 `CODES`, `TABS`에 있다.

## 엑셀 업로드 액션 (5개 탭)

목록 툴바 '엑셀 업로드' 버튼 → 파일 선택 팝업 → `uploadExcel` (static action). 템플릿은 `11_excel`.

| 오브젝트 | 내용 |
| --- | --- |
| `ZA_CMSM_UploadFile` (`03_root`) | 액션 입력 — **root** abstract entity: `Attachment`(rawstring, `@Semantics.largeObject`, xlsx만), `MimeType`, `FileName` |
| BDEF `ZA_CMSM_UploadFile` (`05_bdef`) | 추상 BDEF: `abstract; strict ( 2 ); with hierarchy;` + `with control`, `field ( mandatory : execute ) Attachment;` |
| BDEF R (5개) | `static action uploadExcel deep parameter ZA_CMSM_UploadFile;` — 그냥 `parameter`면 팝업에서 파일 칸이 텍스트 입력칸으로 나온다 |
| BDEF C (5개) | `use action uploadExcel;` |
| 핸들러 (5개) | `uploadexcel` 메서드 하나 (아래 순서) |
| MDE (5개) | 첫 목록 칸에 `{ type: #FOR_ACTION, dataAction: 'uploadExcel', label: '엑셀 업로드' }` |

`uploadexcel` 순서 (중복 체크만 — 단순하게)
1. `zcl_cm_common=>drm_decode` 로 DRM 풀기 → `zcl_cm_common=>convert_xlsx_to_itab_v2` 로 `ty_sheet_data` itab (템플릿 칸 순서 = 구조 순서). **시그니처는 가정** (`drm_decode( xstring )` 반환 xstring, `convert_xlsx_to_itab_v2( EXPORTING iv_xstring IMPORTING et_data )`, 1행부터 다 준다) — 다르면 이 두 문장만 고친다
2. 3행부터 한 줄씩 생성할 값을 만든다 (코드·이름은 대문자). 중복 키가 저장된 건이나 위쪽 행과 같으면 'n행: …' 에러 — 매핑: 구분/소스 시스템/As-Is 유형/As-Is/To-Be 유형/To-Be, VH: 시스템 ID/VH 이름, SB: 시스템 ID/Service Binding, 기술부채: 오브젝트 유형/개발 오브젝트. 요청은 중복 확인 없음
3. 에러가 하나라도 있으면 한 건도 안 올린다
4. 없으면 `MODIFY ENTITIES … IN LOCAL MODE CREATE` (활성 데이터, `%is_draft = off`). 필수·코드값·존재 확인과 채번·기본값은 저장할 때 BO가 한다 (그 메시지엔 행 번호가 없다). 성공 메시지('업로드 완료')는 업로드 때만 (화면 저장엔 건수 0이라 안 뜸) 액션이 아니라 saver `save_modified`에서 띄운다 — 액션 시점은 저장 검증 전이라 거기서 띄우면 검증에 걸릴 때 성공·실패가 같이 나온다. 액션은 Local Types 맨 위 `lcl_upload=>count`(핸들러·saver 공용 static 변수)에 건수만 남기고, 저장이 끝나면(검증 통과) saver가 `reported-%other`로 성공 메시지를 붙인다. 그래서 매핑·VH·SB·기술부채 BDEF도 `managed with additional save` + saver `lsc_zr_cmsm_*` (요청은 메일 saver에 추가)

- 요청 업로드는 줄마다 담당자 메일이 간다
- 기술부채 `debtcat`(부채 구분)은 BO에 필드가 생기면 `CREATE FIELDS`에 추가
- 파일 선택 팝업: root abstract entity + 추상 BDEF + `deep parameter` 조합이 필요하다 (PCE 2023 이상, 최근 UI5). 그래도 텍스트 칸이면 릴리스·UI5 버전 문제 — 프로젝트에서 이미 쓰는 업로드 방식(UI5 FileUploader 확장 등)에 맞추고 핸들러 로직은 그대로 쓴다
- DRM 걸린 파일이 형식(xlsx) 제한에 걸리면 `acceptableMimeTypes` 줄을 뺀다


### 업로드 뒤 목록 새로고침

static 액션은 RAP BDEF side effects를 못 건다 (트리거·대상 둘 다 불가). 앱 `annotation.xml`에 액션별 `Common.SideEffects`를 달고 `TargetEntities`를 엔터티셋 절대경로(`/…Container/Mapping` 등)로 주면, 액션이 끝난 뒤 그 목록을 다시 읽는다 — `09_app/annotation.upload-refresh.sample.xml` (탭 5개). 네임스페이스·컨테이너 이름은 `$metadata` 기준으로 맞춘다. 안 되면 리스트 리포트 컨트롤러 확장에서 액션 뒤 `refresh()`.

## 검색 (필터바 검색 칸)

탭 6개 C 뷰의 검색 대상(`@Search.defaultSearchElement`)에 모두 `@Search.fuzzinessThreshold: 0.8`. 통합 조회 `DevObj`에만 있을 땐 이름 일부(`ZCL_FI` 등)로 검색하면 통합 조회에만 결과가 나왔다. 값을 낮추면(0.7) 더 느슨하게, 높이면(0.9) 더 정확하게 찾는다.

