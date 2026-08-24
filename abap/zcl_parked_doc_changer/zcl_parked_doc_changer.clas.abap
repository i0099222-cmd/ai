"! 임시전표(파킹 문서) 수정 공통 클래스.
"! 실제 수정 로직(BDC/CALL TRANSACTION 'FBV2')은 Z_FI_PARKED_DOC_CHANGE_BDC
"! 함수모듈에 있고, 이 클래스는 그 FM만 호출한다.
"! CALL TRANSACTION 같은 obsolete statement는 FM 쪽에만 있으므로,
"! 이 클래스는 ABAP Cloud 언어버전으로 두어도 되고 FM만
"! Standard ABAP 언어버전 + Local Release 대상이다.
CLASS zcl_parked_doc_changer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! 임시전표 1건의 헤더/명세 필드를 수정한다(FBV2 BDC 호출).
    CLASS-METHODS change
      IMPORTING
        i_bukrs        TYPE bukrs
        i_belnr        TYPE belnr_d
        i_gjahr        TYPE gjahr
        i_bktxt        TYPE bktxt  OPTIONAL
        i_xblnr        TYPE xblnr1 OPTIONAL
        it_item        TYPE ztfi_parked_itm OPTIONAL
      EXPORTING
        ev_messagetype TYPE symsgty
        ev_messagetext TYPE string
        et_message     TYPE tab_bdcmsgcoll.

ENDCLASS.


CLASS zcl_parked_doc_changer IMPLEMENTATION.

  METHOD change.

    CLEAR: ev_messagetype, ev_messagetext, et_message.

    CALL FUNCTION 'Z_FI_PARKED_DOC_CHANGE_BDC'
      EXPORTING
        i_bukrs        = i_bukrs
        i_belnr        = i_belnr
        i_gjahr        = i_gjahr
        i_bktxt        = i_bktxt
        i_xblnr        = i_xblnr
        it_item        = it_item
      IMPORTING
        ev_messagetype = ev_messagetype
        ev_messagetext = ev_messagetext
        et_message     = et_message.

  ENDMETHOD.

ENDCLASS.
