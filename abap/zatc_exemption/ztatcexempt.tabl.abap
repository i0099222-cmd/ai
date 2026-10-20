@EndUserText.label : 'ATC Exemption Request Header'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
// 요청서. 한 요청서에 대상(오브젝트/패키지)이 여러 줄 붙는다(ztatcexempti).
// 사유·유효기간·상태는 요청서 단위다. 승인/반려도 요청서 단위로 한 번에 한다.
// 체크 클래스는 대상 줄마다 다를 수 있다. 표준 예외는 대상 한 줄마다 1건이고,
// 그 ID 는 아이템이 든다.
define table ztatcexempt {

  key client        : abap.clnt not null;

  "! 요청서 GUID. RAP BO 키.
  key exemptuuid    : sysuuid_x16 not null;

  "! 요청 번호(ATCX-2026000012). 처음 저장할 때 번호 범위 ZATCEXREQ 의 그해 구간에서 일련번호를
  "! 받아 zif_atc_exemption=>reqnumber 의 접두어와 연도를 붙인다. 접두어 5자 + 연도 4 + 일련번호 6 = 15자.
  "! 목록과 헤더에서 요청서를 부르는 이름이다.
  "! 버퍼링 때문에 빈 번호가 생길 수 있다. 연속일 필요는 없다.
  reqnumber         : abap.char(15);

  "! 사유 코드. 표준 set_reason( i_reason ) 으로 그대로 넘어간다.
  reasoncode        : abap.char(4);

  "! 근거 텍스트. 감사 대응 시 유일한 서술 근거이므로 최소 길이를 검증한다.
  reasontext        : abap.string(0);

  validfrom         : abap.dats;

  "! 유효종료일. 필수이며 상한은 zif_atc_exemption=>policy-maxvalidmon 이다.
  validto           : abap.dats;

  "! 10 초안 / 20 승인대기 / 30 승인 / 40 반려 / 50 철회 / 60 만료
  exemptstat        : abap.char(2);

  requester         : abap.char(12);

  approver          : abap.char(12);

  approvedat        : timestampl;

  "! CBO 공통 이력 구조. createdby / createdat / 변경자 / 변경일시를 제공한다.
  include zscm00010;

  "! RAP OCC(etag master)용 로컬 변경 타임스탬프.
  loclastchgat      : timestampl;

}
