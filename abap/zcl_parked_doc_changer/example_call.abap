*&---------------------------------------------------------------------*
*& 호출 예시 - Z_FI_PARKED_DOC_CHANGE_BDC / ZCL_PARKED_DOC_CHANGER
*&---------------------------------------------------------------------*

" [예시 1] CHGFLD 없이 - 값이 채워진 필드만 변경
DATA(ls_header) = VALUE zsfi_parked_hdr(
  bukrs = '1000'
  belnr = '1900000123'
  gjahr = '2026'
  bktxt = 'HEADER TEXT'
  xblnr = 'REF-0001' ).

DATA(lt_item) = VALUE ztfi_parked_itm(
  ( buzei = 1
    sgtxt = 'ITEM TEXT'
    zuonr = 'ASSIGN-01'
    zterm = 'ZB01'
    zfbdt = '20260901'
    zbd1t = 10
    zbd1p = '3.000'
    xref1 = 'REF1'
    hzuon = 'HZUON-01' ) ).

zcl_parked_doc_changer=>change(
  EXPORTING
    is_header      = ls_header
    it_item        = lt_item
  IMPORTING
    ev_messagetype = DATA(lv_msgty)     " 'S' / 'E'
    ev_messagetext = DATA(lv_msgtx)     " Document has been updated / Failed to update the document
    et_message     = DATA(lt_message) ).


" [예시 2] CHGFLD 로 변경 대상을 명시 - 공란 지정으로 값 삭제까지 가능
DATA(ls_header2) = VALUE zsfi_parked_hdr(
  bukrs  = '1000'
  belnr  = '1900000123'
  gjahr  = '2026'
  bktxt  = ''                    " 헤더텍스트를 지운다
  chgfld = 'BKTXT' ).            " XBLNR 은 손대지 않음

DATA(lt_item2) = VALUE ztfi_parked_itm(
  ( buzei  = 2
    zlspr  = ''                  " 지급보류표시를 해제한다
    sgtxt  = 'NEW TEXT'
    chgfld = 'ZLSPR,SGTXT' ) ).

" FM 직접 호출도 동일하다
CALL FUNCTION 'Z_FI_PARKED_DOC_CHANGE_BDC'
  EXPORTING
    is_header      = ls_header2
    it_item        = lt_item2
    iv_mode        = 'N'          " 'A' 전체화면 / 'E' 오류시만 / 'N' 무화면
  IMPORTING
    ev_messagetype = lv_msgty
    ev_messagetext = lv_msgtx
    et_message     = lt_message.

" 주의
"  1) CHGFLD 를 채우면 그 구조에서는 "나열된 필드만" 전송된다.
"  2) G/L 명세에는 ZTERM/ZFBDT 등 지급 관련 필드가 화면에 없으므로,
"     해당 명세에는 그 필드들을 넘기지 않아야 한다
"     (화면에 없는 필드를 전송하면 BDC 오류가 난다).
"  3) POSID 를 지정하지 않으면 BUZEI 를 개요화면 테이블컨트롤 행 번호로 사용한다.
"     명세가 많아 스크롤이 필요한 전표는 POSID(화면 행 번호)를 직접 넘기거나
"     페이징(P+ / P-) 처리를 FM 에 추가해야 한다.
