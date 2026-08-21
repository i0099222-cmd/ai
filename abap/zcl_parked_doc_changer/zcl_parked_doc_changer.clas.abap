"! 임시전표(파킹 문서) 수정 공통 클래스.
"! 실제 수정 로직(BDC/CALL TRANSACTION 'FBV2')은 이 클래스가 아니라
"! Z_FI_PARKED_DOC_CHANGE_BDC 함수모듈에 있고, 이 클래스는 그 FM만 호출한다.
"! CALL TRANSACTION 같은 obsolete statement는 그 FM에만 있으므로,
"! 이 클래스 자체는 ABAP Cloud 언어버전으로 두어도 되며, FM 쪽만
"! Standard ABAP 언어버전 + Local Release 대상이다.
"!
"! RAP behavior handler 에서 그냥 이 클래스를 호출하면 된다.
"! (FM 을 직접 CALL FUNCTION 해도 동작은 같다)
CLASS zcl_parked_doc_changer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! 임시전표 1건의 헤더/명세 필드를 수정한다(FBV2 BDC 호출).
    "! @parameter is_header      | 키 + 변경할 헤더 필드
    "! @parameter it_item        | 변경할 명세 목록
    "! @parameter ev_messagetype | 'S' 성공 / 'E' 오류
    "! @parameter ev_messagetext | 결과 메시지 텍스트
    "! @parameter et_message     | CALL TRANSACTION 원본 메시지(BDCMSGCOLL)
    CLASS-METHODS change
      IMPORTING
        is_header      TYPE zsfi_parked_hdr
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
        is_header      = is_header
        it_item        = it_item
      IMPORTING
        ev_messagetype = ev_messagetype
        ev_messagetext = ev_messagetext
        et_message     = et_message.

  ENDMETHOD.

ENDCLASS.
