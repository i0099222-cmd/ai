# 사내 네이밍 규칙 ATC 체크 (ZATC_NAMING)

표준 네이밍 체크로는 사내 개발 표준을 표현할 수 없어서 체크를 직접 만든다.
규칙은 코드가 아니라 테이블에 두고 SM30 으로 유지한다.

## 릴리스 전제

`IF_CI_ATC_CHECK` 는 **S/4HANA 2022 이상**(Private Cloud / 온프레미스),
S/4HANA Cloud Public Edition, BTP ABAP 환경에서 지원된다. 우리 시스템이
2022 미만이면 이 API 자체가 없으므로 구 Code Inspector 경로밖에 없다.
착수 전에 릴리스부터 확인할 것.

## 만드는 것 6개

| # | 오브젝트 | 어디서 | 역할 |
|---|---|---|---|
| 1 | `ZTATCNAMING` | SE11 / ADT | 규칙(정규식)을 담는다 |
| 2 | 유지보수 뷰 | SE11 → 유틸리티 → 테이블 유지보수 생성기 | SM30 으로 규칙을 유지 |
| 3 | `ZCL_ATC_CHECK_NAMING` | ADT | 이름을 규칙과 대조해 finding 을 낸다. `IF_CI_ATC_CHECK` 구현 |
| 4 | **ATC Check Category** | ADT: `New → ABAP Repository Object` | 사내 커스텀 체크를 묶는 분류. Parent Category 는 비워 둔다 |
| 5 | **ATC Check** | ADT: `New → ATC Check` | 체크의 등록. 이름·설명·**카테고리**·**구현 클래스** |
| 6 | ATC Check Variant (예: `ZNAMING`) | ADT: `New → ATC Check Variant` | 5번 체크를 담은 세트. ATC 는 이걸 돌린다 |

4번을 만들면 Project Explorer 에 **ABAP Test Cockpit 노드**가 생기고,
그 아래에 Check Categories / Checks / Check Variants 가 모인다. 5번과 6번은
그 노드의 컨텍스트 메뉴에서 만드는 편이 빠르다.

셋의 관계:

```
체크(Check)        검사 규칙 하나 = ZCL_ATC_CHECK_NAMING
                   실제로 오브젝트를 뜯어보고 위반을 찾는 주체
                        ↓ 골라 담아 묶으면
체크 변형(Variant) 검사 세트 = ZNAMING
                        ↓ 대상(패키지/트랜스포트)에 돌리면
ATC 실행(Run)      결과 = finding 목록
                        ↓
                   예외 관리 앱(ZATC_EXEMPTION)이 읽는 게 이것
```

**체크 변형을 만든다고 규칙이 생기는 게 아니다.** 변형은 그릇이고 검사 로직은
체크 클래스 안에 있다.

## 신규 API 로 간다 (SCI 아님)

체크를 만드는 길이 두 개다. 우리는 **신규 쪽**을 쓴다.

| | 구(舊) Code Inspector | 신(新) ATC |
|---|---|---|
| 클래스 | `CL_CI_TEST_ROOT` 상속 | **`IF_CI_ATC_CHECK` 구현** |
| 메타데이터 | 생성자에서 `description` / `category` / `add_obj_type( )` | `get_meta_data( )` 한 곳 |
| 등록 | SCI → `Goto → Management of → Tests` 에서 체크박스 | **ADT `New → ATC Check`** 오브젝트 |
| 카테고리 | 코드에 카테고리 클래스명을 박음 | ATC Check 오브젝트의 입력 필드 |

구 API 로 가면 SCI 등록·카테고리 클래스명·SCI225 를 전부 상대해야 한다.
신규 API 는 그 단계가 아예 없다. 카테고리도 코드가 아니라 ATC Check
오브젝트에서 고른다.

## 순서

0. 데이터 요소 4개 생성 (아래 **필드 라벨**)
1. `ZTATCNAMING` 생성 → SE13 에서 **로그 데이터 변경 켜기** (규칙 변경 이력)
2. SE11 → 유틸리티 → 테이블 유지보수 생성기
   - 유지보수 유형 **1단계**, 화면번호 임의(예: 0100), 권한그룹 지정
