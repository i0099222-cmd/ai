*&---------------------------------------------------------------------*
*& Function Module Z_FI_PARKED_DOC_CHANGE_BDC
*&---------------------------------------------------------------------*
*& 임시전표(파킹 문서) 수정 - CALL TRANSACTION 'FBV2' BDC 래퍼.
*&
*& [사전 작업] SE11 오브젝트 2개 (DDIC_OBJECTS.md 참고)
*&   ZSFI_PARKED_ITM : 명세 구조
*&   ZTFI_PARKED_ITM : ZSFI_PARKED_ITM 의 테이블 타입
*&
*& [SE37 생성]
*&   Function Group : (기존 Z_FI_POST_PARKED_DOC 재사용 또는 신규)
*&   Function Module: Z_FI_PARKED_DOC_CHANGE_BDC
*&
*&   Import 탭
*&     I_BUKRS TYPE BUKRS
*&     I_BELNR TYPE BELNR_D
*&     I_GJAHR TYPE GJAHR
*&     I_BKTXT TYPE BKTXT                    (optional)
*&     I_XBLNR TYPE XBLNR1                   (optional)
*&     I_MODE  TYPE CTU_PARAMS-DISMODE  Default 'N'   (optional)
*&     IT_ITEM TYPE ZTFI_PARKED_ITM          (optional)
*&   Export 탭
*&     EV_MESSAGETYPE TYPE SYMSGTY
*&     EV_MESSAGETEXT TYPE STRING
*&     ET_MESSAGE     TYPE TAB_BDCMSGCOLL    (선택)
*&
*&   (TABLES 탭은 쓰지 않음 - ABAP Cloud 에서 호출 불가)
*&
*&   CALL TRANSACTION 은 ABAP Cloud 언어버전에서 금지이므로 이 FM은
*&   Standard ABAP 언어버전 패키지에 두고, SE37 > API State 에서
*&   Local API 로 Release 해야 RAP 쪽에서 호출 가능하다.
*&   RAP에서는 CALL TRANSACTION 이 자체 COMMIT 을 하므로 SAVE 단계에서 호출.
*&
*& [변경 규칙] 값이 채워진 필드만 화면에 전송한다.
*&             (공란으로 값을 지우는 기능은 없음)
*&
*& [중요] 화면/OK코드 상수는 클래식 FBV2 기준 기본값이다.
*&        SHDB로 FBV2를 1회 녹화한 뒤(SHDB_RECORDING.md) 상수 블록만
*&        녹화 결과로 교체하면 나머지는 그대로 동작한다.
*&---------------------------------------------------------------------*
FUNCTION z_fi_parked_doc_change_bdc.

*----------------------------------------------------------------------*
* 화면 / OK코드 - SHDB 녹화 결과에 맞춰 여기만 조정한다.
*----------------------------------------------------------------------*
  CONSTANTS:
    lc_prog_init  TYPE bdcdata-program VALUE 'SAPMF05V',  " 초기화면
    lc_dynp_init  TYPE bdcdata-dynpro  VALUE '0100',
    lc_prog_ovw   TYPE bdcdata-program VALUE 'SAPLF040',  " 전표 개요화면
    lc_dynp_ovw   TYPE bdcdata-dynpro  VALUE '0700',
    lc_prog_item  TYPE bdcdata-program VALUE 'SAPMF05A',  " 명세 상세화면
    lc_dynp_item  TYPE bdcdata-dynpro  VALUE '0302',
    lc_dynp_more  TYPE bdcdata-dynpro  VALUE '0331',      " 추가 데이터 팝업
    " 개요화면에서 기존 명세를 고를 때 커서를 놓을 테이블컨트롤 컬럼.
    " [반드시 녹화값으로 교체] RF05V-NEWBS / NEWKO / NEWBK 는 화면 하단의
    " "다음 명세 입력" 필드라 기존 명세 선택용 컬럼과 다르다.
    " SHDB에서 명세를 더블클릭한 스텝의 BDC_CURSOR 값을 그대로 넣을 것.
    lc_fld_pos    TYPE bdcdata-fnam    VALUE 'RF05V-NEWBS',
    lc_ok_enter   TYPE bdcdata-fval    VALUE '/00',
    lc_ok_item    TYPE bdcdata-fval    VALUE '=PA',       " 명세 상세 진입
    lc_ok_more    TYPE bdcdata-fval    VALUE '=ZK',       " 추가 데이터 팝업
    lc_ok_back    TYPE bdcdata-fval    VALUE '=BACK',     " 개요화면 복귀
    lc_ok_save    TYPE bdcdata-fval    VALUE '=BU'.       " 저장

  DATA: lt_bdc  TYPE STANDARD TABLE OF bdcdata WITH DEFAULT KEY,
        lt_f1   TYPE STANDARD TABLE OF bdcdata WITH DEFAULT KEY,
        lt_f2   TYPE STANDARD TABLE OF bdcdata WITH DEFAULT KEY,
        lt_msg  TYPE STANDARD TABLE OF bdcmsgcoll WITH DEFAULT KEY,
        lv_date TYPE char10,
        lv_1t   TYPE char10,
        lv_1p   TYPE char10,
        lv_2t   TYPE char10,
        lv_2p   TYPE char10,
        lv_3t   TYPE char10.

  CLEAR: ev_messagetype, ev_messagetext, et_message.

  " 변경할 게 없으면 트랜잭션을 타지 않는다.
  IF i_bktxt IS INITIAL AND i_xblnr IS INITIAL AND it_item IS INITIAL.
    ev_messagetype = 'S'.
    ev_messagetext = `Document has been updated`.
    RETURN.
  ENDIF.

