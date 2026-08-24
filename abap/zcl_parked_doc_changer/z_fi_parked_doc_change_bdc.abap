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
*&   Import 탭
*&     I_BUKRS TYPE BUKRS
*&     I_BELNR TYPE BELNR_D
*&     I_GJAHR TYPE GJAHR
*&     I_BKTXT TYPE BKTXT              (optional)
*&     I_XBLNR TYPE XBLNR1             (optional)
*&     IT_ITEM TYPE ZTFI_PARKED_ITM    (optional)
*&   Export 탭
*&     EV_MESSAGETYPE TYPE SYMSGTY
*&     EV_MESSAGETEXT TYPE STRING
*&     ET_MESSAGE     TYPE TAB_BDCMSGCOLL    (선택)
*&
*&   (TABLES 탭은 쓰지 않음 - ABAP Cloud 에서 호출 불가)
*&   CALL TRANSACTION 때문에 Standard ABAP 언어버전 패키지 + Local API 릴리스.
*&   RAP에서는 자체 COMMIT 이 있으므로 SAVE 단계에서 호출.
*&
*& [화면 흐름] SHDB 녹화 기준
*&   SAPMF05V 0100  초기화면      - 회사코드/전표번호/회계연도, '=ENTR'
*&   SAPLF040 0700  전표 개요화면 - BKPF-BKTXT / BKPF-XBLNR,
*&                                  명세 선택 커서 RF05V-ANZDT(nn) + '=PI'
*&   SAPLF040 0300  명세 상세화면 - G/L 명세.   BSEG-* 필드
*&   SAPLF040 0302  명세 상세화면 - 채권/채무 명세
*&   SAPLF040 0330  추가데이터 팝업 - G/L 명세.   HZUON / XREF1~3.
*&                  '=RW' 로 닫으면 개요화면으로 빠지고, 거기서 '=BP' 저장
*&   SAPLF040 0332  추가데이터 팝업 - 채권/채무 명세. '=BP' 로 바로 저장
*&                  (팝업 진입은 상세화면에서 '=ZK')
*&   SAPLKACB 0002  계정지정 팝업 - G/L 명세를 상세화면에서 저장할 때. 'ENTE'
*&
*&   명세 상세화면 번호는 명세 유형마다 다르다. 호출자가 안 넘기면
*&   파킹 전표 라인(VBSEG)의 계정유형(KOART)을 읽어 자동으로 정한다.
*&     KOART = D(고객) / K(공급업체) -> '0302'
*&     그 외(S 등)                   -> '0300'
*&   자동 판단이 맞지 않는 유형(자산 등)은 ZSFI_PARKED_ITM-DYNNR 로
*&   명세별로 직접 넘기면 그 값이 우선한다.
*&   추가데이터 팝업 화면/OK코드는 이 상세화면 번호로부터 결정된다.
*&
*& [처리 단위] 녹화된 흐름이 "명세 1건 수정 후 바로 저장" 이라
*&   상세화면에서 개요화면으로 되돌아가는 스텝이 없다. 그래서 명세가
*&   여러 건이면 명세 1건당 CALL TRANSACTION 을 1회씩 수행한다.
*&   헤더 필드는 첫 회차에 같이 전송하고, 명세가 없으면 헤더만 1회 처리한다.
*&   회차별로 COMMIT 되므로 중간에 실패하면 앞 회차는 이미 반영된 상태다.
*&
*& [변경 규칙] 값이 채워진 필드만 화면에 전송한다.
*&             (공란으로 값을 지우는 기능은 없음)
*&---------------------------------------------------------------------*
FUNCTION z_fi_parked_doc_change_bdc.

