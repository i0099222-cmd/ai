@EndUserText.label : 'ATC Naming Convention Rules'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
// 사내 개발 표준의 네이밍 규칙을 담는다. 표준 네이밍 체크로는 사내 규칙을
// 표현할 수 없어서 체크를 직접 만들고, 그 체크가 이 테이블을 읽는다.
//
// 규칙을 코드가 아니라 테이블에 둔 이유:
//   표준 네이밍 체크는 패턴을 "체크 변형" 안에 들고 있다. 규칙 하나를 바꾸려면
//   개발자가 변형을 열어 고치고 이송해야 한다. 테이블 + SM30 이면 개발 표준이
//   바뀔 때 행만 추가하면 되고, 코드도 체크 클래스도 건드리지 않는다.
//
// 한 오브젝트 타입에 여러 행을 두면 **전부 만족해야 한다(AND)**.
//   행 하나가 곧 요구사항 하나이고, 어긋나면 그 행의 msgtext 로 finding 이 뜬다.
//   "ZCL_ 또는 ZCX_" 처럼 택일 조건은 행을 나누지 말고 정규식 안에서 | 로 쓴다.
//   (행을 OR 로 두면 어느 규칙을 어겼는지 메시지로 지목할 수 없다.)
//
// 변경 이력은 ZSCM00010 을 넣지 않고 SE13 의 "로그 데이터 변경" 으로 남긴다.
// SM30 화면에 생성자/생성일시 컬럼이 같이 뜨면 유지보수하는 사람이 그걸
// 채워야 하는 값으로 오해한다. 커스터마이징 테이블의 표준 방식은 테이블 로그다.
define table ztatcnaming {

  key client   : abap.clnt not null;

  "! TADIR 오브젝트 타입. CLAS / INTF / TABL / PROG / DDLS / FUGR / DEVC ...
  "! 체크 클래스가 이 값으로 규칙을 찾는다. TADIR-OBJECT 와 같은 값이다.
  "!
  "! 표준 데이터 요소를 쓴다. 라벨도 값 도움도 이미 있고, 우리가 만들면
  "! TADIR 과 같은 값인데 다른 이름으로 불리게 된다.
  key objtype  : trobjtype not null;

  "! 같은 타입 안의 규칙 번호. 순서만 정하고 의미는 없다.
  key seqnr    : zatc_nameseq not null;

  "! 규칙 사용 여부. 규칙을 지우지 않고 끌 수 있어야 한다 -
  "! 지우면 왜 뺐는지가 남지 않는다.
  active       : zatc_nameact;

  "! 정규식(PCRE). 오브젝트 이름 전체가 이것과 맞아야 한다.
  "! 이름은 대문자로 저장되므로 패턴도 대문자로 쓴다.
  "!   ^ZCL_[A-Z0-9_]{1,26}$   ZCL_ 로 시작하고 전체 30자 이내
  "!   ^Z(CL|CX|IF)_[A-Z0-9_]+$  ZCL_ / ZCX_ / ZIF_ 중 하나로 시작
  "!   ^Z[A-Z0-9_]+$           Z 로 시작하기만 하면 됨
  pattern      : zatc_namepatt;

  "! finding 우선순위. 1 이 가장 심각하다.
  "!   1 -> error / 2 -> warning / 3 -> note
  "! 예외 앱의 ztatccfg-maxpriority 와 맞물린다. 거기서 2 로 막아두면
  "! 여기 1 로 둔 규칙은 예외 신청 자체가 되지 않는다.
  priority     : zatc_nameprio;

  "! 위반 시 개발자에게 보이는 문장. 시스템 언어가 EN 이므로 영어로 쓴다.
  "! "무엇이 틀렸다" 가 아니라 "어떻게 해야 한다" 로 쓴다 -
  "! 이름을 고칠 사람에게 필요한 정보는 규칙이지 판정이 아니다.
  msgtext      : zatc_namemsg;

}
