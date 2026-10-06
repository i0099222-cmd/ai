@EndUserText.label : 'ATC Exemption Request Header'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
// 요청서. 한 요청서에 대상(오브젝트/패키지)이 여러 줄 붙는다(ztatcexempti).
// 사유·유효기간·체크·상태는 요청서 단위다. 승인/반려도 요청서 단위로 한 번에 한다.
// 표준 예외는 대상 한 줄마다 1건이고, 그 ID 는 아이템이 든다.
define table ztatcexempt {

  key client        : abap.clnt not null;

  "! 요청서 GUID. RAP BO 키.
  key exemptuuid    : sysuuid_x16 not null;

  "! 요청 제목. 신청번호가 없으므로 목록에서 요청서를 부르는 이름이다.
  title             : abap.char(80);

  "! 체크 변형. 체크 클래스 값 도움을 거르는 데 쓴다.
  checkvariant      : abap.char(30);

  "! 대상 체크 클래스. 표준 create_exemption( i_check_class ) 에 넘기는 값이다.
  "! 요청서의 모든 대상에 같은 체크가 걸린다.
  checkclass        : abap.char(30);

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
