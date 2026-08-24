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
*& [화면 흐름] SHDB 녹화 기준. 명세 전체를 한 번의 CALL TRANSACTION 으로 처리한다.
*&
*&   SAPMF05V 0100  초기화면   회사코드/전표번호/회계연도 -> '=ENTR'
*&   SAPLF040 0700  개요화면   헤더 BKPF-BKTXT / BKPF-XBLNR (첫 진입 시)
*&                             명세 선택: 커서 RF05V-ANZDT(nn) + '=PI'
*&   SAPLF040 0300  상세화면   G/L 명세.    빠져나올 때 '=BP'
*&                             -> SAPLKACB 0002 계정지정 팝업('ENTE') -> 개요화면
*&   SAPLF040 0302  상세화면   채권/채무 명세. 빠져나올 때 '=RW'(뒤로) -> 개요화면
*&   SAPLF040 0330  추가데이터 팝업 - G/L 명세용     (상세화면에서 '=ZK')
*&   SAPLF040 0332  추가데이터 팝업 - 채권/채무용    (상세화면에서 '=ZK')
*&                             팝업은 '=RW' 로 닫으면 개요화면으로 빠진다
*&   SAPLF040 0700  개요화면   명세를 다 처리한 뒤 '=BP' 로 저장
*&
*&   명세 상세화면 번호는 명세 유형마다 다르다. 호출자가 안 넘기면
*&   파킹 전표 라인(VBSEG)의 계정유형(KOART)을 읽어 자동으로 정한다.
*&     KOART = D(고객) / K(공급업체) -> '0302'
*&     그 외(S 등)                   -> '0300'
*&   자동 판단이 맞지 않는 유형(자산 등)은 ZSFI_PARKED_ITM-DYNNR 로
*&   명세별로 직접 넘기면 그 값이 우선한다.
*&   추가데이터 팝업 화면도 이 상세화면 번호로부터 결정된다.
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
    lc_dynp_gl    TYPE bdcdata-dynpro  VALUE '0300',  " G/L 명세
    lc_dynp_kd    TYPE bdcdata-dynpro  VALUE '0302',  " 채권/채무 명세
    " 추가 데이터 팝업 (HZUON, XREF1~3) - 이것도 명세 유형마다 화면이 다르다.
    lc_prog_more  TYPE bdcdata-program VALUE 'SAPLF040',
    lc_dynp_more_gl TYPE bdcdata-dynpro VALUE '0330',
    lc_dynp_more_kd TYPE bdcdata-dynpro VALUE '0332',
    " G/L 명세 상세화면을 '=BP' 로 빠져나올 때 뜨는 CO 계정지정 팝업
    lc_prog_kacb  TYPE bdcdata-program VALUE 'SAPLKACB',
    lc_dynp_kacb  TYPE bdcdata-dynpro  VALUE '0002',
    " 개요화면 테이블컨트롤에서 명세를 고를 때 커서를 놓는 컬럼
    lc_fld_pos    TYPE bdcdata-fnam    VALUE 'RF05V-ANZDT',
    " OK 코드
    lc_ok_enter   TYPE bdcdata-fval    VALUE '=ENTR',  " 초기화면 진행
    lc_ok_item    TYPE bdcdata-fval    VALUE '=PI',    " 개요화면 -> 명세 상세
    lc_ok_more    TYPE bdcdata-fval    VALUE '=ZK',    " 상세화면 -> 추가데이터 팝업
    lc_ok_back    TYPE bdcdata-fval    VALUE '=RW',    " 뒤로 -> 개요화면
    lc_ok_kacb    TYPE bdcdata-fval    VALUE 'ENTE',   " 계정지정 팝업 확인
    lc_ok_save    TYPE bdcdata-fval    VALUE '=BP',    " 임시전표 저장
    " 화면 표시 모드. 운영은 'N'(무화면).
    " SHDB 맞춰가는 동안만 'A'(전체화면) / 'E'(오류시만)로 바꿔서 확인한다.
    " RAP/백그라운드에서는 화면을 띄울 수 없으므로 반드시 'N' 이어야 한다.
    lc_dismode    TYPE ctu_params-dismode VALUE 'N'.

  DATA: lt_bdc       TYPE STANDARD TABLE OF bdcdata WITH DEFAULT KEY,
        lt_f1        TYPE STANDARD TABLE OF bdcdata WITH DEFAULT KEY,
        lt_f2        TYPE STANDARD TABLE OF bdcdata WITH DEFAULT KEY,
        lt_msg       TYPE STANDARD TABLE OF bdcmsgcoll WITH DEFAULT KEY,
        lv_koart     TYPE vbseg-koart,
        lv_dynp      TYPE bdcdata-dynpro,
        lv_dynp_more TYPE bdcdata-dynpro,
        lv_ok_exit   TYPE bdcdata-fval,
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
* 2) 명세별 - 개요화면에서 선택 -> 상세화면 수정 -> 개요화면 복귀
*----------------------------------------------------------------------*
  LOOP AT it_item INTO DATA(ls_item).

    DATA(lv_i) = sy-tabix.
    CLEAR: lt_f1, lt_f2, lv_koart, lv_dynp, lv_dynp_more, lv_ok_exit,
           lv_date, lv_1t, lv_1p, lv_2t, lv_2p, lv_3t.

    " 2-1) 개요화면 - 헤더 필드(첫 진입 시)와 명세 선택
    APPEND VALUE #( program = lc_prog_ovw dynpro = lc_dynp_ovw dynbegin = 'X' ) TO lt_bdc.
    APPEND VALUE #( fnam = 'BDC_OKCODE' fval = lc_ok_item ) TO lt_bdc.
    " 명세의 화면 행번호로 BUZEI 를 그대로 사용한다.
    APPEND VALUE #( fnam = 'BDC_CURSOR'
                    fval = |{ lc_fld_pos }({ ls_item-buzei WIDTH = 2 PAD = '0' ALIGN = RIGHT })| ) TO lt_bdc.

    IF lv_i = 1.
      IF i_bktxt IS NOT INITIAL.
        APPEND VALUE #( fnam = 'BKPF-BKTXT' fval = i_bktxt ) TO lt_bdc.
      ENDIF.
      IF i_xblnr IS NOT INITIAL.
        APPEND VALUE #( fnam = 'BKPF-XBLNR' fval = i_xblnr ) TO lt_bdc.
      ENDIF.
    ENDIF.

    " 2-2) 명세 유형별 화면 결정
    IF ls_item-dynnr IS NOT INITIAL.
      lv_dynp = ls_item-dynnr.
    ELSE.
      SELECT SINGLE koart FROM vbseg
        INTO lv_koart
        WHERE ausbk = i_bukrs
          AND belnr = i_belnr
          AND gjahr = i_gjahr
          AND buzei = ls_item-buzei.
      lv_dynp = COND #( WHEN lv_koart = 'D' OR lv_koart = 'K'
                        THEN lc_dynp_kd ELSE lc_dynp_gl ).
    ENDIF.

    lv_dynp_more = COND #( WHEN lv_dynp = lc_dynp_kd
                           THEN lc_dynp_more_kd ELSE lc_dynp_more_gl ).

    " 상세화면에서 개요화면으로 빠져나오는 OK코드.
    " 녹화상 G/L 명세는 '=BP', 채권/채무 명세는 '=RW' 로 빠져나왔고
    " 둘 다 개요화면으로 돌아왔다. G/L 의 '=BP' 뒤에는 계정지정 팝업이 뜬다.
    lv_ok_exit = COND #( WHEN lv_dynp = lc_dynp_gl THEN lc_ok_save ELSE lc_ok_back ).

    " 2-3) 화면에 보낼 필드 준비
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

    " 2-4) 상세화면 - 추가 데이터가 있으면 팝업으로, 없으면 개요화면으로 복귀
    APPEND VALUE #( program = lc_prog_item dynpro = lv_dynp dynbegin = 'X' ) TO lt_bdc.
    APPEND VALUE #( fnam = 'BDC_OKCODE'
                    fval = COND #( WHEN lt_f2 IS INITIAL THEN lv_ok_exit ELSE lc_ok_more ) ) TO lt_bdc.
    APPEND LINES OF lt_f1 TO lt_bdc.

    IF lt_f2 IS NOT INITIAL.
      " 2-5) 추가 데이터 팝업 - '=RW' 로 닫으면 개요화면으로 빠진다
      APPEND VALUE #( program = lc_prog_more dynpro = lv_dynp_more dynbegin = 'X' ) TO lt_bdc.
      APPEND VALUE #( fnam = 'BDC_OKCODE' fval = lc_ok_back ) TO lt_bdc.
      APPEND LINES OF lt_f2 TO lt_bdc.
    ELSEIF lv_ok_exit = lc_ok_save.
      " 2-6) G/L 명세를 '=BP' 로 빠져나오면 계정지정 팝업이 뜬다.
      "      값은 그대로 두고 Enter 로 통과한다.
      APPEND VALUE #( program = lc_prog_kacb dynpro = lc_dynp_kacb dynbegin = 'X' ) TO lt_bdc.
      APPEND VALUE #( fnam = 'BDC_OKCODE' fval = lc_ok_kacb ) TO lt_bdc.
    ENDIF.

  ENDLOOP.

*----------------------------------------------------------------------*
* 3) 개요화면 - 저장
*    (명세가 없으면 헤더 필드만 넣고 바로 저장한다)
*----------------------------------------------------------------------*
  APPEND VALUE #( program = lc_prog_ovw dynpro = lc_dynp_ovw dynbegin = 'X' ) TO lt_bdc.
  APPEND VALUE #( fnam = 'BDC_OKCODE' fval = lc_ok_save ) TO lt_bdc.

  IF it_item IS INITIAL.
    IF i_bktxt IS NOT INITIAL.
      APPEND VALUE #( fnam = 'BKPF-BKTXT' fval = i_bktxt ) TO lt_bdc.
    ENDIF.
    IF i_xblnr IS NOT INITIAL.
      APPEND VALUE #( fnam = 'BKPF-XBLNR' fval = i_xblnr ) TO lt_bdc.
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
