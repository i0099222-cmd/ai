# SAP RAP Template (PCE) — Case 1 ~ 8

SAP S/4HANA Private Cloud Edition 환경에서 사용할 **RAP 표준 템플릿** 모음이다.
원천 데이터 유형별로 8개 케이스를 각각 독립적으로 따라 할 수 있게 구성했다.

---

## 1. 전제 조건

| 항목 | 값 |
|------|-----|
| 릴리즈 | S/4HANA 2021(ABAP Platform 7.56) 이상 권장 |
| ABAP 언어 버전 | Standard ABAP (Case 6~8 은 `MAKT` 등 비릴리즈 오브젝트를 참조) |
| 패키지 | 프로젝트 개발 패키지 1개 (예: `ZDQ_RAP_TEMPLATE`) |
| 히스토리 구조 | `ZSCM00010` (RAP 표준형 5필드 — `00_common/zscm00010.reference.md` 참고) |

---

## 2. 네이밍 규칙

| 접두어 | 오브젝트 | 설명 |
|--------|----------|------|
| `ZDQ_I_*`  | Interface view | 테이블/표준 CDS 를 감싸는 재사용 기본 뷰. 필드명 정규화 + association 정의 |
| `ZDQ_R_*`  | Root view entity | behavior definition 이 붙는 뷰. composition / to parent 정의 |
| `ZDQ_P_*`  | Projection view | 트랜잭션 서비스에 노출되는 뷰 (`provider contract transactional_query`) |
| `ZDQ_C_*`  | Consumption view | **조회 전용** 서비스에 노출되는 뷰 (behavior 없음) |
| `ZDQ_CE_*` | Custom entity | 조회 로직을 ABAP 클래스로 구현하는 엔티티 |
| `ZDQ_TF_*` | Table function | AMDP(SQLScript) 로 구현하는 엔티티 |
| `ZDQ_A_*`  | Abstract entity | 액션 파라미터 구조 |
| `ZDQ_SD_*` / `ZDQ_SB_*` | Service definition / binding | |
| `ZBP_DQ_*` | Behavior pool | behavior definition 구현 클래스 |
| `ZCL_DQ_*` | 일반 클래스 | query provider, AMDP |
| `ZDQ_T*`   | CBO 테이블 | |

> 뷰 이름만 보면 케이스를 알 수 있게 `ZDQ_<유형>_<케이스명>` 형태를 유지했다.
> (예: `ZDQ_I_TABLE_TO_SERVICE`, `ZDQ_R_CDS_TO_SRV_ACTION`)
>
> CDS/클래스 이름은 최대 30자이므로 `SERVICE` → `SRV`, `FUNCTION` → `FUNC` 로 줄인 곳이 있다.

### I - R - P 를 언제 쓰고 Table → C 를 언제 쓰나

- **변경(액션/CRUD)이 있는 경우** → `I` → `R` → `P`
  - `I` 는 재사용 가능한 기본 뷰, `R` 은 behavior 가 붙는 지점, `P` 는 서비스 노출/화면 애노테이션
- **조회만 하는 경우** → `I` → `C` (또는 원천 → `C`)
  - behavior 가 없으므로 root view 를 따로 둘 이유가 없다

---

## 3. 공통 데이터 모델

모든 케이스가 **같은 CBO 테이블 + 같은 표준 CDS** 를 바라본다. 케이스 간 CDS 의존은 없으므로
필요한 케이스만 골라서 생성해도 되고, 전부 생성하면 하나의 업무 데이터로 연결된다.

```
  [CBO]                                        [Standard CDS]

  ZDQ_TORDHDR (구매주문 헤더)  ── supplier ──▶  I_Supplier
      │  order_id                 plant    ──▶  I_Plant
      │
      └─▶ ZDQ_TORDITM (구매주문 아이템) ── product ──▶ I_Product
                                                        │
  ZDQ_TPRDREV (자재 검토상태) ──── product ─────────────┘
                                                   I_ProductDescription
```