*----------------------------------------------------------------------*
* 화면 / OK코드 - SHDB 녹화 결과에 맞춰 여기만 조정한다.
*----------------------------------------------------------------------*
  CONSTANTS:
    " 초기화면
    lc_prog_init  TYPE bdcdata-program VALUE 'SAPMF05V',
    lc_dynp_init  TYPE bdcdata-dynpro  VALUE '0100',
    " 전표 개요화면
    lc_prog_ovw   TYPE bdcdata-program VALUE 'SAPLF040',
    lc_dynp_ovw   TYPE bdcdata-dynpro  VALUE '0700',
    " 명세 상세화면 - 화면번호는 명세 유형마다 다르다.
    " 기본은 VBSEG-KOART 로 자동 판단하고, DYNNR 을 넘기면 그 값이 우선한다.
    lc_prog_item  TYPE bdcdata-program VALUE 'SAPLF040',
    lc_dynp_item  TYPE bdcdata-dynpro  VALUE '0300',  " G/L 명세 (기본)
    lc_dynp_item2 TYPE bdcdata-dynpro  VALUE '0302',  " 채권/채무 명세
    " 추가 데이터 팝업 (HZUON, XREF1~3) - 이것도 명세 유형마다 화면이 다르다.
    " 팝업 OK코드가 저장(=BP)이 아니면, 팝업을 닫은 뒤 개요화면에서 저장한다.
    lc_prog_more  TYPE bdcdata-program VALUE 'SAPLF040',
    lc_dynp_more  TYPE bdcdata-dynpro  VALUE '0330',  " G/L 명세의 팝업
    lc_ok_more2   TYPE bdcdata-fval    VALUE '=RW',   " G/L 팝업 확인 -> 개요화면
    lc_dynp_more2 TYPE bdcdata-dynpro  VALUE '0332',  " 채권/채무 명세의 팝업
    lc_ok_more3   TYPE bdcdata-fval    VALUE '=BP',   " 채권/채무 팝업에서 바로 저장
    " 저장 시 뜨는 CO 계정지정 팝업
    lc_prog_kacb  TYPE bdcdata-program VALUE 'SAPLKACB',
    lc_dynp_kacb  TYPE bdcdata-dynpro  VALUE '0002',
    " 개요화면 테이블컨트롤에서 명세를 고를 때 커서를 놓는 컬럼
    lc_fld_pos    TYPE bdcdata-fnam    VALUE 'RF05V-ANZDT',
    " OK 코드
    lc_ok_enter   TYPE bdcdata-fval    VALUE '=ENTR',  " 초기화면 진행
    lc_ok_item    TYPE bdcdata-fval    VALUE '=PI',    " 명세 상세 진입
    lc_ok_save    TYPE bdcdata-fval    VALUE '=BP',    " 임시전표 저장
    lc_ok_more    TYPE bdcdata-fval    VALUE '=ZK',    " 추가 데이터 팝업 진입
    lc_ok_kacb    TYPE bdcdata-fval    VALUE 'ENTE',   " 계정지정 팝업 확인
    " CO 계정지정 팝업(SAPLKACB 0002)이 뜨는 명세 상세화면.
    " 녹화상 G/L 명세(0300)를 상세화면에서 저장할 때만 떴다.
    " 팝업이 안 뜨는데 블록이 남아 있으면 오류가 나므로 이 경우에만 붙인다.
    lc_kacb_dynp  TYPE bdcdata-dynpro  VALUE '0300',
    " 화면 표시 모드. 운영은 'N'(무화면).
    " SHDB 맞춰가는 동안만 'A'(전체화면) / 'E'(오류시만)로 바꿔서 확인한다.
    " RAP/백그라운드에서는 화면을 띄울 수 없으므로 반드시 'N' 이어야 한다.
    lc_dismode    TYPE ctu_params-dismode VALUE 'N'.

  DATA: lt_bdc       TYPE STANDARD TABLE OF bdcdata WITH DEFAULT KEY,
        lt_f1        TYPE STANDARD TABLE OF bdcdata WITH DEFAULT KEY,
        lt_f2        TYPE STANDARD TABLE OF bdcdata WITH DEFAULT KEY,
        lt_msg       TYPE STANDARD TABLE OF bdcmsgcoll WITH DEFAULT KEY,
        ls_item      TYPE zsfi_parked_itm,
        lv_dynp      TYPE bdcdata-dynpro,
        lv_dynp_more TYPE bdcdata-dynpro,
        lv_ok_more   TYPE bdcdata-fval,
        lv_koart     TYPE vbseg-koart,
        lv_ok        TYPE abap_bool,
        lv_date      TYPE char10,
        lv_1t        TYPE char10,
        lv_1p        TYPE char10,
        lv_2t        TYPE char10,
        lv_2p        TYPE char10,
        lv_3t        TYPE char10.

  CLEAR: ev_messagetype, ev_messagetext, et_message.

  " 변경할 게 없으면 트랜잭션을 타지 않는다.
  IF i_bktxt IS INITIAL AND i_xblnr IS INITIAL AND it_item IS INITIAL.
    ev_messagetype = 'S'.
    ev_messagetext = `Document has been updated`.
    RETURN.
  ENDIF.

  " 명세가 없으면 헤더만 1회, 있으면 명세 1건당 1회 실행한다.
  DATA(lv_times) = COND i( WHEN it_item IS INITIAL THEN 1 ELSE lines( it_item ) ).

  DO lv_times TIMES.

    DATA(lv_i) = sy-index.
    CLEAR: lt_bdc, lt_f1, lt_f2, lt_msg, ls_item,
           lv_dynp, lv_dynp_more, lv_ok_more,
           lv_date, lv_1t, lv_1p, lv_2t, lv_2p, lv_3t.

    READ TABLE it_item INTO ls_item INDEX lv_i.
    DATA(lv_has_item) = xsdbool( sy-subrc = 0 ).

