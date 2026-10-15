"=====================================================================
" Z POSTING_INTERFACE_CLEARING : 환차 라인 코스트센터 (최종본)
"   = v12 에서 테스트용 기록(lt_fx_log)만 뺀 것. 동작은 v12 와 같음
"   기존 CALL TRANSACTION 문장 그대로, DO 루프로 감싸기
"
" 문제
"  - 외화 반제 시 FB05 가 만드는 환차 라인이 원가요소 계정이라 코스트센터 필수
"  - BDC 로 저장하면 "Correct the marked line items"(F5 413) 로 전기 안 됨
"
" 처리 (SHDB 녹화 흐름)
"  1) 원래 BDC 그대로 1회 → 전기되면 끝
"  2) F5 413 이 나면, 원래 저장 OK코드 뒤에 녹화 경로를 붙여서 라인을 차례로 시도
"       SAPMF05A 0700  BDC_CURSOR RF05A-AZSAL   =PI
"       SAPMF05A 0610  *BSEG-BUZEI = 라인번호   =ENTR
"       SAPMF05A 0300  BDC_CURSOR BSEG-WRBTR    =RW
"       SAPLKACB 0002  COBL-KOSTL               =ENTE
"       SAPMF05A 0700  BDC_CURSOR RF05A-NEWBS   =BU
"     - 팝업이 안 뜨는 라인      : 0700 에서 멈춤 (=BU 전) → 다음 라인
"     - 코스트센터 칸 없는 팝업  : 00 343/349 COBL-KOSTL  → 다음 라인
"     - 환차 라인                : 팝업에 코스트센터 입력 → 전기
"     - 라인 없음                : 0610 에서 멈춤 → 포기
"     ※ 틀린 라인 시도는 전기 전에 멈추므로 전표 안 생김
"     ※ 2회차부터 표준 화면 크기(DEFSIZE = 'X'), 끝나면 ls_ctu 원래대로
"  3) 끝내 실패하면 1회차(원래 BDC)의 tab_msg / sy-subrc / sy-msg* 로 되돌림
"     → 이후 기존 에러 처리 로직 그대로
"
" 처리 안 되는 경우 (원래 에러 그대로 리턴)
"  - 입력 라인(FTPOST)에 코스트센터가 없는 건
"  - 원화(DMBTR) 있는 건 (저장 시 KI 235)
"  - 환차 라인이 2개 이상인 건
"  - 환차 라인 번호가 (입력 라인 수 + 19) 보다 큰 건 (최대 20회 시도)
"
" ※ ft / tab_msg / ls_ctu / t_ftpost 는 함수그룹의 실제 이름
"=====================================================================


"---------------------------------------------------------------------
" TOP include
"---------------------------------------------------------------------
DATA: gv_fx_kostl   TYPE kostl,
      gv_fx_n_input TYPE i.             " 입력 라인 수 (FTPOST 아이템)


"---------------------------------------------------------------------
" FM 시작부 : 입력 라인의 코스트센터 + 입력 라인 수
"---------------------------------------------------------------------
  CLEAR: gv_fx_kostl, gv_fx_n_input.
  LOOP AT t_ftpost INTO DATA(ls_ftpost) WHERE stype = 'P'.
    IF gv_fx_kostl IS INITIAL
   AND ( ls_ftpost-fnam = 'COBL-KOSTL' OR ls_ftpost-fnam = 'BSEG-KOSTL' )
   AND ls_ftpost-fval IS NOT INITIAL
   AND ls_ftpost-fval <> '/'.
      gv_fx_kostl = ls_ftpost-fval.
    ENDIF.
    IF ls_ftpost-count > gv_fx_n_input.
      gv_fx_n_input = ls_ftpost-count.
    ENDIF.
  ENDLOOP.


