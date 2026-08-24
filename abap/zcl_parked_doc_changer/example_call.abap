*&---------------------------------------------------------------------*
*& 호출 예시 - Z_FI_PARKED_DOC_CHANGE_BDC / ZCL_PARKED_DOC_CHANGER
*&---------------------------------------------------------------------*
*& 값이 채워진 필드만 변경된다. 안 넘기면 그 필드는 손대지 않는다.
*&---------------------------------------------------------------------*

DATA: lv_msgty   TYPE symsgty,
      lv_msgtx   TYPE string,
      lt_message TYPE tab_bdcmsgcoll.

" 명세 여러 건 + 헤더를 한 번에 넘긴다.
DATA(lt_item) = VALUE ztfi_parked_itm(
  " 채권/채무 명세 - 상세화면 필드 + 추가데이터 팝업 필드
  ( buzei = 1
    sgtxt = 'ITEM TEXT'
    zuonr = 'ASSIGN-01'
    zterm = 'ZB01'
    zfbdt = '20260901'
    zbd1t = 10
    zbd1p = '3.000'
    hzuon = 'HZUON-01'             " 추가데이터 팝업 필드
    xref1 = 'REF1' )
  " G/L 명세 - 상세화면 필드만
  ( buzei = 2
    sgtxt = 'GL ITEM TEXT' ) ).

zcl_parked_doc_changer=>change(
  EXPORTING
    i_bukrs        = '1000'
    i_belnr        = '3120000133'
    i_gjahr        = '2026'
    i_bktxt        = 'HEADER TEXT'
    i_xblnr        = 'REF-0001'
    it_item        = lt_item
  IMPORTING
    ev_messagetype = lv_msgty      " 'S' / 'E'
    ev_messagetext = lv_msgtx      " Document has been updated / Failed to update the document
    et_message     = lt_message ).


" 헤더만 수정할 때는 IT_ITEM 없이 호출한다.
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
"  1) 명세 유형별 상세화면(G/L 0300 / 채권·채무 0302)은 FM 이
"     VBSEGK/VBSEGD 조회로 알아서 판단한다. 넘길 게 없다.
"  2) G/L 명세에는 ZTERM/ZFBDT 등 지급 관련 필드가 화면에 없으므로
"     해당 명세에는 그 필드들을 넘기지 않는다.
"  3) BUZEI 를 개요화면 테이블컨트롤 행 번호로 그대로 쓴다.
"     명세가 많아 스크롤이 필요한 전표는 페이징(P+) 블록 추가 필요.
"  4) 값을 공란으로 지우는 기능은 없다(빈 값 = 변경 안 함).
"  5) 명세 1건당 CALL TRANSACTION 1회(= 저장 1회)씩 수행된다.
"     '=BP'(저장)가 트랜잭션을 끝내기 때문에 한 번에 여러 명세를 처리할 수 없다.
"     중간에 실패하면 앞 명세는 이미 반영된 상태이고, 뒤 명세는 처리되지 않는다.
"     ET_MESSAGE 에는 회차별 메시지가 모두 누적된다.