*----------------------------------------------------------------------*
* 1) 초기화면 - 회사코드 / 전표번호 / 회계연도
*----------------------------------------------------------------------*
    lt_bdc = VALUE #(
      ( program = lc_prog_init dynpro = lc_dynp_init dynbegin = 'X' )
      ( fnam = 'BDC_CURSOR'   fval = 'RF05V-BUKRS' )
      ( fnam = 'BDC_OKCODE'   fval = lc_ok_enter )
      ( fnam = 'RF05V-BUKRS'  fval = i_bukrs )
      ( fnam = 'RF05V-BELNR'  fval = i_belnr )
      ( fnam = 'RF05V-GJAHR'  fval = i_gjahr ) ).

*----------------------------------------------------------------------*
* 2) 개요화면 - 헤더 필드(첫 회차만) + 명세 진입 / 저장
*----------------------------------------------------------------------*
    APPEND VALUE #( program = lc_prog_ovw dynpro = lc_dynp_ovw dynbegin = 'X' ) TO lt_bdc.
    APPEND VALUE #( fnam = 'BDC_OKCODE'
                    fval = COND #( WHEN lv_has_item = abap_true THEN lc_ok_item ELSE lc_ok_save ) ) TO lt_bdc.

    IF lv_has_item = abap_true.
      " 명세의 화면 행번호로 BUZEI 를 그대로 사용한다.
      APPEND VALUE #( fnam = 'BDC_CURSOR'
                      fval = |{ lc_fld_pos }({ ls_item-buzei WIDTH = 2 PAD = '0' ALIGN = RIGHT })| ) TO lt_bdc.
    ENDIF.

    IF lv_i = 1.
      IF i_bktxt IS NOT INITIAL.
        APPEND VALUE #( fnam = 'BKPF-BKTXT' fval = i_bktxt ) TO lt_bdc.
      ENDIF.
      IF i_xblnr IS NOT INITIAL.
        APPEND VALUE #( fnam = 'BKPF-XBLNR' fval = i_xblnr ) TO lt_bdc.
      ENDIF.
    ENDIF.

