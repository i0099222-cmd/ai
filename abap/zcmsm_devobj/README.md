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
| `09_app` | Fiori 앱 manifest의 routing 예시 (탭 + 상세 화면) | 1 |

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
| 도메인 이름은 딕셔너리 이름 그대로 (`ZDO_DM_*`) | `01_vh` 각 VH 파일의 도메인 이름 2곳 |
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
| 기술부채 | ID, 모듈, 개발 오브젝트, 비released 대상, Debt Level, 래핑 여부, 개선상태, 업무담당자 | 모듈, Debt Level, 개선상태, 래핑 여부, 업무담당자 |

- 정렬: 등록 일시 내림차순. 탭마다 `@UI.selectionPresentationVariant` `#Tab` (탭 이름 포함)
- 고정값 코드(상태·모듈·유형 등)는 텍스트만 (`#TEXT_ONLY`), 사람·시스템은 "이름 (ID)"
- 텍스트 보조 필드(`…Text`, `…Name`)와 UUID, 마임 타입·파일명은 숨김 → 테이블 설정에서도 안 보인다

### 상세 화면 섹션

| 엔티티 | 제목 / 부제 | 헤더 | 섹션 |
| --- | --- | --- | --- |
| 요청 | 제목 / 요청번호 | 상태, 담당자, 요청자, 요청 일시 | 요청 내용 · 처리 · 변경 이력(표) · 관리 정보 |
| 매핑 | To-Be 오브젝트 / 등록번호 | 구분, 모듈, 담당자 | As-Is · To-Be · UI (T-code일 때) · 기본 정보 · 관리 정보 |
| Value Help | VH 이름 / 등록번호 | 구현 방식, 모듈, 담당자 | 기본 정보 · 데이터 소스(표) · 테스트 · 관리 정보 |
| OData 서비스 | Service Binding / 등록번호 | 모듈, 담당자 | 기본 정보 · 테스트 · 관리 정보 |
| 기술부채 | 개발 오브젝트 / ID | Debt Level, 개선상태, 업무담당자 | 대상 오브젝트 · 비released 사용 · 판단·개선 · 관리 정보 |

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
| `validateMandatory` | 저장, Prepare | VH 이름·모듈 필수 |
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

항상 필수: 모듈, 오브젝트 유형, 개발 오브젝트, 비released 대상 유형, 비released 대상, Debt Level.

### 자동 처리·검증

| 이름 | 시점 | 내용 |
| --- | --- | --- |
| `setInitialValues` | 생성 | 개선상태 = 개선대상(T) |
| `clearWrapType` | Debt Level 변경 | C가 아니면 래핑 여부 비움 (side effects로 바로 반영) |
| `setDebtId` | 저장 (생성) | TD-nnn 채번 (번호 범위 구간 05) |
| `validateMandatory` | 저장, Prepare | 위 필수 + 조건부 필수 |
| `validateDevObj` | 저장, Prepare | 개발 오브젝트가 시스템에 있는지 (`I_CustABAPObjDirectoryEntry`). 유형 → CLASS=CLAS, TABLE=TABL, CDS=DDLS, BO=BDEF, ACTION=BDEF(BO 부분만), VH=DDLS/SHLP, SRVB=SRVB, TCODE=TRAN. FM·RFC·PROXY는 확인 안 함 |
| `validateDuplicate` | 저장, Prepare | 같은 개발 오브젝트 + 같은 비released 대상(유형·이름)이 이미 있으면 에러 |
| `copyDebt` (버튼 "복사") | 목록 행 선택 / 상세 헤더 | 같은 개발 오브젝트가 비released 대상을 여러 개 쓸 때. 값을 복사한 새 부채(드래프트)로 이동 — 비released 대상 이름은 비움, 개선상태 = T, ID는 저장 시 새로 채번 |

비released 대상이 여러 개면 대상마다 한 건 (대상별로 대체 API 시점이 달라 개선상태를 따로 관리). 두 번째부터는 "복사"로 만든다.

개발 오브젝트 입력: `ZI_CMSM_DevObjectVH` — 통합 목록 `ZI_CMSM_DevObject`(`02_interface`, 딕셔너리의 오브젝트 UNION 뷰)에서 As-Is를 뺀 것. 통합 목록의 등록 구분(`SourceTab`): TOBE(매핑 To-Be) / ASIS(매핑 As-Is, 신규 매핑은 없음) / VH / SB / TD(기술부채, 부채마다 한 줄). 매핑 한 건은 TOBE·ASIS 두 줄이고 등록번호가 같다. 시스템 칸은 ASIS면 소스 시스템, 나머지는 타겟·등록 시스템. 기술부채 줄의 '설명'은 비released 대상 이름. 고르면 오브젝트 유형·모듈도 채워진다 (`additionalBinding`). 어디에도 없는 오브젝트는 직접 입력.

### 만드는 순서

1. 번호 범위 `ZCMSM_DOID` 구간 `05` 확인 (1–999)
2. `ZI_CMSM_DevObject` (`02_interface`) 새로 만들고 활성화
3. `ZC_CMSM_Debt` (`04_projection`) — 개발 오브젝트 VH 추가
4. `ZR_CMSM_Debt` BDEF 교체 → `ZBP_R_CMSM_DEBT` 로컬 핸들러 교체 → 같이 활성화
5. `ZC_CMSM_Debt` BDEF 교체 (`use side effects;` 추가) → 활성화
6. (선택) `ZCL_CMSM_TEST_DATA` 교체 후 F9 — 기술부채 개발 오브젝트를 이 프로그램의 실제 오브젝트로 바꿈
