"! 예시: 개별 RAP BO(예: ZI_Document)의 behavior implementation에서
"! 공통 클래스 zcl_parked_doc_poster를 호출하는 parkedPost 액션 구현 예시.
"! 실제 프로젝트에서는 각 BO의 CDS behavior definition에
"!   action parkedPost result [1] $self;
"! 를 정의하고, 이 handler에서 zcl_parked_doc_poster를 호출한다.

CLASS lhc_document DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS parkedpost FOR MODIFY
      IMPORTING keys FOR ACTION document~parkedpost RESULT result.

ENDCLASS.


CLASS lhc_document IMPLEMENTATION.

  METHOD parkedpost.

    " 1) RAP 키로부터 확정 전기 대상 임시전표 정보 조회
    READ ENTITIES OF zi_document IN LOCAL MODE
      ENTITY document
        FIELDS ( bukrs belnr gjahr )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_document)
      FAILED DATA(lt_read_failed).

    APPEND LINES OF CORRESPONDING #( lt_read_failed-document ) TO failed-document.

    CHECK lt_document IS NOT INITIAL.

    " 2) 공통 클래스로 확정 전기 위임
    DATA(lt_keys) = VALUE zif_parked_doc_poster=>tt_key(
      FOR ls_doc IN lt_document
      ( bukrs = ls_doc-bukrs belnr = ls_doc-belnr gjahr = ls_doc-gjahr )
    ).

    DATA(lo_poster) = NEW zcl_parked_doc_poster( ).
    DATA(lt_result) = lo_poster->zif_parked_doc_poster~post_all( lt_keys ).

    " 3) 결과를 RAP mapped/reported/failed로 변환
    LOOP AT lt_document INTO DATA(ls_document).

      DATA(ls_result) = VALUE #( lt_result[
        bukrs = ls_document-bukrs
        belnr = ls_document-belnr
        gjahr = ls_document-gjahr ] OPTIONAL ).

      IF ls_result-success = abap_true.

        APPEND VALUE #( %tky = ls_document-%tky ) TO mapped-document.

        APPEND VALUE #( %tky   = ls_document-%tky
                         %param = CORRESPONDING #( ls_document ) )
               TO result.

      ELSE.

        APPEND VALUE #( %tky = ls_document-%tky ) TO failed-document.

        " CALL TRANSACTION 'FBV0' ... MESSAGES INTO 결과(BDCMSGCOLL)를 RAP 메시지로 변환
        LOOP AT ls_result-t_message INTO DATA(ls_msg) WHERE msgtyp CA 'EA'.
          APPEND VALUE #(
            %tky = ls_document-%tky
            %msg = new_message(
                     id       = ls_msg-msgid
                     number   = ls_msg-msgnr
                     v1       = ls_msg-msgv1
                     v2       = ls_msg-msgv2
                     v3       = ls_msg-msgv3
                     v4       = ls_msg-msgv4
                     severity = if_abap_behv_message=>severity-error ) )
            TO reported-document.
        ENDLOOP.

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