"---------------------------------------------------------------------
" CALL TRANSACTION 하는 FORM : 기존 호출을 감싸기
"---------------------------------------------------------------------
  DATA: lt_ft_org    TYPE STANDARD TABLE OF bdcdata,
        lt_msg_org   TYPE STANDARD TABLE OF bdcmsgcoll,
        ls_sy_org    TYPE symsg,
        lv_subrc_org TYPE sysubrc,
        lv_subrc     TYPE sysubrc,
        lv_try       TYPE i,
        lv_line      TYPE i,
        lv_ok        TYPE abap_bool.

  lt_ft_org = ft[].                     " 원본 BDC 보관
  DATA(ls_ctu_org) = ls_ctu.            " 원래 CALL TRANSACTION 옵션 보관
  lv_line   = gv_fx_n_input.            " 환차 라인 후보 : 입력 라인 다음부터
  CLEAR lv_try.

  DO 20 TIMES.

    lv_try = lv_try + 1.
    CLEAR tab_msg[].

    " ↓↓↓ 기존 CALL TRANSACTION 문장 그대로 ↓↓↓
    CALL TRANSACTION 'FB05' USING ft
         OPTIONS FROM ls_ctu
         MESSAGES INTO tab_msg.
    " ↑↑↑ 기존 CALL TRANSACTION 문장 그대로 ↑↑↑
    lv_subrc = sy-subrc.

    " 첫 실행(원래 BDC) 결과 보관 → 끝내 실패하면 이걸 돌려줌
    IF lv_try = 1.
      lv_subrc_org = lv_subrc.
      lt_msg_org   = tab_msg[].
      ls_sy_org    = VALUE #( msgty = sy-msgty  msgid = sy-msgid  msgno = sy-msgno
                              msgv1 = sy-msgv1  msgv2 = sy-msgv2
                              msgv3 = sy-msgv3  msgv4 = sy-msgv4 ).
    ENDIF.

    " 전기됐거나 코스트센터 값이 없으면 종료
    IF lv_subrc = 0 OR gv_fx_kostl IS INITIAL.
      EXIT.
    ENDIF.

    IF lv_try = 1.
      " 원래 BDC : 저장 후 "Correct the marked line items"(F5 413) 가 난 경우만 처리
      IF NOT line_exists( tab_msg[ msgid = 'F5' msgnr = '413' ] )
     AND NOT line_exists( tab_msg[ msgid = '00' msgnr = '344'
                                   msgv1 = 'SAPMF05A' msgv2 = '0700' ] ).
        EXIT.
      ENDIF.
    ELSE.
      " 그 번호 라인이 없음 (0610 에서 멈춤) → 포기
      IF line_exists( tab_msg[ msgid = '00' msgnr = '344'
                               msgv1 = 'SAPMF05A' msgv2 = '0610' ] )
      OR line_exists( tab_msg[ msgtyp = 'E' dyname = 'SAPMF05A' dynumb = '0610' ] ).
        EXIT.
      ENDIF.
      " 팝업은 떴지만 코스트센터 칸이 없음 (00 343/349 COBL-KOSTL)
      "   = 다른 계정지정이 필요한 라인 (환차 라인 아님) → 다음 라인으로
      IF NOT line_exists( tab_msg[ msgid = '00' msgnr = '343' msgv1 = 'COBL-KOSTL' ] )
     AND NOT line_exists( tab_msg[ msgid = '00' msgnr = '349' msgv1 = 'COBL-KOSTL' ] ).
        " 라인을 연 뒤 0700/03xx 에서 멈춘 경우(= 환차 라인 아님)만 다음 라인으로
        READ TABLE tab_msg INTO DATA(ls_fx_344) WITH KEY msgid = '00' msgnr = '344'.
        IF sy-subrc <> 0
        OR ls_fx_344-msgv1 <> 'SAPMF05A'
        OR NOT ( ls_fx_344-msgv2 = '0700' OR ls_fx_344-msgv2(2) = '03' ).
          EXIT.
        ENDIF.
      ENDIF.
    ENDIF.

    " 다음 후보 라인으로 녹화 경로 붙여서 재실행
    lv_line = lv_line + 1.
    ft[] = lt_ft_org.
    PERFORM add_fx_kostl_path USING    lv_line
                              CHANGING lv_ok.
    ls_ctu-defsize = 'X'.               " 녹화와 같은 표준 화면 크기
    IF lv_ok = abap_false.
      EXIT.
    ENDIF.

  ENDDO.

  ls_ctu = ls_ctu_org.                  " CALL TRANSACTION 옵션 원래대로

  " 끝내 실패 → 첫 실행(원래 BDC) 결과로 되돌림
  IF lv_subrc <> 0 AND lv_try > 1.
    tab_msg[] = lt_msg_org.
    lv_subrc  = lv_subrc_org.
    IF ls_sy_org-msgid IS NOT INITIAL AND ls_sy_org-msgty IS NOT INITIAL.
      MESSAGE ID ls_sy_org-msgid TYPE ls_sy_org-msgty NUMBER ls_sy_org-msgno
              WITH ls_sy_org-msgv1 ls_sy_org-msgv2 ls_sy_org-msgv3 ls_sy_org-msgv4
              INTO DATA(lv_fx_dummy) ##NEEDED.
    ENDIF.
  ENDIF.

  ft[]     = lt_ft_org.
  sy-subrc = lv_subrc.                  " ← 반드시 마지막 문장

  " 이후 기존 sy-subrc / tab_msg 에러 처리 로직 그대로


