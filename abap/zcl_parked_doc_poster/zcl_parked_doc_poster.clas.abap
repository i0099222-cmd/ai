CLASS zcl_parked_doc_poster DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_parked_doc_poster.

  PRIVATE SECTION.
    "! FM 1회 호출 단위(FM이 mass 처리 가능한지에 따라 회사코드/연도 단위로 묶어서 호출)
    METHODS post_one_company
      IMPORTING
        iv_bukrs         TYPE bukrs
        it_keys          TYPE zif_parked_doc_poster=>tt_key
      RETURNING
        VALUE(rt_result) TYPE zif_parked_doc_poster=>tt_result.

ENDCLASS.


CLASS zcl_parked_doc_poster IMPLEMENTATION.

  METHOD zif_parked_doc_poster~post_all.

    CHECK it_keys IS NOT INITIAL.

    " FM이 회사코드 단위로 동작하는 경우가 많아 BUKRS 기준으로 묶어서 호출한다.
    LOOP AT it_keys INTO DATA(ls_key) GROUP BY ls_key-bukrs
         REFERENCE INTO DATA(lr_group).

      DATA(lt_keys_of_bukrs) = VALUE zif_parked_doc_poster=>tt_key(
        FOR <k> IN it_keys WHERE ( bukrs = lr_group->bukrs )
        ( <k> )
      ).

      rt_result = VALUE #( BASE rt_result
        ( LINES OF post_one_company(
                    iv_bukrs = lr_group->bukrs
                    it_keys  = lt_keys_of_bukrs ) ) ).

    ENDLOOP.

  ENDMETHOD.


  METHOD post_one_company.

    " ------------------------------------------------------------------
    " TODO: 실제 PRELIMINARY_POSTING_POST_ALL 시그니처는 SE37/ADT에서
    " 확인 후 아래 IMPORTING/TABLES 구조에 맞춰 채워 넣을 것.
    " (릴리즈/모듈에 따라 파라미터명이 다를 수 있음)
    " ------------------------------------------------------------------
    DATA: lt_belnr  TYPE STANDARD TABLE OF belnr_d,   " TODO: FM TABLES 파라미터 타입으로 교체
          lt_return TYPE bapiret2_t.

    lt_belnr = VALUE #( FOR ls_key IN it_keys ( ls_key-belnr ) ).

    CALL FUNCTION 'PRELIMINARY_POSTING_POST_ALL'
      EXPORTING
        i_bukrs  = iv_bukrs                          " TODO: 실제 파라미터명 확인
*     IMPORTING
*       ...
      TABLES
        t_belnr  = lt_belnr                          " TODO: 실제 파라미터명 확인
        t_return = lt_return                         " TODO: 실제 파라미터명 확인
      EXCEPTIONS
        OTHERS   = 1.

    IF sy-subrc = 0 AND NOT line_exists( lt_return[ type = 'E' ] )
                    AND NOT line_exists( lt_return[ type = 'A' ] ).
      COMMIT WORK AND WAIT.
    ELSE.
      ROLLBACK WORK.
    ENDIF.

    " ------------------------------------------------------------------
    " FM 리턴(BAPIRET2)을 요청 키 단위 결과로 매핑.
    " FM이 문서별 리턴을 어떤 필드(예: MESSAGE_V1=BELNR)로 구분해서 주는지
    " 확인 후 이 매핑 로직을 맞춰야 함. 아래는 "전체 성공/실패를 함께 판단"하는
    " 단순 버전이며, 문서 단위 개별 판정이 필요하면 BAPIRET2-ID/NUMBER나
    " MESSAGE_V1 등으로 BELNR을 식별해 개별 매핑하도록 보완할 것.
    " ------------------------------------------------------------------
    DATA(lv_has_error) = xsdbool( line_exists( lt_return[ type = 'E' ] )
                               OR line_exists( lt_return[ type = 'A' ] ) ).

    rt_result = VALUE #(
      FOR ls_key IN it_keys
      ( bukrs     = ls_key-bukrs
        belnr     = ls_key-belnr
        gjahr     = ls_key-gjahr
        belnr_new = ls_key-belnr   " TODO: FM이 신규 확정전표 번호를 반환하면 그 값으로 교체
        success   = xsdbool( lv_has_error = abap_false )
        t_message = lt_return )
    ).

  ENDMETHOD.

ENDCLASS.