*----------------------------------------------------------------------*
* 1) 초기화면 - 회사코드 / 전표번호 / 회계연도
*----------------------------------------------------------------------*
  lt_bdc = VALUE #(
    ( program = lc_prog_init dynpro = lc_dynp_init dynbegin = 'X' )
    ( fnam = 'BDC_CURSOR'   fval = 'RF05V-BELNR' )
    ( fnam = 'BDC_OKCODE'   fval = lc_ok_enter )
    ( fnam = 'RF05V-BUKRS'  fval = i_bukrs )
    ( fnam = 'RF05V-BELNR'  fval = i_belnr )
    ( fnam = 'RF05V-GJAHR'  fval = i_gjahr ) ).

*----------------------------------------------------------------------*
* 2) 개요화면 - 헤더 필드(BKTXT, XBLNR) + 첫 명세 진입 / 저장
*----------------------------------------------------------------------*
  APPEND VALUE #( program = lc_prog_ovw dynpro = lc_dynp_ovw dynbegin = 'X' ) TO lt_bdc.
  APPEND VALUE #( fnam = 'BDC_OKCODE'
                  fval = COND #( WHEN it_item IS INITIAL THEN lc_ok_save ELSE lc_ok_item ) ) TO lt_bdc.
  IF it_item IS NOT INITIAL.
    APPEND VALUE #( fnam = 'BDC_CURSOR'
                    fval = |{ lc_fld_pos }({ it_item[ 1 ]-buzei WIDTH = 2 PAD = '0' ALIGN = RIGHT })| ) TO lt_bdc.
  ENDIF.
  IF i_bktxt IS NOT INITIAL.
    APPEND VALUE #( fnam = 'BKPF-BKTXT' fval = i_bktxt ) TO lt_bdc.
  ENDIF.
  IF i_xblnr IS NOT INITIAL.
    APPEND VALUE #( fnam = 'BKPF-XBLNR' fval = i_xblnr ) TO lt_bdc.
  ENDIF.

