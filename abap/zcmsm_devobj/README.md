# 개발 오브젝트 통합관리 · CDS (I → R → C)

딕셔너리 1차 기준. 테이블 7+1개에 대해 인터페이스(I) → 루트 BO(R) → 프로젝션(C) 3단 구성.

## 폴더 = 활성화 순서

| 폴더 | 내용 | 개수 |
| --- | --- | --- |
| `01_vh` | 고정값 도메인 VH 12개, 사용자 VH, 시스템 ID | 14 |
| `02_interface` | `ZI_CMSM_*` 테이블 1:1 뷰 (라벨·텍스트용 연관) + 요청번호 VH | 8 |
| `03_root` | `ZR_CMSM_*` BO 뷰 (composition, 관리 필드 semantics, LOB) | 7 |
| `04_projection` | `ZC_CMSM_*` 프로젝션 (텍스트 필드, VH, 검색) | 7 |

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
- BDEF·서비스 정의·바인딩
- UNION 오브젝트 뷰, 기술부채 여부 뷰, SB 기능 목록 custom entity
- `ZDO_SYSID` 유지보수 → 비즈니스 설정 유지보수 오브젝트 생성기를 쓰면 CDS·BDEF가 따로 생긴다

## BDEF 만들 때 메모

- CDS 별칭(`ReqUuid`)과 테이블 필드(`requuid`)가 대소문자만 달라서 `mapping for ztcmsm00170 corresponding;`이면 된다.
- 읽기 전용 후보: UUID 키, 표시 번호(`ReqId` 등), 관리 필드, `DoneDate`, `VhImpl`(자동 판별), `TestBy`/`TestAt`, 이력 자식 전체.
- 드래프트로 가면 루트 `LastChangedAt`이 total etag, 각 엔티티 `LocalLastChangedAt`이 etag.
