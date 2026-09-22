# 사내 네이밍 규칙 ATC 체크 (ZATC_NAMING)

표준 네이밍 체크로는 사내 개발 표준을 표현할 수 없어서 체크를 직접 만든다.
규칙은 코드가 아니라 테이블에 두고 SM30 으로 유지한다.

## 만드는 것 4개

| # | 오브젝트 | 어디서 | 역할 |
|---|---|---|---|
| 1 | `ZTATCNAMING` | SE11 / ADT | 규칙(정규식)을 담는다 |
| 2 | 유지보수 뷰 | SE11 → 유틸리티 → 테이블 유지보수 생성기 | SM30 으로 규칙을 유지 |
| 3 | `ZCL_ATC_CHECK_NAMING` | ADT | 이름을 규칙과 대조해 finding 을 낸다 |
| 4 | 체크 변형 (예: `ZNAMING`) | SCI / ATC | 3번 체크만 담은 세트. ATC 는 이걸 돌린다 |

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

## 순서

0. 데이터 요소 4개 생성 (아래 **필드 라벨**)
1. `ZTATCNAMING` 생성 → SE13 에서 **로그 데이터 변경 켜기** (규칙 변경 이력)
2. SE11 → 유틸리티 → 테이블 유지보수 생성기
   - 유지보수 유형 **1단계**, 화면번호 임의(예: 0100), 권한그룹 지정
3. `ZCL_ATC_CHECK_NAMING` 생성 → 아래 **확인 필요 3곳** 처리 후 활성화
4. 규칙 행 입력 (SM30)
5. SCI/ATC 에서 체크 변형 생성 → 체크 트리에서 이 체크만 선택
6. 예외 앱 연결: `ZTATCCFG` 에 그 변형명으로 1행 (`activeflg = X`,
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
| `priority` | `ZATC_NAMEPRIO` | 신규 INT1 | `Priority` | `Priority` | `Finding Priority (1 = Error)` | `Prio` |
| `msgtext` | `ZATC_NAMEMSG` | 신규 CHAR 120 | `Message` | `Message Text` | `Message Shown on Violation` | `Message` |

`active` 의 도메인을 표준 `XFELD` 로 두는 이유는 SM30 에서 체크박스로 뜨기
때문이다. `ABAP_BOOLEAN` 을 쓰면 라벨이 없어 컬럼 제목이 비어 보인다.

`priority` 에 고정값을 넣어 둘지는 선택이다. 도메인에 1/2/3 을 고정값으로
등록하면 SM30 에 드롭다운이 생기고 오타가 막힌다. 다만 표준 ATC 가 우선순위를
넓히면 우리만 못 따라가므로, 넣는다면 설명 목적으로만 보는 게 낫다.

## 확인 필요 3곳 (ADT 에서 `CL_CI_TEST_ROOT` 를 열어볼 것)

체크 클래스에서 프레임워크에 의존하는 부분이다. 나머지(규칙 조회·대조)는
프레임워크와 무관하므로 그대로 쓰면 된다.

| 위치 | 확인할 것 |
|---|---|
| `constructor` 의 `add_obj_type( )` | 메서드명과 파라미터. 다루는 오브젝트 타입을 등록하는 방식 |
| `run` 의 `inform( )` | 파라미터 이름과 필수 여부 (`p_kind` / `p_test` / `p_code` / `p_param_*`) |
| `get_message_text( )` | 메시지 텍스트를 여기서 주는 게 맞는지, `SCIMESSAGES` 등록 방식인지 |

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