*----------------------------------------------------------------------*
* 3) 명세별 - 상세화면 / 추가 데이터 팝업 / 개요화면 복귀
*----------------------------------------------------------------------*
  LOOP AT it_item INTO DATA(ls_item).

    DATA(lv_idx) = sy-tabix.

    " 날짜/수치는 사용자 형식으로 변환해서 전송한다.
    CLEAR: lv_date, lv_1t, lv_1p, lv_2t, lv_2p, lv_3t.
    IF ls_item-zfbdt IS NOT INITIAL. WRITE ls_item-zfbdt TO lv_date.                ENDIF.
    IF ls_item-zbd1t IS NOT INITIAL. WRITE ls_item-zbd1t TO lv_1t LEFT-JUSTIFIED.   ENDIF.
    IF ls_item-zbd1p IS NOT INITIAL. WRITE ls_item-zbd1p TO lv_1p LEFT-JUSTIFIED.   ENDIF.
    IF ls_item-zbd2t IS NOT INITIAL. WRITE ls_item-zbd2t TO lv_2t LEFT-JUSTIFIED.   ENDIF.
    IF ls_item-zbd2p IS NOT INITIAL. WRITE ls_item-zbd2p TO lv_2p LEFT-JUSTIFIED.   ENDIF.
    IF ls_item-zbd3t IS NOT INITIAL. WRITE ls_item-zbd3t TO lv_3t LEFT-JUSTIFIED.   ENDIF.

    " 명세 상세화면 필드
    lt_f1 = VALUE #(
      ( fnam = 'BSEG-SGTXT' fval = ls_item-sgtxt )
      ( fnam = 'BSEG-ZUONR' fval = ls_item-zuonr )
      ( fnam = 'BSEG-BVTYP' fval = ls_item-bvtyp )
      ( fnam = 'BSEG-HBKID' fval = ls_item-hbkid )
      ( fnam = 'BSEG-ZTERM' fval = ls_item-zterm )
      ( fnam = 'BSEG-ZFBDT' fval = lv_date )
      ( fnam = 'BSEG-ZBD1T' fval = lv_1t )
      ( fnam = 'BSEG-ZBD1P' fval = lv_1p )
      ( fnam = 'BSEG-ZBD2T' fval = lv_2t )
      ( fnam = 'BSEG-ZBD2P' fval = lv_2p )
      ( fnam = 'BSEG-ZBD3T' fval = lv_3t )
      ( fnam = 'BSEG-ZLSCH' fval = ls_item-zlsch )
      ( fnam = 'BSEG-ZLSPR' fval = ls_item-zlspr )
      ( fnam = 'BSEG-ZBFIX' fval = ls_item-zbfix )
      ( fnam = 'BSEG-RSTGR' fval = ls_item-rstgr ) ).

    " 추가 데이터 팝업 필드
    lt_f2 = VALUE #(
      ( fnam = 'BSEG-HZUON' fval = ls_item-hzuon )
      ( fnam = 'BSEG-XREF1' fval = ls_item-xref1 )
      ( fnam = 'BSEG-XREF2' fval = ls_item-xref2 )
      ( fnam = 'BSEG-XREF3' fval = ls_item-xref3 ) ).

    " 값이 안 넘어온 필드는 전송하지 않는다.
    DELETE lt_f1 WHERE fval IS INITIAL.
    DELETE lt_f2 WHERE fval IS INITIAL.

    " 3-1) 명세 상세화면
    APPEND VALUE #( program = lc_prog_item dynpro = lc_dynp_item dynbegin = 'X' ) TO lt_bdc.
    APPEND VALUE #( fnam = 'BDC_OKCODE'
                    fval = COND #( WHEN lt_f2 IS INITIAL THEN lc_ok_back ELSE lc_ok_more ) ) TO lt_bdc.
    APPEND LINES OF lt_f1 TO lt_bdc.

    " 3-2) 추가 데이터 팝업 -> 확인 후 상세화면에서 뒤로
    IF lt_f2 IS NOT INITIAL.
      APPEND VALUE #( program = lc_prog_item dynpro = lc_dynp_more dynbegin = 'X' ) TO lt_bdc.
      APPEND VALUE #( fnam = 'BDC_OKCODE' fval = lc_ok_enter ) TO lt_bdc.
      APPEND LINES OF lt_f2 TO lt_bdc.

      APPEND VALUE #( program = lc_prog_item dynpro = lc_dynp_item dynbegin = 'X' ) TO lt_bdc.
      APPEND VALUE #( fnam = 'BDC_OKCODE' fval = lc_ok_back ) TO lt_bdc.
    ENDIF.

    " 3-3) 개요화면 - 다음 명세로 이동하거나 마지막이면 저장
    APPEND VALUE #( program = lc_prog_ovw dynpro = lc_dynp_ovw dynbegin = 'X' ) TO lt_bdc.
    IF lv_idx < lines( it_item ).
      APPEND VALUE #( fnam = 'BDC_OKCODE' fval = lc_ok_item ) TO lt_bdc.
      APPEND VALUE #( fnam = 'BDC_CURSOR'
                      fval = |{ lc_fld_pos }({ it_item[ lv_idx + 1 ]-buzei WIDTH = 2 PAD = '0' ALIGN = RIGHT })| ) TO lt_bdc.
    ELSE.
      APPEND VALUE #( fnam = 'BDC_OKCODE' fval = lc_ok_save ) TO lt_bdc.
    ENDIF.

  ENDLOOP.

*----------------------------------------------------------------------*
* 4) 실행
*----------------------------------------------------------------------*
  DATA(ls_options) = VALUE ctu_params(
    dismode = COND #( WHEN i_mode IS NOT INITIAL THEN i_mode ELSE 'N' )
    updmode = 'S'      " 동기 업데이트 - 호출자 응답 시점에 결과 확정
    defsize = 'X' ).   " 화면 크기 고정

  CALL TRANSACTION 'FBV2' USING lt_bdc
    OPTIONS FROM ls_options
    MESSAGES INTO lt_msg.

*----------------------------------------------------------------------*
* 5) 결과 처리
*----------------------------------------------------------------------*
  et_message = lt_msg.

  IF sy-subrc = 0
  AND NOT line_exists( lt_msg[ msgtyp = 'E' ] )
  AND NOT line_exists( lt_msg[ msgtyp = 'A' ] ).
    ev_messagetype = 'S'.
    ev_messagetext = `Document has been updated`.
  ELSE.
    ev_messagetype = 'E'.
    ev_messagetext = `Failed to update the document`.
  ENDIF.

ENDFUNCTION.
