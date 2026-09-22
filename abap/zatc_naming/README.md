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

1. `ZTATCNAMING` 생성 → SE13 에서 **로그 데이터 변경 켜기** (규칙 변경 이력)
2. SE11 → 유틸리티 → 테이블 유지보수 생성기
   - 유지보수 유형 **1단계**, 화면번호 임의(예: 0100), 권한그룹 지정
3. `ZCL_ATC_CHECK_NAMING` 생성 → 아래 **확인 필요 3곳** 처리 후 활성화
4. 규칙 행 입력 (SM30)
5. SCI/ATC 에서 체크 변형 생성 → 체크 트리에서 이 체크만 선택
6. 예외 앱 연결: `ZTATCCFG` 에 그 변형명으로 1행 (`activeflg = X`,
   `objactive = X`, `pkgactive = X`, `fndactive` 공란)

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

### 예시 행

| objtype | seqnr | pattern | prio | msgtext |
|---|---|---|---|---|
| `CLAS` | 010 | `^ZCL_[A-Z0-9_]{1,26}$` | 1 | `Class name must start with ZCL_` |
| `INTF` | 010 | `^ZIF_[A-Z0-9_]{1,26}$` | 1 | `Interface name must start with ZIF_` |
| `TABL` | 010 | `^Z[TS][A-Z0-9_]+$` | 1 | `Table must start with ZT, structure with ZS` |
| `PROG` | 010 | `^Z[A-Z0-9_]+$` | 2 | `Report name must start with Z` |
| `DDLS` | 010 | `^Z[IPRC]_[A-Z0-9]+$` | 2 | `CDS view must be ZI_ ZP_ ZR_ or ZC_` |

이건 **예시다.** 사내 개발 표준 문서의 규칙으로 바꿔서 넣는다.

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