"=====================================================================
" 원래 BDC 의 저장 OK코드 뒤에 SHDB 녹화 경로 추가 (저장 OK코드는 그대로)
"   0700 =PI → 0610 라인번호 → 0300 =RW → 0002 코스트센터 → 0700 =BU
"=====================================================================
FORM add_fx_kostl_path USING    pv_line TYPE i
                       CHANGING cv_ok   TYPE abap_bool.

  DATA: lv_idx   TYPE i,
        lv_ins   TYPE i,
        lv_buzei TYPE char3.

  cv_ok = abap_false.

  " 1) 저장 OK코드 위치 (ft 안에 하나뿐)
  LOOP AT ft INTO DATA(ls_ft)
       WHERE fnam = 'BDC_OKCODE'
         AND ( fval = '/11' OR fval = '=BU' ).
    lv_idx = sy-tabix.
  ENDLOOP.
  CHECK lv_idx > 0.

  " 2) 그 화면 블록이 끝나는 위치
  lv_ins = lines( ft[] ) + 1.
  LOOP AT ft INTO ls_ft FROM lv_idx + 1 WHERE dynbegin = 'X'.
    lv_ins = sy-tabix.
    EXIT.
  ENDLOOP.

  lv_buzei = |{ pv_line }|.

  " 3) SHDB 녹화 그대로
  INSERT LINES OF VALUE bdcdata_tab(
    ( program = 'SAPMF05A' dynpro = '0700' dynbegin = 'X' )
    ( fnam = 'BDC_CURSOR'  fval = 'RF05A-AZSAL' )
    ( fnam = 'BDC_OKCODE'  fval = '=PI' )

    ( program = 'SAPMF05A' dynpro = '0610' dynbegin = 'X' )
    ( fnam = 'BDC_CURSOR'  fval = '*BSEG-BUZEI' )
    ( fnam = 'BDC_OKCODE'  fval = '=ENTR' )
    ( fnam = '*BSEG-BUZEI' fval = lv_buzei )

    ( program = 'SAPMF05A' dynpro = '0300' dynbegin = 'X' )
    ( fnam = 'BDC_CURSOR'  fval = 'BSEG-WRBTR' )
    ( fnam = 'BDC_OKCODE'  fval = '=RW' )

    ( program = 'SAPLKACB' dynpro = '0002' dynbegin = 'X' )
    ( fnam = 'BDC_CURSOR'  fval = 'COBL-KOSTL' )
    ( fnam = 'BDC_OKCODE'  fval = '=ENTE' )
    ( fnam = 'COBL-KOSTL'  fval = gv_fx_kostl )

    ( program = 'SAPMF05A' dynpro = '0700' dynbegin = 'X' )
    ( fnam = 'BDC_CURSOR'  fval = 'RF05A-NEWBS' )
    ( fnam = 'BDC_OKCODE'  fval = '=BU' ) )
    INTO ft INDEX lv_ins.

  cv_ok = abap_true.

ENDFORM.