| 테이블 | 내용 | 사용 케이스 |
|--------|------|-------------|
| `ZDQ_TORDHDR` | 구매주문 헤더 | 1, 2, 3 |
| `ZDQ_TORDITM` | 구매주문 아이템 | 3, 6, 8 |
| `ZDQ_TPRDREV` | 자재 검토상태 (액션 저장 대상) | 5, 7 |

세 테이블 모두 `include zscm00010;` 로 히스토리 필드를 갖는다.

---

## 4. 케이스 요약

| # | 케이스 | 원천 | CDS 구성 | Behavior | 액션 |
|---|--------|------|----------|----------|------|
| 1 | Table to Service | `ZDQ_TORDHDR` | I → C | 없음 (조회) | – |
| 2 | Table to Service with Action | `ZDQ_TORDHDR` | I → R → P | `managed` | `releaseOrder`, `changeStatus` |
| 3 | Table to BO | `ZDQ_TORDHDR` + `ZDQ_TORDITM` | I → R → P (Header/Item) | `managed` + composition | `closeOrder` |
| 4 | CDS to Service with Display | `I_Product` | I → C | 없음 (조회) | – |
| 5 | CDS to Service with Action | `I_Product` + `ZDQ_TPRDREV` | I → R → P | `managed with unmanaged save` | `approveReview` |
| 6 | Custom Entity with display | `ZDQ_TORDITM` + `I_ProductDescription` | Custom entity | 없음 (조회) | – |
| 7 | Custom Entity with Action | `I_Product` + `ZDQ_TPRDREV` | Custom entity | `unmanaged` | `approveReview` |
| 8 | Table Function to Service | `ZDQ_TORDITM` + `MAKT` | TF → I → C | 없음 (조회) | – |

액션은 모두 **필드 하나를 바꾸는 수준**으로만 구현했다 (주문상태 / 검토상태).

---

## 5. 생성 순서

1. `00_common` 의 테이블 3개 (`ZSCM00010` 이 먼저 존재해야 한다)
2. Case 7 을 만들 경우 잠금 오브젝트 `EZDQ_TPRDREV`
3. 케이스별로 `I → R → P/C → Abstract → BDEF → Behavior pool → Service definition → Service binding` 순서
4. Service binding 은 ADT 에서 생성 (파일로 관리되지 않음) — 아래 6번 표 참고
5. Service binding 에서 **Publish** 실행 → Fiori Elements Preview 로 확인

---

## 6. Service Binding 목록

모두 **OData V4 / UI** 타입으로 생성한다.

| # | Service Definition | Service Binding | 노출 엔티티 |
|---|--------------------|-----------------|-------------|
| 1 | `ZDQ_SD_TABLE_TO_SERVICE`    | `ZDQ_SB_TABLE_TO_SERVICE`    | `PurchaseOrder` |
| 2 | `ZDQ_SD_TABLE_TO_SRV_ACTION` | `ZDQ_SB_TABLE_TO_SRV_ACTION` | `PurchaseOrder` |
| 3 | `ZDQ_SD_TABLE_TO_BO`         | `ZDQ_SB_TABLE_TO_BO`         | `PurchaseOrder`, `PurchaseOrderItem` |
| 4 | `ZDQ_SD_CDS_TO_SRV_DISPLAY`  | `ZDQ_SB_CDS_TO_SRV_DISPLAY`  | `Product` |
| 5 | `ZDQ_SD_CDS_TO_SRV_ACTION`   | `ZDQ_SB_CDS_TO_SRV_ACTION`   | `ProductReview` |
| 6 | `ZDQ_SD_CUSTOM_ENT_DISPLAY`  | `ZDQ_SB_CUSTOM_ENT_DISPLAY`  | `PurchaseOrderItem` |
| 7 | `ZDQ_SD_CUSTOM_ENT_ACTION`   | `ZDQ_SB_CUSTOM_ENT_ACTION`   | `ProductReview` |
| 8 | `ZDQ_SD_TABLE_FUNC_TO_SERVICE` | `ZDQ_SB_TABLE_FUNC_TO_SERVICE` | `PurchaseOrderSummary` |

