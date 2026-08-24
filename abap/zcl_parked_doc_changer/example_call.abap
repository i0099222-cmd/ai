*&---------------------------------------------------------------------*
*& 호출 예시 - Z_FI_PARKED_DOC_CHANGE_BDC / ZCL_PARKED_DOC_CHANGER
*&---------------------------------------------------------------------*
*& 값이 채워진 필드만 변경된다. 안 넘기면 그 필드는 손대지 않는다.
*&---------------------------------------------------------------------*

DATA(lt_item) = VALUE ztfi_parked_itm(
  ( buzei = 1
    dynnr = '0302'                " 채권/채무 명세 상세화면 (G/L 이면 생략 = 0300)
    sgtxt = 'ITEM TEXT'
    zuonr = 'ASSIGN-01'
    zterm = 'ZB01'
    zfbdt = '20260901'
    zbd1t = 10
    zbd1p = '3.000'
    xref1 = 'REF1'
    hzuon = 'HZUON-01' )
  ( buzei = 2
    sgtxt = 'ITEM TEXT 2'
    zlsch = 'T' ) ).

" 클래스로 호출
zcl_parked_doc_changer=>change(
  EXPORTING
    i_bukrs        = '1000'
    i_belnr        = '1900000123'
    i_gjahr        = '2026'
    i_bktxt        = 'HEADER TEXT'
    i_xblnr        = 'REF-0001'
    it_item        = lt_item
  IMPORTING
    ev_messagetype = DATA(lv_msgty)    " 'S' / 'E'
    ev_messagetext = DATA(lv_msgtx)    " Document has been updated / Failed to update the document
    et_message     = DATA(lt_message) ).

" FM 직접 호출도 동일
CALL FUNCTION 'Z_FI_PARKED_DOC_CHANGE_BDC'
  EXPORTING
    i_bukrs        = '1000'
    i_belnr        = '1900000123'
    i_gjahr        = '2026'
    i_bktxt        = 'HEADER TEXT'
    it_item        = lt_item
  IMPORTING
    ev_messagetype = lv_msgty
    ev_messagetext = lv_msgtx
    et_message     = lt_message.

" 주의
"  1) G/L 명세에는 ZTERM/ZFBDT 등 지급 관련 필드가 화면에 없으므로
"     해당 명세에는 그 필드들을 넘기지 않는다
"     (화면에 없는 필드를 전송하면 BDC 오류).
"  2) BUZEI 를 개요화면 테이블컨트롤 행 번호로 그대로 쓴다.
"     명세가 많아 스크롤이 필요한 전표는 페이징(P+) 블록 추가 필요.
"  3) 값을 공란으로 지우는 기능은 없다(빈 값 = 변경 안 함).
"  4) 명세 1건당 CALL TRANSACTION 을 1회씩 수행한다(회차별 COMMIT).
"     중간에 실패하면 앞 회차는 이미 반영된 상태다.
"  5) DYNNR 은 명세 유형별 상세화면 번호다. G/L=0300(기본), 채권/채무=0302.
"     틀리게 넘기면 "화면이 다름" 오류가 난다.
