*----------------------------------------------------------------------*
* HTML 템플릿 동적 테이블 샘플 (ADT 에서 F9 로 실행)
*
* [1] zra_t_html_tpl 에 등록할 HTML (TEMPLATE_ID = ZRA_APPROVAL_MAIL)
*
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
*
* [2] 아래 클래스 실행 → 콘솔에 품목 3줄짜리 표가 들어간 HTML 출력
*     (테스트 데이터를 SELECT 결과로 바꾸면 조회 건수만큼 행이 늘고 줄어든다)
*----------------------------------------------------------------------*
CLASS zra_cl_html_tpl_sample DEFINITION
 PUBLIC
 FINAL
 CREATE PUBLIC .

 PUBLIC SECTION.
   INTERFACES if_oo_adt_classrun.
 PROTECTED SECTION.
 PRIVATE SECTION.
ENDCLASS.

CLASS zra_cl_html_tpl_sample IMPLEMENTATION.

 METHOD if_oo_adt_classrun~main.

   TYPES : BEGIN OF ty_item,
             matnr TYPE string,
             maktx TYPE string,
             menge TYPE i,
           END OF ty_item,
           tt_item TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

   DATA lv_rows TYPE string.

   " 1. 테스트 데이터 (실제로는 SELECT 결과)
   DATA(lt_item) = VALUE tt_item( ( matnr = 'M-001' maktx = '노트북' menge = 2 )
                                  ( matnr = 'M-002' maktx = '모니터' menge = 1 )
                                  ( matnr = 'M-003' maktx = '마우스' menge = 5 ) ).

   " 2. 조회 건수만큼 행 만들기
   LOOP AT lt_item INTO DATA(ls_item).
     lv_rows = lv_rows && |<tr><td>{ ls_item-matnr }</td><td>{ ls_item-maktx }</td><td>{ ls_item-menge }</td></tr>|.
   ENDLOOP.

   " 3. 템플릿 치환
   DATA(lv_html) = zra_cl_approval_request_hrc=>get_html_template(
                     iv_template_id = 'ZRA_APPROVAL_MAIL'
                     it_replace     = VALUE #( ( key = '{TITLE}'    value = '결재 요청' )
                                               ( key = '{USERNAME}' value = '홍길동' )
                                               ( key = '{DOCNO}'    value = 'REQ-0001' )
                                               ( key = '{ROWS}'     value = lv_rows ) ) ).

   out->write( lv_html ).

 ENDMETHOD.

ENDCLASS.