---

## 7. 케이스별 상세

### Case 1 — Table to Service (조회 전용)

```
zdq_tordhdr ──▶ ZDQ_I_TABLE_TO_SERVICE ──▶ ZDQ_C_TABLE_TO_SERVICE ──▶ ZDQ_SD_TABLE_TO_SERVICE
```

- 가장 기본 형태. behavior 가 없으므로 root view 없이 `I → C` 로 끝난다.
- `I` 뷰에서 `I_Supplier` / `I_Plant` association 을 노출하고, `C` 뷰에서 경로식으로 텍스트를 가져온다.
- 텍스트 필드는 `@ObjectModel.text.element` 로 코드 필드에 연결한다.

### Case 2 — Table to Service with Action

```
zdq_tordhdr ──▶ ZDQ_I_TABLE_TO_SRV_ACTION ──▶ ZDQ_R_TABLE_TO_SRV_ACTION ──▶ ZDQ_P_TABLE_TO_SRV_ACTION
                                                      │ (BDEF: managed)
                                              ZBP_DQ_R_TABLE_TO_SRV_ACTION
```

- `managed` + `persistent table zdq_tordhdr`. CRUD 는 프레임워크가 처리한다.
- `OrderStatus` 는 `field ( readonly )` 로 막고 **액션으로만** 변경한다.
  - `releaseOrder` : 파라미터 없는 액션
  - `changeStatus` : `ZDQ_A_ORDER_STATUS` 파라미터를 받는 액션
- 핸들러에서 `MODIFY ENTITIES ... IN LOCAL MODE` 를 쓰면 `readonly` 제약을 우회할 수 있다.
- `determination setInitialStatus` 로 생성 시 상태를 `01` 로 채운다.

### Case 3 — Table to BO (Header / Item)

```
ZDQ_R_TABLE_TO_BO_HEADER ──composition──▶ ZDQ_R_TABLE_TO_BO_ITEM
ZDQ_P_TABLE_TO_BO_HEADER ──redirected──▶ ZDQ_P_TABLE_TO_BO_ITEM
```

- 헤더/아이템 **composition** 이 핵심. 아이템은 `lock dependent by _Header`,
  `authorization dependent by _Header` 로 헤더에 종속시킨다.
- `determination calcTotalAmount` (아이템 `on save`) 가 헤더 총액을 재계산한다.
  헤더가 함께 삭제된 경우를 대비해 헤더 존재 여부를 먼저 확인한다.
- `validation checkSupplier` 로 필수값 검증 + 메시지 반환 패턴을 보여준다.
  메시지 클래스 없이 `new_message_with_text( )` 를 사용했다.
- 아이템 번호(`ItemNo`)는 키이므로 생성 시 사용자가 입력한다.

### Case 4 — CDS to Service with Display

```
I_Product ──▶ ZDQ_I_CDS_TO_SRV_DISPLAY ──▶ ZDQ_C_CDS_TO_SRV_DISPLAY
```

- 원천이 **표준 CDS** 인 조회 케이스. `I` 뷰에서 프로젝트 필드셋으로 정규화하고
  `I_ProductDescription` 을 언어별로 붙인다.
- 표준 CDS 는 데이터량이 많으므로 화면에서 필터 사용을 전제로 한다.

### Case 5 — CDS to Service with Action

```
I_Product ─┐
           ├─▶ ZDQ_I_CDS_TO_SRV_ACTION ──▶ ZDQ_R_CDS_TO_SRV_ACTION ──▶ ZDQ_P_CDS_TO_SRV_ACTION
zdq_tprdrev┘                                      │ (BDEF: managed with unmanaged save)
                                          ZBP_DQ_R_CDS_TO_SRV_ACTION
```

**이 케이스의 핵심** — 표준 CDS 는 읽기 전용이라 `persistent table` 을 지정할 수 없다.

