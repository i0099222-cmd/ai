@EndUserText.label : 'ATC 예외 신청 상태 이력'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztatcexemptlog {

  key client    : abap.clnt not null;

  key loguuid   : sysuuid_x16 not null;

  "! 상위 신청서
  exemptuuid    : sysuuid_x16 not null;

  seqnr         : abap.int4;

  "! SUBMIT / WITHDRAW / APPROVE / REJECT / REVOKE / EXPIRE / SYNC
  actioncode    : abap.char(10);

  fromstat      : abap.char(2);
  tostat        : abap.char(2);

  "! 반려 사유 등 코멘트
  commenttxt    : abap.string(0);

  actionby      : abap.char(12);
  actionat      : timestampl;

  include zscm00010;

}