*----------------------------------------------------------------------*
* 3) 명세 상세화면 - 변경 필드 전송 후 저장
*----------------------------------------------------------------------*
    IF lv_has_item = abap_true.

      " 명세 유형별 상세화면 / 추가데이터 팝업 화면.
      " DYNNR 을 넘기면 그 값을 쓰고, 안 넘기면 파킹 전표 라인(VBSEG)의
      " 계정유형(KOART)으로 판단한다. S=G/L, D=고객, K=공급업체.
      IF ls_item-dynnr IS NOT INITIAL.
        lv_dynp = ls_item-dynnr.
      ELSE.
        CLEAR lv_koart.
        SELECT SINGLE koart FROM vbseg
          INTO lv_koart
          WHERE ausbk = i_bukrs
            AND belnr = i_belnr
            AND gjahr = i_gjahr
            AND buzei = ls_item-buzei.
        lv_dynp = COND #( WHEN lv_koart = 'D' OR lv_koart = 'K'
                          THEN lc_dynp_item2 ELSE lc_dynp_item ).
      ENDIF.

      IF lv_dynp = lc_dynp_item2.
        lv_dynp_more = lc_dynp_more2.    " 채권/채무
        lv_ok_more   = lc_ok_more3.
      ELSE.
        lv_dynp_more = lc_dynp_more.     " G/L
        lv_ok_more   = lc_ok_more2.
      ENDIF.

      " 날짜/수치는 사용자 형식으로 변환해서 전송한다.
      IF ls_item-zfbdt IS NOT INITIAL. WRITE ls_item-zfbdt TO lv_date.              ENDIF.
      IF ls_item-zbd1t IS NOT INITIAL. WRITE ls_item-zbd1t TO lv_1t LEFT-JUSTIFIED. ENDIF.
      IF ls_item-zbd1p IS NOT INITIAL. WRITE ls_item-zbd1p TO lv_1p LEFT-JUSTIFIED. ENDIF.
      IF ls_item-zbd2t IS NOT INITIAL. WRITE ls_item-zbd2t TO lv_2t LEFT-JUSTIFIED. ENDIF.
      IF ls_item-zbd2p IS NOT INITIAL. WRITE ls_item-zbd2p TO lv_2p LEFT-JUSTIFIED. ENDIF.
      IF ls_item-zbd3t IS NOT INITIAL. WRITE ls_item-zbd3t TO lv_3t LEFT-JUSTIFIED. ENDIF.

      " 명세 상세화면 필드
      " (지급조건 관련 필드는 채권/채무 명세 화면에만 있다. G/L 명세에
      "  ZTERM/ZFBDT 등을 넘기면 "필드가 화면에 없음" 오류가 난다)
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

      " 3-1) 상세화면 - 추가 데이터가 있으면 팝업으로, 없으면 바로 저장
      APPEND VALUE #( program = lc_prog_item dynpro = lv_dynp dynbegin = 'X' ) TO lt_bdc.
      APPEND VALUE #( fnam = 'BDC_OKCODE'
                      fval = COND #( WHEN lt_f2 IS INITIAL THEN lc_ok_save ELSE lc_ok_more ) ) TO lt_bdc.
      APPEND LINES OF lt_f1 TO lt_bdc.

      " 3-2) 추가 데이터 팝업
      IF lt_f2 IS NOT INITIAL.
        APPEND VALUE #( program = lc_prog_more dynpro = lv_dynp_more dynbegin = 'X' ) TO lt_bdc.
        APPEND VALUE #( fnam = 'BDC_OKCODE' fval = lv_ok_more ) TO lt_bdc.
        APPEND LINES OF lt_f2 TO lt_bdc.

        " 팝업에서 바로 저장되지 않는 경우(G/L 의 '=RW'), 팝업을 닫으면
        " 상세화면이 아니라 전표 개요화면으로 빠지고 거기서 저장한다.
        IF lv_ok_more <> lc_ok_save.
          APPEND VALUE #( program = lc_prog_ovw dynpro = lc_dynp_ovw dynbegin = 'X' ) TO lt_bdc.
          APPEND VALUE #( fnam = 'BDC_OKCODE' fval = lc_ok_save ) TO lt_bdc.
        ENDIF.
      ENDIF.

      " 3-3) 계정지정 팝업 - 값은 그대로 두고 Enter 로 통과.
      " 녹화상 G/L 명세를 "상세화면에서 저장"할 때만 떴다.
      " 추가데이터 팝업을 거쳐 개요화면에서 저장하는 경로에서는 안 떴다.
      IF lv_dynp = lc_kacb_dynp AND lt_f2 IS INITIAL.
        APPEND VALUE #( program = lc_prog_kacb dynpro = lc_dynp_kacb dynbegin = 'X' ) TO lt_bdc.
        APPEND VALUE #( fnam = 'BDC_OKCODE' fval = lc_ok_kacb ) TO lt_bdc.
      ENDIF.

    ENDIF.

*----------------------------------------------------------------------*
* 4) 실행
*----------------------------------------------------------------------*
    DATA(ls_options) = VALUE ctu_params(
      dismode = lc_dismode
      updmode = 'S'      " 동기 업데이트 - 호출자 응답 시점에 결과 확정
      defsize = 'X' ).   " 화면 크기 고정

    CALL TRANSACTION 'FBV2' USING lt_bdc
      OPTIONS FROM ls_options
      MESSAGES INTO lt_msg.

    lv_ok = xsdbool( sy-subrc = 0
                 AND NOT line_exists( lt_msg[ msgtyp = 'E' ] )
                 AND NOT line_exists( lt_msg[ msgtyp = 'A' ] ) ).

    APPEND LINES OF lt_msg TO et_message.

    " 한 건이라도 실패하면 뒤 명세는 진행하지 않는다.
    IF lv_ok = abap_false.
      EXIT.
    ENDIF.

  ENDDO.

*----------------------------------------------------------------------*
* 5) 결과 처리
*----------------------------------------------------------------------*
  IF lv_ok = abap_true.
    ev_messagetype = 'S'.
    ev_messagetext = `Document has been updated`.
  ELSE.
    ev_messagetype = 'E'.
    ev_messagetext = `Failed to update the document`.
  ENDIF.

ENDFUNCTION.
