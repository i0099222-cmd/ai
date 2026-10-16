@EndUserText.label : 'ATC Exemption Request Target'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
// 요청서의 대상 한 줄 = 표준 예외 1건 = 패키지 또는 오브젝트 하나 × 체크 클래스 하나.
// 오브젝트(유형/이름)를 넣으면 오브젝트 대상(OBJ), 패키지만 넣으면 패키지 대상(PCKG)이다.
define table ztatcexempti {

  key client     : abap.clnt not null;

  key itemuuid   : sysuuid_x16 not null;

  "! 상위 요청서
  exemptuuid     : sysuuid_x16 not null;

  itemno         : abap.int4;

  "! 적용 범위. OBJ / PCKG. 오브젝트 입력 여부로 정해진다(사용자가 고르지 않는다).
  scopetype      : abap.char(4);

  "! 대상 패키지. OBJ 는 TADIR 에서 파생된다.
  devclass       : devclass;

  "! 대상 오브젝트. PCKG 는 비어 있다.
  objecttype     : trobjtype;
  objectname     : sobj_name;

  "! 체크 클래스. 표준 create_exemption( i_check_class ) 에 넘기는 값이다(필수).
  checkclass     : abap.char(30);

  "! 대상 메시지 코드. 비우면 그 체크의 모든 메시지(CHK)다.
  checkcode      : abap.char(10);

  "! 규칙 적용 축. 코드가 있는 OBJ -> MSG(메시지 1개), 그 외 -> CHK(체크 전체)
  rulescope      : abap.char(3);

  "! 이 줄의 표준 예외 ID (SATC_CI_EXEMPTION_ID = SYSUUID_C32).
  extexemptid    : sysuuid_c32;

  "! 표준 쪽 진행 상태. 공란 없음 / P 승인대기 / A 승인 / R 반려.
  "! 승인·반려가 중간에 실패하면 이미 처리된 줄을 다시 처리하지 않기 위해 둔다.
  stdstatus      : abap.char(1);

  include zscm00010;

  "! RAP OCC 용 로컬 변경 타임스탬프
  loclastchgat   : timestampl;

}
