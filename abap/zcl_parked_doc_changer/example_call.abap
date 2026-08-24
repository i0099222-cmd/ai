*&---------------------------------------------------------------------*
*& 호출 예시 - Z_FI_PARKED_DOC_CHANGE_BDC / ZCL_PARKED_DOC_CHANGER
*&---------------------------------------------------------------------*
*& FM 은 명세 1건을 처리한다. 여러 건이면 호출하는 쪽에서 루프를 돈다.
*& 값이 채워진 필드만 변경된다. 안 넘기면 그 필드는 손대지 않는다.
*&---------------------------------------------------------------------*

DATA: lv_msgty   TYPE symsgty,
      lv_msgtx   TYPE string,
      lt_message TYPE tab_bdcmsgcoll.

" [예시 1] 명세 1건만 수정 (채권/채무 명세)
DATA(ls_item) = VALUE zsfi_parked_itm(
  buzei = 1
  dynnr = '0302'                 " 채권/채무 명세. G/L 이면 생략(= 0300)
  sgtxt = 'ITEM TEXT'
  zuonr = 'ASSIGN-01'
  zterm = 'ZB01'
  zfbdt = '20260901'
  hzuon = 'HZUON-01'             " 추가 데이터 팝업 필드
  xref1 = 'REF1' ).

zcl_parked_doc_changer=>change(
  EXPORTING
    i_bukrs        = '1000'
    i_belnr        = '3120000133'
    i_gjahr        = '2026'
    is_item        = ls_item
  IMPORTING
    ev_messagetype = lv_msgty      " 'S' / 'E'
    ev_messagetext = lv_msgtx      " Document has been updated / Failed to update the document
    et_message     = lt_message ).


" [예시 2] 헤더 + 명세 여러 건 - 호출하는 쪽에서 루프
DATA(lt_item) = VALUE ztfi_parked_itm_local(
  ( buzei = 1 dynnr = '0302' sgtxt = 'AAA' )
  ( buzei = 2 dynnr = '0300' sgtxt = 'BBB' ) ).

LOOP AT lt_item INTO DATA(ls_line).

  zcl_parked_doc_changer=>change(
    EXPORTING
      i_bukrs        = '1000'
      i_belnr        = '3120000133'
      i_gjahr        = '2026'
      " 헤더는 첫 회차에만 같이 넘긴다
      i_bktxt        = COND #( WHEN sy-tabix = 1 THEN 'HEADER TEXT' )
      i_xblnr        = COND #( WHEN sy-tabix = 1 THEN 'REF-0001' )
      is_item        = ls_line
    IMPORTING
      ev_messagetype = lv_msgty
      ev_messagetext = lv_msgtx
      et_message     = lt_message ).

  " 한 건이라도 실패하면 중단한다. 앞 회차는 이미 저장된 상태다.
  IF lv_msgty = 'E'.
    EXIT.
  ENDIF.

ENDLOOP.


" [예시 3] 헤더만 수정 - IS_ITEM 없이 호출
zcl_parked_doc_changer=>change(
  EXPORTING
    i_bukrs        = '1000'
    i_belnr        = '3120000133'
    i_gjahr        = '2026'
    i_bktxt        = 'HEADER ONLY'
  IMPORTING
    ev_messagetype = lv_msgty
    ev_messagetext = lv_msgtx
    et_message     = lt_message ).

" 주의
"  1) DYNNR 은 명세 유형별 상세화면 번호다. G/L=0300(기본), 채권/채무=0302.
"     틀리게 넘기면 "화면이 다름" 오류가 난다.
"  2) G/L 명세에는 ZTERM/ZFBDT 등 지급 관련 필드가 화면에 없으므로
"     해당 명세에는 그 필드들을 넘기지 않는다.
"  3) BUZEI 를 개요화면 테이블컨트롤 행 번호로 그대로 쓴다.
"     명세가 많아 스크롤이 필요한 전표는 페이징(P+) 블록 추가 필요.
"  4) 값을 공란으로 지우는 기능은 없다(빈 값 = 변경 안 함).
"  5) 호출 1회당 CALL TRANSACTION 1회(= COMMIT 1회)다.
"     ztfi_parked_itm_local 은 예시용이며, 호출하는 쪽에서 쓰는
"     내부 테이블 타입으로 각자 선언하면 된다.
