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

- UI 어노테이션 → 메타데이터 익스텐션(MDE)
- 권한 → 지금은 전부 `#NOT_REQUIRED`. DCL 만들 때 C 뷰를 `#CHECK`로
- 액션, determination, validation (표시 번호 채번, 기본값, 상태 변경, 이력 기록 등)
- 서비스 바인딩 (ADT에서 `ZUI_CMSM_DEVOBJ` 우클릭 → OData V4 - UI)
- UNION 오브젝트 뷰, 기술부채 여부 뷰, SB 기능 목록 custom entity
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

- 표시 번호 채번 (RQ-/MP-/VH-/SB-/TD-) — 지금은 비어 있음. 그래서 `ZI_CMSM_ReqVH`(요청번호 VH)도 아직 비어 보인다
- 기본값: 요청 상태 `R`, 개선상태 `T`, 시스템 ID
- `DoneDate`, `VhImpl`, `TestBy`/`TestAt` 자동 채움
- 요청 이력 기록, 요청자/담당자별 필드 제어, 상태 변경 액션
- `mapping … corresponding;`에서 문법 에러가 나면 `corresponding { }` 형태로 바꾼다
