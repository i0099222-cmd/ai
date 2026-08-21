"! 임시전표(파킹 문서) 수정 공통 클래스.
"! 실제 수정 로직(BDC/CALL TRANSACTION 'FBV2')은 이 클래스가 아니라
"! Z_FI_PARKED_DOC_CHANGE_BDC 함수모듈에 있고, 이 클래스는 그 FM만 호출한다.
"! CALL TRANSACTION 같은 obsolete statement는 그 FM에만 있으므로,
"! 이 클래스 자체는 ABAP Cloud 언어버전으로 두어도 되며, FM 쪽만
"! Standard ABAP 언어버전 + Local Release 대상이다.
CLASS zcl_parked_doc_changer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_parked_doc_changer.

ENDCLASS.


CLASS zcl_parked_doc_changer IMPLEMENTATION.

  METHOD zif_parked_doc_changer~change.

    CALL FUNCTION 'Z_FI_PARKED_DOC_CHANGE_BDC'
      EXPORTING
        is_header      = is_header
        it_item        = it_item
      IMPORTING
        ev_messagetype = rs_result-messagetype
        ev_messagetext = rs_result-messagetext
        et_message     = rs_result-t_message.

    rs_result-bukrs = is_header-bukrs.
    rs_result-belnr = is_header-belnr.
    rs_result-gjahr = is_header-gjahr.

  ENDMETHOD.

ENDCLASS.
