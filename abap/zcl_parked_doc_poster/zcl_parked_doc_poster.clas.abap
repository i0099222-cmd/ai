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
    " 실제 확인된 시그니처(TABLES): T_VBKPF / T_MSG_TAB
    " TODO: VBKPF 라인에 BUKRS/BELNR/GJAHR 외 추가 필드(BLART, BUDAT 등)가
    " 필요한지 SE37에서 확인할 것. MSG_TAB_LINE의 실제 필드명(에러 판정에
    " 쓰는 타입 필드 등)도 SE11에서 확인 후 아래 TODO 부분을 맞출 것.
    " ------------------------------------------------------------------
    DATA: lt_vbkpf  TYPE STANDARD TABLE OF vbkpf WITH DEFAULT KEY,
          lt_return TYPE zif_parked_doc_poster=>tt_message.

    lt_vbkpf = VALUE #(
      FOR ls_key IN it_keys
      ( bukrs = ls_key-bukrs
        belnr = ls_key-belnr
        gjahr = ls_key-gjahr ) ).

    CALL FUNCTION 'PRELIMINARY_POSTING_POST_ALL'
      TABLES
        t_vbkpf   = lt_vbkpf
        t_msg_tab = lt_return
      EXCEPTIONS
        OTHERS    = 1.

    DATA(lv_has_error) = xsdbool( line_exists( lt_return[ msgty = 'E' ] )   " TODO: 실제 필드명(msgty 등) 확인
                               OR line_exists( lt_return[ msgty = 'A' ] ) ).

    IF sy-subrc = 0 AND lv_has_error = abap_false.
      COMMIT WORK AND WAIT.
    ELSE.
      ROLLBACK WORK.
    ENDIF.

    " ------------------------------------------------------------------
    " FM이 문서별 리턴을 구분할 수 있는 필드(예: 메시지 변수에 BELNR 포함)를
    " 주는지 확인 후, 문서 단위 개별 성공/실패 판정이 필요하면 이 매핑을
    " 보완할 것. 지금은 그룹(BUKRS) 전체 성공/실패를 각 문서에 동일 적용하는
    " 단순 버전이며, 메시지 테이블은 가공 없이 그대로 각 결과에 실어 보낸다.
    " ------------------------------------------------------------------
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
