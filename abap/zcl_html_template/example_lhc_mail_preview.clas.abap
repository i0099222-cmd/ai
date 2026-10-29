"! 예시: 개별 RAP BO(예: ZI_PurchaseRequest)의 behavior implementation에서
"! 공통 클래스 zcl_html_template 로 메일 본문 HTML 을 만드는 예시.
"!
"! 전제
"!   - SMW0 > 바이너리 데이터 에 sample_approval_mail.html 을 ZPR_APPROVAL_MAIL 로 업로드
"!   - behavior definition 에
"!       action previewMail result [1] ZA_MailPreview;
"!     ZA_MailPreview 는 Html : abap.string 필드 하나를 가진 abstract entity
"!   - 메일을 실제로 보낼 때는 DB 쓰기가 일어나므로 interaction phase(액션)가 아니라
"!     saver 의 save_modified 에서 같은 방식으로 HTML 을 만든 뒤 발송한다.

CLASS lhc_purchaserequest DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS previewmail FOR MODIFY
      IMPORTING keys FOR ACTION purchaserequest~previewmail RESULT result.

ENDCLASS.


CLASS lhc_purchaserequest IMPLEMENTATION.

  METHOD previewmail.

    " 1) 헤더 + 품목 조회
    READ ENTITIES OF zi_purchaserequest IN LOCAL MODE
      ENTITY purchaserequest
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_header)
      ENTITY purchaserequest BY \_item
        ALL FIELDS WITH CORRESPONDING #( keys )
        RESULT DATA(lt_item).

    LOOP AT lt_header INTO DATA(ls_header).

      DATA(lt_item_of_header) = lt_item.
      DELETE lt_item_of_header WHERE purchaserequestid <> ls_header-purchaserequestid.

      TRY.
          " 2) 템플릿 로드 + 치환
          "    CDS 필드명(대문자)이 그대로 {{PURCHASEREQUESTID}} 같은 이름이 된다.
          DATA(lv_html) = zcl_html_template=>create_from_smw0( 'ZPR_APPROVAL_MAIL'
            )->set_structure( is_data   = ls_header
                              it_amount = VALUE #( ( amount = 'TOTALAMOUNT' currency = 'CURRENCY' ) )
            )->set( iv_name  = 'TODAY'
                    iv_value = cl_abap_context_info=>get_system_date( )
            )->set_table( iv_name   = 'ITEMS'
                          it_data   = lt_item_of_header
                          it_amount = VALUE #( ( amount = 'NETAMOUNT' currency = 'CURRENCY' ) )
            )->render( ).

          APPEND VALUE #( %tky        = ls_header-%tky
                          %param-html = lv_html ) TO result.

        CATCH zcx_html_template INTO DATA(lx_template).
          " 3) 템플릿 오류(SMW0 미등록, 태그 짝 안 맞음 등)는 RAP 메시지로 변환
          APPEND VALUE #( %tky = ls_header-%tky ) TO failed-purchaserequest.

          APPEND VALUE #( %tky = ls_header-%tky
                          %msg = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = lx_template->get_text( ) ) )
                 TO reported-purchaserequest.
      ENDTRY.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