3. 규칙 행 입력 (SM30). **체크보다 먼저 넣는다** - 규칙이 없으면 체크가
   돌아도 아무 일이 없어서 되는 건지 안 되는 건지 구분할 수 없다
4. `CL_CI_ATC_CHECK_EXAMPLE` 을 복사해 `ZCL_ATC_CHECK_NAMING` 생성 →
   검사 로직만 우리 것으로 교체 (`check_name( )` 부분)
5. ADT `New → ABAP Repository Object` → **ATC Check Category** 생성.
   Description 이 체크 변형 화면에 분류명으로 뜬다. Parent Category 는 비움
6. ADT `New → ATC Check` → 이름·설명·카테고리(5번)·구현 클래스(4번) → 활성화
7. ADT `New → ATC Check Variant` → 5번 카테고리 아래에 뜬 6번 체크를 담고 활성화
8. ADT 대상 패키지 우클릭 → `Run As → ABAP Test Cockpit` → 결과는 ATC Problems 뷰
9. 예외 앱 연결: `ZTATCCFG` 에 그 변형명으로 1행 (`activeflg = X`,
   `objactive = X`, `pkgactive = X`, `fndactive` 공란)

## 필드 라벨

SM30 의 컬럼 제목은 **데이터 요소의 필드 라벨**에서 나온다. 내장 타입
(`abap.char(4)` 등)으로 두면 라벨이 없어 필드명만 뜨므로 데이터 요소를 쓴다.
시스템 언어가 EN 이라 라벨은 영어로 등록한다.

`objtype` 은 표준 `TROBJTYPE` 을 그대로 쓴다. 라벨도 값 도움도 이미 있고,
우리가 만들면 TADIR 과 같은 값인데 다른 이름으로 불리게 된다.

| 필드 | 데이터 요소 | 도메인 | Short (10) | Medium (20) | Long (40) | Heading (55) |
|---|---|---|---|---|---|---|
| `objtype` | `TROBJTYPE` (표준) | — | 표준 그대로 | | | |
| `seqnr` | `ZATC_NAMESEQ` | 신규 NUMC 3 | `Rule No.` | `Rule Number` | `Naming Rule Number` | `Rule` |
| `active` | `ZATC_NAMEACT` | 표준 `XFELD` | `Active` | `Active` | `Rule Is Active` | `Act.` |
| `pattern` | `ZATC_NAMEPATT` | 신규 CHAR 255 | `Pattern` | `Name Pattern` | `Name Pattern (Regular Expression)` | `Name Pattern (Regular Expression)` |
| `priority` | `ZATC_NAMEPRIO` | 신규 NUMC 1 | `Priority` | `Priority` | `Finding Priority (1 = Error)` | `Prio` |
| `msgtext` | `ZATC_NAMEMSG` | 신규 CHAR 120 | `Message` | `Message Text` | `Message Shown on Violation` | `Message` |

`active` 의 도메인을 표준 `XFELD` 로 두는 이유는 SM30 에서 체크박스로 뜨기
때문이다. `ABAP_BOOLEAN` 을 쓰면 라벨이 없어 컬럼 제목이 비어 보인다.

`priority` 에 고정값을 넣어 둘지는 선택이다. 도메인에 1/2/3 을 고정값으로
등록하면 SM30 에 드롭다운이 생기고 오타가 막힌다. 다만 표준 ATC 가 우선순위를
넓히면 우리만 못 따라가므로, 넣는다면 설명 목적으로만 보는 게 낫다.

## 체크 클래스는 예제를 복사해서 만든다

`CL_CI_ATC_CHECK_EXAMPLE` 이 `IF_CI_ATC_CHECK` 의 본보기다. 인터페이스
메서드는 다섯 개고, 우리가 채울 곳은 둘뿐이다.

