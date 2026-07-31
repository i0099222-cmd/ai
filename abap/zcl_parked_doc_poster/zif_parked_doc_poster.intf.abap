INTERFACE zif_parked_doc_poster
  PUBLIC.

  "! 확정 전기 대상 임시전표 키
  TYPES:
    BEGIN OF ty_key,
      bukrs TYPE bukrs,
      belnr TYPE belnr_d,
      gjahr TYPE gjahr,
    END OF ty_key,
    tt_key TYPE STANDARD TABLE OF ty_key WITH EMPTY KEY.

  "! 문서 1건당 확정 전기 결과
  TYPES:
    BEGIN OF ty_result,
      bukrs     TYPE bukrs,
      belnr     TYPE belnr_d,
      gjahr     TYPE gjahr,
      belnr_new TYPE belnr_d,
      success   TYPE abap_bool,
      t_message TYPE bapiret2_t,
    END OF ty_result,
    tt_result TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY.

  "! 임시전표(들)을 확정전표로 전기한다.
  "! 여러 RAP BO의 parked_Post 액션에서 공통으로 호출하기 위한 진입점.
  METHODS post_all
    IMPORTING
      it_keys          TYPE tt_key
    RETURNING
      VALUE(rt_result) TYPE tt_result.

ENDINTERFACE.
