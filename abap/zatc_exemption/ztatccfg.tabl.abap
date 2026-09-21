@EndUserText.label : 'ATC Exemption Control Table'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #C
@AbapCatalog.dataMaintenance : #ALLOWED
// 업무 데이터가 아니라 앱의 동작 규칙을 담는 컨트롤 테이블이다.
//
// 키를 체크 변형으로 잡은 이유:
//   "어떤 체크를 대상으로 볼지" 는 표준이 이미 체크 변형으로 묶어놓았다.
//   체크 단위로 키를 잡으면 Phase 2 에서 수백 행을 손으로 등록해야 하고,
//   체크가 추가될 때마다 이 테이블을 손봐야 한다.
//   변형 단위면 Phase 1 은 1행, Phase 2 도 3~4행이면 끝나고, 체크 추가는
//   변형 관리로 흡수된다.
//
// 체크 마스터가 아니다. 체크의 실체(체크 클래스, 메시지 코드, 체크 제목)는
// 표준이 갖고 있고 finding 에 실려 온다. 이 테이블은 그 위에 우리 정책만 얹는다.
//
// 답하는 질문:
//   ① 이 변형의 결과가 앱의 관리 대상인가?  -> activeflg   (요건: 네이밍 건만)
//   ② 어떤 적용범위를 허용하는가?           -> *active 3종 (요건: 패키지/오브젝트만)
//   ③ 유효기간 상한은?                      -> maxvalidmon
//   ④ 어느 Priority 까지 예외를 허용하는가?  -> maxpriority
//
// 가동 전에 반드시 초기 데이터를 넣어야 한다. 비어 있으면 모든 신청이 거부되고
// 조회 목록도 비어 보인다.
//
// 승인 권한은 여기 두지 않는다. 권한 오브젝트 Z_ATCEXEM 의 SCOPETYPE 필드가
// 이미 "누가 어느 범위를 승인할 수 있는지" 를 표현하므로 이중 관리가 된다.
define table ztatccfg {

  key client      : abap.clnt not null;

  "! 체크 변형. SATC_API_FINDINGS-CHECKVARIANT 와 같은 값이다.
  "! 예: 네이밍 전용 변형 하나를 만들어 여기 등록한다.
  key checkvariant : abap.char(30) not null;

  "! NAMING / PERF / SECURITY / CLOUD ...
  "! 변형명은 버전이 붙어 바뀔 수 있으므로(Z_NAMING_V1 -> V2), 권한 역할에는
  "! 이 안정적인 분류값을 쓴다. 권한 오브젝트의 CHECKGRP 필드와 짝이다.
  checkgroup      : abap.char(10);

  "! 앱 취급 대상 여부. Phase 1 은 네이밍 변형 행만 X.
  activeflg       : abap_boolean;

  "! --- 적용범위 허용 여부 ---
  "! 요건 "패키지/오브젝트 단위로만 등록" 이 지켜지는 지점.
  "! Phase 1 네이밍: fndactive 공란 / objactive X / pkgactive X
  "! Phase 2 에서 행을 추가하면 코드 변경 없이 열린다.
  "!   성능 변형 : fndactive X (라인별 판단이 본질) / pkgactive 공란
  "!   보안 변형 : fndactive X / objactive 공란 / pkgactive 공란
  "!              (패키지로 열면 그 패키지의 보안 검증이 통째로 꺼진다)
  fndactive       : abap_boolean;
  objactive       : abap_boolean;
  pkgactive       : abap_boolean;

  "! 최대 유효기간(개월). 0 이면 제한 없음. 무기한 예외를 막는다.
  maxvalidmon     : abap.int2;

  "! 사유 코드/근거 텍스트 필수 여부
  reasonreq       : abap_boolean;

  "! 표준 예외의 이메일 알림 유형 (set_notification_type).
  "!   REJ  반려 시에만 / ALWS 승인·반려 모두 / NEVR 보내지 않음
  "! 조직 정책이라 코드에 박지 않는다.
  notiftype       : abap.char(4);

  "! 기본 승인자. 표준 예외를 승인대기로 올릴 때 send_to_approver( ) 가
  "! 받는 사람이다. 표준은 승인자 1명을 필수로 요구한다.
  "!
  "! 우리 앱의 승인 권한 자체는 이 값이 아니라 권한 오브젝트 Z_ATCEXEM 이
  "! 정한다. 이 필드는 "표준에 누구 앞으로 올릴 것인가" 만 정한다.
  defapprover     : abap.char(12);

  "! 예외 신청을 허용하는 최대 Priority. 0 이면 제한 없음.
  "! Priority 는 1 이 가장 심각하다. 2 로 두면 Prio 1 위반은 신청 자체를 차단한다.
  maxpriority     : abap.int1;

  include zscm00010;

}