- 변경 대상 필드만 CBO 테이블(`ZDQ_TPRDREV`)에 두고 `LEFT OUTER JOIN` 으로 붙인다.
- `managed with unmanaged save` 를 쓰면 조회/잠금/트랜잭션 버퍼는 프레임워크가 처리하고
  **저장만** saver 의 `save_modified` 에서 구현하면 된다.
- 검토 레코드가 아직 없는 자재도 있으므로 saver 에서 `MODIFY ... FROM TABLE` (upsert) 로 저장한다.
- 이력 필드는 자동 채번되지 않으므로 saver 에서 직접 채운다.

### Case 6 — Custom Entity with display

```
ZDQ_CE_CUSTOM_ENT_DISPLAY ◀── ZCL_DQ_CE_DISPLAY_QUERY (if_rap_query_provider)
```

- 조회 로직을 ABAP 으로 직접 구현해야 할 때 쓴다 (RFC, 외부 연계, 복잡한 가공 등).
- query provider 에서 반드시 처리해야 하는 것: **필터 / `$count` / `$top` / `$skip`**.
  이 셋을 빠뜨리면 화면 페이징과 건수 표시가 깨진다.
- 정렬(`get_sort_elements( )`)은 템플릿에서 고정 `ORDER BY` 로 처리했다.
  화면에서 컬럼 정렬이 필요하면 이 부분을 확장한다.

### Case 7 — Custom Entity with Action

```
ZDQ_CE_CUSTOM_ENT_ACTION ◀── ZCL_DQ_CE_ACTION_QUERY   (조회)
            │ (BDEF: unmanaged)
   ZBP_DQ_CE_CUSTOM_ENT_ACTION                        (read / lock / action / save)
```

**8개 중 가장 손이 많이 가는 케이스.** custom entity 는 ABAP SQL 로 읽을 수 없어
`managed` 를 쓸 수 없고, 다음을 전부 직접 구현해야 한다.

| 구현 위치 | 역할 |
|-----------|------|
| `lhc_productreview~read` | 키로 인스턴스 조회 + 미저장 버퍼 반영 |
| `lhc_productreview~lock` | `EZDQ_TPRDREV` 잠금 오브젝트 호출 |
| `lhc_productreview~approvereview` | 액션 — 버퍼에만 반영 |
| `lsc_zdq_ce_custom_ent_action~save` | 버퍼 → DB 저장 |
| `lsc_zdq_ce_custom_ent_action~cleanup` | 롤백 시 버퍼 정리 |

- 잠금 오브젝트 생성은 `00_common/ezdq_tprdrev.enqu.md` 참고.
- `ENQUEUE_EZDQ_TPRDREV` 의 파라미터명은 생성된 함수모듈 시그니처에 맞춰 조정한다.

### Case 8 — Table Function to Service

```
ZCL_DQ_TABLE_FUNC_TO_SERVICE (AMDP) ──▶ ZDQ_TF_TABLE_FUNC_TO_SERVICE
                                              ──▶ ZDQ_I_TABLE_FUNC_TO_SERVICE ──▶ ZDQ_C_TABLE_FUNC_TO_SERVICE
```

- CDS 만으로 표현하기 어려운 집계/가공을 SQLScript 로 처리할 때 쓴다.
- 클라이언트 처리: `@ClientHandling.algorithm: #SESSION_VARIABLE` +
  `@Environment.systemField: #CLIENT` 파라미터 + `returns` 의 `client` 필드. 세 개가 세트다.
- 단위/통화가 섞인 합계가 나오지 않도록 `quantity_unit`, `currency` 까지 `GROUP BY` 에 넣고
  키에도 포함했다.
- AMDP 는 `USING` 에 적은 DB 오브젝트만 접근할 수 있다 (`zdq_torditm`, `makt`).

---

## 8. 활성화 전 검증 체크리스트

이 템플릿은 실제 시스템에서 활성화 검증을 거치지 않았다. 아래 항목은 **처음 생성할 때 반드시 확인**한다.

### 8.1 필수 확인

