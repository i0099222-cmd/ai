*----------------------------------------------------------------------*
* HTML 템플릿 치환 + 메일 발송
*
* [1] 템플릿 테이블 (ADT > New > Database Table)
*
*   @EndUserText.label : 'HTML 템플릿'
*   @AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
*   @AbapCatalog.tableCategory : #TRANSPARENT
*   @AbapCatalog.deliveryClass : #C
*   @AbapCatalog.dataMaintenance : #RESTRICTED
*   define table zra_t_html_tpl {
*     key client      : abap.clnt not null;
*     key template_id : abap.char(30) not null;
*     description     : abap.char(60);
*     content         : abap.string(0);
*   }
*
* [2] 템플릿 데이터 (zra_t_html_tpl 에 저장)
*
*   ZRA_APPROVAL_MAIL
*   <html>
*   <head><meta charset="UTF-8"></head>
*   <body>
*     <h2>{TITLE}</h2>
*     <p>요청자: {USERNAME}</p>
*     <p>문서번호: {DOCNO}</p>
*     <table border="1" cellpadding="5" style="border-collapse:collapse;">
*       <tr><th>자재</th><th>자재명</th><th>수량</th></tr>
*       {ROWS}
*     </table>
*   </body>
*   </html>
*----------------------------------------------------------------------*
CLASS zra_cl_approval_request_hrc DEFINITION
 PUBLIC
 FINAL
 CREATE PUBLIC .

 PUBLIC SECTION.
   TYPES : BEGIN OF ty_s_replace,
             key   TYPE string,   " 템플릿의 치환 대상 (예: {TITLE})
             value TYPE string,   " 바꿀 값
           END OF ty_s_replace,
           ty_t_replace TYPE STANDARD TABLE OF ty_s_replace WITH EMPTY KEY.

   " 템플릿 읽기 + 치환
   CLASS-METHODS get_html_template
     IMPORTING
       VALUE(iv_template_id) TYPE zra_t_html_tpl-template_id
       VALUE(it_replace)     TYPE ty_t_replace
     RETURNING
       VALUE(rv_html)        TYPE string.

   " HTML 메일 발송
   CLASS-METHODS send_mail
     IMPORTING
       VALUE(iv_subject)  TYPE so_obj_des          " 제목
       VALUE(iv_html)     TYPE string              " get_html_template 결과
       VALUE(it_receiver) TYPE string_table        " 수신 메일주소
       VALUE(iv_sender)   TYPE ad_smtpadr OPTIONAL " 발신 메일주소
     RETURNING
       VALUE(rv_ok)       TYPE abap_bool.
 PROTECTED SECTION.
 PRIVATE SECTION.
ENDCLASS.

CLASS zra_cl_approval_request_hrc IMPLEMENTATION.

 METHOD get_html_template.

   " 1. 템플릿 읽기
   SELECT SINGLE content FROM zra_t_html_tpl
     WHERE template_id = @iv_template_id
     INTO @rv_html.

   " 2. 치환
   LOOP AT it_replace INTO DATA(ls_replace) WHERE key IS NOT INITIAL.
     REPLACE ALL OCCURRENCES OF ls_replace-key IN rv_html WITH ls_replace-value.
   ENDLOOP.

 ENDMETHOD.


 METHOD send_mail.

   TRY.
       DATA(lo_send) = cl_bcs=>create_persistent( ).

       " 본문 (HTML)
       lo_send->set_document( cl_document_bcs=>create_document(
                                i_type    = 'HTM'
                                i_subject = iv_subject
                                i_text    = cl_document_bcs=>string_to_soli( iv_html ) ) ).

       " 발신자 (생략 시 실행 사용자)
       IF iv_sender IS NOT INITIAL.
         lo_send->set_sender( cl_cam_address_bcs=>create_internet_address( iv_sender ) ).
       ENDIF.

       " 수신자
       LOOP AT it_receiver INTO DATA(lv_receiver).
         lo_send->add_recipient( cl_cam_address_bcs=>create_internet_address( CONV #( lv_receiver ) ) ).
       ENDLOOP.

       lo_send->set_send_immediately( abap_true ).
       rv_ok = lo_send->send( ).

     CATCH cx_bcs.
       rv_ok = abap_false.
   ENDTRY.

 ENDMETHOD.

ENDCLASS.

*----------------------------------------------------------------------*
* [3] 호출 예시
*
*   DATA lv_rows TYPE string.
*
*   " 1. 조회 건수만큼 행 만들기
*   LOOP AT lt_item INTO DATA(ls_item).
*     lv_rows = lv_rows && |<tr><td>{ ls_item-matnr }</td><td>{ ls_item-maktx }</td><td>{ ls_item-menge NUMBER = USER }</td></tr>|.
*   ENDLOOP.
*
*   " 2. 본문에 값 + 행 넣기
*   DATA(lv_html) = zra_cl_approval_request_hrc=>get_html_template(
*                     iv_template_id = 'ZRA_APPROVAL_MAIL'
*                     it_replace     = VALUE #( ( key = '{TITLE}'    value = lv_title )
*                                               ( key = '{USERNAME}' value = lv_username )
*                                               ( key = '{DOCNO}'    value = lv_docno )
*                                               ( key = '{ROWS}'     value = lv_rows ) ) ).
*
*   " 3. 메일 발송 (리포트: 호출 후 COMMIT WORK / RAP: saver 의 save_modified 에서 호출, COMMIT 금지)
*   DATA(lv_ok) = zra_cl_approval_request_hrc=>send_mail(
*                   iv_subject  = '결재 요청'
*                   iv_html     = lv_html
*                   it_receiver = VALUE #( ( `test@company.com` ) ) ).
*----------------------------------------------------------------------*
