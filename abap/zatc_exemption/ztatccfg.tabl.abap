@EndUserText.label : 'ATC 예외 관리 컨트롤 테이블'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
// 업무 데이터가 아니라 앱의 동작 규칙을 담는 컨트롤 테이블이다.
// 답하는 질문 두 개:
//   1) 이 체크가 앱의 관리 대상인가?      -> activeflg   (요건: 네이밍 건만)
//   2) 어떤 적용범위를 허용하는가?         -> *active 3종 (요건: 패키지/오브젝트만)
//
// 가동 전에 반드시 초기 데이터를 넣어야 한다. 비어 있으면 모든 신청이 거부된다.
//
// 승인 권한은 여기 두지 않는다. 권한 오브젝트 Z_ATCEXEM 의 SCOPETYPE 필드가
// 이미 "누가 어느 범위를 승인할 수 있는지" 를 표현하므로 이중 관리가 된다.
define table ztatccfg {

  key client    : abap.clnt not null;

  "! 체크 ID (Code Inspector 체크 클래스 / 체크 식별자)
  key checkid   : abap.char(30) not null;

  "! 메시지 ID. 공란 행은 해당 체크의 모든 메시지를 의미한다.
  "! 메시지 단위 행이 있으면 그것이 체크 전체 행보다 우선한다.
  key messageid : abap.char(30) not null;

  "! NAMING / PERF / SECURITY / CLOUD ...
  "! 적용범위 정책을 체크 종류별로 다르게 걸기 위한 분류축이다.
  checkgroup    : abap.char(10);

  "! 앱 취급 대상 여부. Phase 1 은 NAMING 행만 X.
  activeflg     : abap_boolean;

  "! --- 적용범위 허용 여부 ---
  "! 요건 "패키지/오브젝트 단위로만 등록" 이 지켜지는 지점.
  "! Phase 1 네이밍: fndactive 공란 / objactive X / pkgactive X
  "! Phase 2 에서 행을 추가하면 코드 변경 없이 열린다.
  "!   성능 체크 : fndactive X (라인별 판단이 본질) / pkgactive 공란
  "!   보안 체크 : fndactive X / objactive 공란 / pkgactive 공란
  "!              (패키지로 열면 그 패키지의 보안 검증이 통째로 꺼진다)
  fndactive     : abap_boolean;
  objactive     : abap_boolean;
  pkgactive     : abap_boolean;

  "! 최대 유효기간(개월). 0 이면 제한 없음. 무기한 예외를 막는다.
  maxvalidmon   : abap.int2;

  "! 사유 코드/근거 텍스트 필수 여부
  reasonreq     : abap_boolean;

  "! 예외 신청을 허용하는 최대 Priority. 0 이면 제한 없음.
  "! 예: 2 로 두면 Prio 1 위반은 신청 자체를 차단한다.
  maxpriority   : abap.int1;

  descr         : abap.char(60);

  include zscm00010;

}
