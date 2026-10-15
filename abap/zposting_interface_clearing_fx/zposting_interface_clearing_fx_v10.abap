"=====================================================================
" Z POSTING_INTERFACE_CLEARING : 환차 라인 코스트센터 (v10)
"   v4 와 같은 모양 (기존 CALL TRANSACTION 문장 그대로, DO 루프로 감싸기)
"   + SHDB 녹화 흐름으로 수정
"
" v9 대비 변경 (테스트용 기록만 추가, 동작은 v9 와 같음)
"  - 회차마다 시도한 라인번호 + tab_msg 전체를 lt_fx_log 에 남김
"    → 코스트센터 팝업(SAPLKACB 0002)에 COBL-KOSTL 이 없다고 나온 게
"      몇 번 라인을 열었을 때인지 확인하기 위함
"
" v8 대비 변경 (테스트 결과 반영)
"  - 첫 실행 메시지가 F5 413 (Correct the marked line items) 이면 처리 대상
"      v8 은 "00 344 SAPMF05A 0700" 만 봐서, 0733 에서 멈춘 건은 바로 종료했음
"  - 2회차부터는 라인을 연 뒤 0700/03xx 에서 멈춘 경우만 다음 라인으로
"      (그 외 화면에서 멈추면 같은 결과가 반복되므로 바로 종료)
"
" SHDB 녹화 (원화 없음, 환차 라인 = 3번)
"   SAPDF05X 3100  저장
"   SAPMF05A 0700  BDC_CURSOR RF05A-AZSAL   =PI
"   SAPMF05A 0610  *BSEG-BUZEI = 3          =ENTR
"   SAPMF05A 0300  BDC_CURSOR BSEG-WRBTR    =RW
"   SAPLKACB 0002  COBL-KOSTL               =ENTE
"   SAPMF05A 0700  BDC_CURSOR RF05A-NEWBS   =BU
"
" v4 대비 변경
"  1) 저장 OK코드를 =BS 로 바꾸지 않음 → 녹화처럼 저장 → 0700 에서 이어감
"  2) 0700 커서 RF05A-AZHAB → RF05A-AZSAL (녹화 값), 나머지 커서도 녹화대로
"  3) 환차 라인 번호 : KI 235 MSGV2 / 계산식 삭제
"     → 입력 라인 다음 번호부터 차례로 녹화 경로 + =BU 로 시도
"       틀린 라인 : 0300 =RW 후 팝업이 안 떠서 BDC 가 멈춤 (=BU 전) → 전표 안 생김
"       맞는 라인 : 팝업에 코스트센터 입력 → =BU 전기
"       라인 없음 : 0610 에서 멈춤 → 포기
"  4) v4 버그 수정 : 루프 뒤 sy-subrc 가 LOOP/INSERT 결과로 바뀌던 것
"     → CALL TRANSACTION 직후 sy-subrc 를 보관했다가 마지막에 되돌림
"  5) 끝내 실패하면 첫 실행(원래 BDC)의 tab_msg / sy-subrc / sy-msg* 로 되돌림
"
" 처리 범위
"  - 저장하면 0700 이 다시 뜨는 건 (원화 없음, 녹화와 같은 상황)
"  - 원화 있는 건(KI 235) 은 녹화가 없어서 처리 안 함 → 원래 에러 그대로
"  - 환차 라인이 2개 이상이면 처리 안 됨 → 원래 에러 그대로
"
" ※ ft / tab_msg / ls_ctu / t_ftpost 는 v4 에서 쓰던 실제 이름 그대로
"=====================================================================


"---------------------------------------------------------------------
" TOP include
"---------------------------------------------------------------------
DATA: gv_fx_kostl   TYPE kostl,
      gv_fx_n_input TYPE i.             " 입력 라인 수 (FTPOST 아이템)


"---------------------------------------------------------------------
" FM 시작부 : 입력 라인의 코스트센터 + 입력 라인 수 (v4 + 라인 수)
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
" CALL TRANSACTION 하는 FORM : 기존 호출을 감싸기 (v4 와 같은 자리)
"---------------------------------------------------------------------
  DATA: lt_ft_org    TYPE STANDARD TABLE OF bdcdata,
        lt_msg_org   TYPE STANDARD TABLE OF bdcmsgcoll,
        ls_sy_org    TYPE symsg,
        lv_subrc_org TYPE sysubrc,
        lv_subrc     TYPE sysubrc,
        lv_try       TYPE i,
        lv_line      TYPE i,
        lv_ok        TYPE abap_bool,
        lt_fx_log    TYPE string_table.         " 회차별 기록 (테스트용)

  lt_ft_org = ft[].                     " 원본 BDC 보관
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

    " 회차별 기록 (테스트용) : 1회차 = 원래 BDC, 2회차부터 = 그 회차에 연 라인
    APPEND |#{ lv_try } line={ COND i( WHEN lv_try = 1 THEN 0 ELSE lv_line ) } subrc={ lv_subrc }|
           TO lt_fx_log.
    LOOP AT tab_msg INTO DATA(ls_fx_log).
      APPEND |    { ls_fx_log-msgtyp } { ls_fx_log-msgid }-{ ls_fx_log-msgnr } | &&
             |@{ ls_fx_log-dyname } { ls_fx_log-dynumb } | &&
             |[{ ls_fx_log-msgv1 }][{ ls_fx_log-msgv2 }][{ ls_fx_log-msgv3 }][{ ls_fx_log-msgv4 }]|
             TO lt_fx_log.
    ENDLOOP.

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
      " 라인을 연 뒤 0700/03xx 에서 멈춘 경우(= 환차 라인 아님)만 다음 라인으로
      READ TABLE tab_msg INTO DATA(ls_fx_344) WITH KEY msgid = '00' msgnr = '344'.
      IF sy-subrc <> 0
      OR ls_fx_344-msgv1 <> 'SAPMF05A'
      OR NOT ( ls_fx_344-msgv2 = '0700' OR ls_fx_344-msgv2(2) = '03' ).
        EXIT.
      ENDIF.
    ENDIF.

    " 다음 후보 라인으로 녹화 경로 붙여서 재실행
    lv_line = lv_line + 1.
    ft[] = lt_ft_org.
    PERFORM add_fx_kostl_path USING    lv_line
                              CHANGING lv_ok.
    IF lv_ok = abap_false.
      EXIT.
    ENDIF.

  ENDDO.

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

  ft[]     = lt_ft_org.                 " ← 여기 브레이크포인트 : lt_fx_log 확인
  sy-subrc = lv_subrc.                  " ← 반드시 마지막 문장 (v4 버그 수정)

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


"=====================================================================
" 테스트 (녹화한 건과 같은 데이터, 입력 라인 1개 기준)
"   CALL TRANSACTION 바로 다음 줄에 브레이크포인트 → 회차별 tab_msg 확인
"     1회 : 원래 BDC         → F5 413 (Correct the marked line items)
"     2회 : 라인 2 시도      → 00 344 SAPMF05A 0700 (팝업 안 뜸 = 환차 라인 아님)
"     3회 : 라인 3 시도      → sy-subrc 0, F5 312 (전기)
"   2회차가 0733 등 다른 화면에서 멈추면 그 회차 tab_msg (MSGV1/MSGV2 포함) 를 보내주세요
"=====================================================================
