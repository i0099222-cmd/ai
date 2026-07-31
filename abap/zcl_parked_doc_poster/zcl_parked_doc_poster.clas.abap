"! 임시전표(파킹 문서) -> 확정전표 전기 공통 클래스.
"! 실제 전기 로직(BDC/CALL TRANSACTION 'FBV0')은 이 클래스가 아니라
"! Z_FI_PARKED_DOC_POST_BDC 함수모듈에 있고, 이 클래스는 그 FM만 호출한다.
"! CALL TRANSACTION 같은 obsolete statement는 그 FM에만 있으므로,
"! 이 클래스 자체는 ABAP Cloud 언어버전으로 두어도 되며, FM 쪽만
"! Standard ABAP 언어버전 + Local Release 대상이다.
CLASS zcl_parked_doc_poster DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_parked_doc_poster.

ENDCLASS.


CLASS zcl_parked_doc_poster IMPLEMENTATION.

  METHOD zif_parked_doc_poster~post_all.

    " FBV0는 BDC로 한 번에 문서 1건만 처리 가능하므로 키 단위로 순차 호출한다.
    LOOP AT it_keys INTO DATA(ls_key).

      CALL FUNCTION 'Z_FI_PARKED_DOC_POST_BDC'
        EXPORTING
          is_key    = ls_key
        IMPORTING
          es_result = DATA(ls_result).

      APPEND ls_result TO rt_result.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