| 메서드 | 역할 | 우리 구현 |
|---|---|---|
| `get_meta_data` | 체크의 신상 - 제목, 카테고리, 다룰 오브젝트 타입, finding 코드 | 예제 구조를 우리 값으로 |
| `run` | 실제 검사 | 규칙 대조 + finding 보고 |
| `set_assistant_factory` | 프레임워크가 보조 객체 팩토리를 주입 | 받아서 보관만. 소스를 안 읽으므로 쓸 일 없음 |
| `set_attributes` | 체크 파라미터(변형에 저장되는 설정) | 빈 구현. 규칙은 변형이 아니라 `ZTATCNAMING` 에 있다 |

`set_attributes` 를 비우는 것은 SAP 예제와 다른 선택이다. SAP 예제는 이름
패턴을 **체크 변형의 파라미터**로 둔다. 그러면 규칙을 바꿀 때마다 변형을
고쳐 이송해야 하고, 개발자가 아니면 손댈 수 없다. 규칙을 테이블에 둔 이유가
그것이므로 여기서는 파라미터를 쓰지 않는다.
| `verify_prerequisites` | 실행 전제 확인 | 빈 구현 |

`get_meta_data( )` 가 돌려주는 것은 구조체가 아니라
**`IF_CI_ATC_CHECK_META_DATA` 를 구현한 객체**이고, 그 클래스는 SAP 이 주는 게
아니라 체크를 만드는 쪽이 직접 만든다. 이 저장소에서는
`zcl_atc_check_naming.clas.locals_imp.abap` (ADT 의 **Local Types** 탭) 이 그것이다.

| 메타데이터 메서드 | 우리 값 |
|---|---|
| `get_description` | `Naming conventions (customer rules)` |
| `get_check_object_types` | `ZTATCNAMING` 에서 `SELECT DISTINCT objtype` |
| `get_finding_code_infos` | 코드 3개 = 심각도 3개. 텍스트는 전부 `&1` |
| `get_attributes` | 비움 (체크 파라미터를 쓰지 않는다) |
| `get_quickfix_code_infos` | 비움 (이름 변경은 자동으로 고칠 수 없다) |
| `is_remote_enabled` | `X` - 검사 대상 시스템의 데이터를 읽지 않는다 |
| `uses_checksums` | 공란 - finding 이 소스 줄이 아니라 이름에 붙는다 |

**심각도는 finding 코드에 붙는다.** `ty_finding` 에 심각도 필드가 없어서,
규칙의 `priority` 를 건별로 반영하려면 코드를 심각도 수만큼 나누는 수밖에
없다. 그래서 `NAMING_E` / `NAMING_W` / `NAMING_N` 셋이다.

**메시지 텍스트가 전부 `&1` 인 것도 같은 이유다.** 규칙마다 문장이 다르므로
코드에 고정 문장을 걸 수 없다. `run( )` 이 규칙의 `msgtext` 를 `param_1` 로
넘겨 그 자리를 채운다.

## 규칙 쓰는 법

한 오브젝트 타입에 여러 행 = **전부 만족해야 한다(AND)**. 행 하나가 요구사항
하나이고, 어긋나면 그 행의 `msgtext` 로 finding 이 뜬다. "ZCL_ 또는 ZCX_"
같은 택일은 행을 나누지 말고 정규식 안에서 `|` 로 쓴다 — 행으로 나누면 어느
규칙을 어겼는지 지목할 수 없다.

### 정규식 기호

| 기호 | 뜻 | 예 |
|---|---|---|
| `^` | 시작 | `^Z` → Z 로 시작 |
| `$` | 끝 | `_DPC_EXT$` |
| `[A-Z0-9_]` | 이 중 한 글자 | 대문자·숫자·언더바 |
| `+` | 1번 이상 | `[A-Z]+` |
| `{1,26}` | 1~26번 | 길이 제한 |
| `(A|B)` | 택일 | `^Z(CL|CX|IF)_` |

오브젝트 이름은 대문자로 저장되므로 패턴도 대문자로 쓴다.

`matches( )` 는 **전체 일치**다. 접두어만 보고 싶어도 부분 일치가 되지 않으므로
뒤에 `.*` 를 붙여야 한다. `^ZCL_` 만 쓰면 `ZCL_` 딱 네 글자인 이름만 통과한다.

