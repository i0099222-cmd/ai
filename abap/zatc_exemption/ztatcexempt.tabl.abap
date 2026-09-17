@EndUserText.label : 'ATC 예외 신청 헤더'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztatcexempt {

  key client        : abap.clnt not null;

  "! 신청서 GUID. RAP BO 키.
  key exemptuuid    : sysuuid_x16 not null;

  "! 사용자 표시용 신청번호 (넘버레인지)
  exemptid          : abap.char(12);

  "! 체크 그룹. ztatccfg 에서 파생. 예: NAMING / PERF / SECURITY
  checkgroup        : abap.char(10);

  "! 적용 범위. FND / OBJ / PKG.
  "! 허용 여부는 ztatccfg 컨트롤 테이블로 판정한다 (하드코딩 금지).
  scopetype         : abap.char(3);

  "! 대상 패키지. OBJ/FND 스코프에서는 TADIR 에서 파생된다.
  devclass          : devclass;

  "! 하위 패키지 포함 여부 (PKG 스코프에서만 의미 있음)
  inclsubpkg        : abap_boolean;

  "! 대상 오브젝트 타입. OBJ/FND 스코프에서 필수.
  objecttype        : trobjtype;

  "! 대상 오브젝트명. OBJ/FND 스코프에서 필수.
  objectname        : sobj_name;

  "! 인클루드명. FND 스코프 전용 (Phase 2 대비 선반영)
  subobject         : abap.char(40);

  "! 소스 라인. FND 스코프 전용 (Phase 2 대비 선반영)
  lineno            : abap.int4;

  "! 표준 finding 식별자. FND 스코프 전용 (Phase 2 대비 선반영)
  "! 라인 번호만으로는 코드 변경 시 매칭이 깨지므로 표준 키를 그대로 보관한다.
  findingkey        : abap.char(60);

  "! 대상 체크 ID. 공란이면 체크그룹 전체.
  checkid           : abap.char(30);

  "! 대상 메시지 ID. 공란이면 체크의 모든 메시지.
  messageid         : abap.char(30);

  "! 규칙 적용 축. MSG(메시지 1개) / CHK(체크 전체)
  rulescope         : abap.char(3);

  "! 사유 코드
  reasoncode        : abap.char(4);

  "! 근거 텍스트. 감사 대응 시 유일한 서술 근거이므로 최소 길이를 검증한다.
  reasontext        : abap.string(0);

  validfrom         : abap.dats;

  "! 유효종료일. 필수이며 상한은 ztatccfg-maxvalidmon 으로 제한된다.
  validto           : abap.dats;

  "! 10 초안 / 20 승인대기 / 30 승인 / 40 반려 / 50 철회 / 60 만료
  exemptstat        : abap.char(2);

  requester         : abap.char(12);

  approver          : abap.char(12);

  approvedat        : timestampl;

  "! 표준 ATC 예외 저장소에 생성된 예외 ID.
  "! 승인 시 표준 반영이 성공하면 채워지며, 철회/연장 시 역추적에 사용한다.
  extexemptid       : abap.char(32);

  "! 사전등록 여부. finding 없이 선제적으로 등록한 건이면 X.
  preregflag        : abap_boolean;

  "! CBO 공통 이력 구조 (생성자/생성일/변경자/변경일 등)
  include zscm00010;

  "! RAP 기술 필드. ZSCM00010 의 날짜+시간 분리 필드는 etag 로 쓸 수 없으므로
  "! 타임스탬프 필드를 별도로 둔다.
  createdat         : timestampl;
  lastchangedat     : timestampl;
  loclastchgat      : timestampl;

}