- [ ] `ZSCM00010` 의 실제 필드명이 `CREATED_BY / CREATED_AT / LAST_CHANGED_BY / LAST_CHANGED_AT /
      LOCAL_LAST_CHANGED_AT` 인지. 다르면 `ZDQ_I_*` 뷰의 select list 와 BDEF 의 `mapping for` 두 곳을 수정
- [ ] 타임스탬프 필드 타입이 `timestampl` (DEC 21,7) 인지. `utclong` 이면 saver 의
      `GET TIME STAMP FIELD` 대상 변수 타입을 `utclong` 으로 바꾼다
- [ ] 사용한 표준 CDS 필드가 해당 릴리즈에 존재하는지
  - `I_Product` : `Product`, `ProductType`, `ProductGroup`, `Division`, `BaseUnit`, `CreationDate`, `CreatedByUser`
  - `I_ProductDescription` : `Product`, `Language`, `ProductDescription`
  - `I_Supplier` : `Supplier`, `SupplierName`
  - `I_Plant` : `Plant`, `PlantName`
- [ ] Case 8: 해당 릴리즈의 `define view entity` 가 table function 을 데이터 소스로 지원하는지.
      지원하지 않으면 `ZDQ_I_TABLE_FUNC_TO_SERVICE` 를 classic `define view` 로 작성한다
- [ ] Case 7: 잠금 오브젝트 `EZDQ_TPRDREV` 생성 및 ENQUEUE 함수모듈 파라미터명 확인

### 8.2 기능 확인

- [ ] Case 1/4/6/8 — 목록 조회, 필터, 정렬, 페이징, 건수
- [ ] Case 2 — 생성 시 상태 `01` 자동 설정 / `releaseOrder` 후 `02` / `changeStatus` 파라미터 반영
- [ ] Case 3 — 아이템 추가·수정·삭제 후 헤더 총액 재계산 / 헤더 삭제 시 오류 없이 연쇄 삭제
- [ ] Case 3 — 공급업체 미입력 시 저장 거부 및 메시지 표시
- [ ] Case 5 — 검토 레코드가 **없는** 자재에 `approveReview` 실행 시 신규 생성되는지 (upsert 확인)
- [ ] Case 5/7 — 두 세션에서 동시 변경 시 잠금/ETag 동작
- [ ] Case 7 — 액션 실행 후 화면 값이 즉시 갱신되는지 (read 핸들러의 버퍼 반영 확인)

---

## 9. 템플릿에 포함하지 않은 것

의도적으로 제외했다. 프로젝트 표준에 맞춰 별도로 결정한다.

| 항목 | 설명 |
|------|------|
| DCL (접근 제어) | 모든 뷰가 `@AccessControl.authorizationCheck: #NOT_REQUIRED`. 권한 오브젝트 확정 후 DCL 추가 |
| 권한 체크 | `get_global_authorizations` 는 전역 허용. 실제로는 `AUTHORITY-CHECK` 로 대체 |
| Draft | Case 3 는 non-draft. 필요 시 BDEF 에 `with draft;` + draft 테이블 추가 |
| 메시지 클래스 | `new_message_with_text( )` 사용. 다국어가 필요하면 T100 메시지 클래스로 교체 |
| 값 도움말 | 상태 코드 값 도움말 뷰 미포함. 필요 시 `@Consumption.valueHelpDefinition` 추가 |
| 번호 채번 | 주문번호/아이템번호는 사용자 입력. 자동 채번이 필요하면 determination + 번호범위 사용 |

---

## 10. 파일 확장자

ADT 에 복사해 넣기 좋도록 소스 형태로 관리한다 (abapGit 형식 준용).

| 확장자 | 오브젝트 |
|--------|----------|
| `.tabl.ddl` | 데이터베이스 테이블 (ADT DDL 정의) |
| `.ddls.asddls` | CDS view entity / custom entity / abstract entity / table function |
| `.bdef.asbdef` | Behavior definition |
| `.srvd.srvdsrv` | Service definition |
| `.clas.abap` | 글로벌 클래스 |
| `.clas.locals_imp.abap` | 클래스의 Local Types (behavior 구현부) |