### 등록된 행 (CLAS)

| objtype | seqnr | pattern | prio | msgtext |
|---|---|---|---|---|
| `CLAS` | 010 | `^Z(CL\|CX\|BP)_[A-Z]{2}.*$` | 2 | `Class name must start with ZCL_, ZCX_ or ZBP_ followed by a module code` |

사내 표준의 전체 형태는 이보다 자세하다.

```
ZCL_MMMR_BOM_CREATE        일반        ZCL_ + 모듈2 + 서브2 + _ + DESC
ZCX_MRPP_BOM_CREATE        예외        ZCX_ + 모듈2 + 서브2 + _ + DESC
ZCL_WF_ACC_DOCUMENT_POST   래핑팩토리  ZCL_WF_ + DESC (모듈코드 없음)
ZBP_CMSM_R_OBJECT_MASTER   BDEF        ZBP_ + 모듈2 + 서브2 + _ + DESC
```

전부를 하나의 정규식에 넣지 않는다. 넷이 모두 TADIR 타입 `CLAS` 라서 한 패턴
안에 `|` 로 묶어야 하는데, 그러면 위반 메시지가 네 형태를 전부 나열하게 되어
정작 무엇이 틀렸는지 알려주지 못한다. 예외(래핑 팩토리처럼 모듈코드가 없는
형태)도 계속 늘어난다. 그래서 **접두어와 모듈코드까지만 본다** - 이 선은
예외가 없고, 넘으면 위반이 분명하다.

길이 규칙은 두지 않는다. 클래스명은 30자를 넘길 수 없어서 ABAP 이 애초에
만들지 못하게 한다. 절대 걸리지 않는 규칙은 읽는 사람만 헷갈리게 한다.

나머지 타입(INTF, TABL, DDLS, PROG, FUGR …)도 같은 기준으로 정한다.

### 표준 문서가 없거나 못 찾을 때

현행 오브젝트에서 역으로 뽑는다. 타입별 실제 이름을 훑으면 팀이 암묵적으로
써 온 규칙이 보인다. 그걸 정리해 리드에게 확인받는 게 제일 빠르다.

```abap
SELECT object, obj_name FROM tadir
  WHERE devclass LIKE 'Z%'
    AND pgmid    = 'R3TR'
    AND delflag  = @abap_false
  ORDER BY object, obj_name
  INTO TABLE @DATA(lt_tadir).
```

### 규칙을 넣기 전에 확인하는 법

ATC 를 돌리지 않고 콘솔에서 바로 대조할 수 있다. 규칙 하나 넣을 때마다
ATC 를 돌리면 한 번에 몇 분씩 걸린다.

```abap
DATA(lt_violation) = NEW zcl_atc_check_naming( )->check_name(
                       iv_objtype = 'CLAS'
                       iv_objname = 'ZCL_FOO' ).
```

## 기존 오브젝트를 어떻게 할 것인가

규칙을 켜면 **이미 있는 오브젝트도 전부 걸린다.** 신규만 적용하는 기능은
ATC 에 없다. 선택지는 셋이다.

1. 이름을 고친다 — 깨끗하지만 참조가 많으면 현실적이지 않다
2. 예외로 등록한다 — 우리 예외 관리 앱이 하는 일이 이것이다.
   패키지 단위로 한 건 올려 두면 기존 오브젝트가 통째로 빠진다
3. 규칙을 느슨하게 시작한다 — `priority 3`(note) 으로 켜서 규모를 먼저 보고,
   정리된 뒤에 1 로 올린다

**3 → 2 → 1 순서를 권한다.** 처음부터 error 로 켜면 기존 위반 수백 건이
한꺼번에 쏟아져서 팀이 체크 자체를 꺼 버린다.

## Phase 2

오브젝트 이름만 본다. 메서드명·변수명·폼명 같은 **내부 이름**까지 보려면
소스를 읽어야 하고, 그때는 `CL_CI_TEST_SCAN` 계열로 확장한다. 규칙 테이블은
그대로 쓰고 `objtype` 에 내부 종류를 나타내는 값을 추가하는 방향이 된다.
