"=====================================================================
" Z POSTING_INTERFACE_CLEARING : 환차 라인 코스트센터 (v7, SHDB 녹화 기준)
"
" SHDB 녹화 (원화 없음, 부분지급, 환차 라인 = 3번)
"   SAPDF05X 3100  =PART / 부분지급액 입력 후 저장
"   SAPMF05A 0700  BDC_CURSOR RF05A-AZSAL   =PI
"   SAPMF05A 0610  *BSEG-BUZEI = 3          =ENTR
"   SAPMF05A 0300  BDC_CURSOR BSEG-WRBTR    =RW
"   SAPLKACB 0002  COBL-KOSTL = H0SF0103    =ENTE
"   SAPMF05A 0700  BDC_CURSOR RF05A-NEWBS   =BU
"
" v1~v6 와 녹화가 달랐던 점
"  - 0700 커서 : 녹화 RF05A-AZSAL  ↔ 기존 RF05A-AZHAB
"      =PI 는 커서 위치를 보고 동작하므로 이 값이 다르면 0610 팝업이 안 뜰 수 있음
"  - 0700 으로 가는 방법 : 녹화는 "저장 → 0700"  ↔ v1~v4 는 저장을 =BS(시뮬레이션)로 바꿈
"      → v7 은 원래 저장 OK코드 그대로 두고 0700 에서 이어감 (녹화와 같음)
"  - 환차 라인 번호 : v2~v4 는 추측 → v7 은 라인을 하나씩 열어 팝업이 뜨는 라인을 찾음
"
" 흐름
"  ① 기존 BDC 그대로 1회 → 전기되면 끝
"  ② 0700 에서 멈췄으면 (= 저장했더니 0700 이 다시 뜸 : 녹화와 같은 상황)
"     입력 라인 다음 번호부터 하나씩 : 0700 =PI → 0610 번호 → 0300 =RW → (BDC 끝)
"       멈춘 화면 0610      : 그 번호 라인 없음 → 탐색 끝
"       멈춘 화면 SAPLKACB  : 코스트센터 팝업이 뜬 라인 → 환차 라인
"       그 외 (0700 등)     : 일반 라인
"     ※ 탐색 실행은 =BU 전에 끝나므로 전표 안 생김
"  ③ 찾은 라인 전부 녹화대로 코스트센터 입력 → 0700 =BU
"  실패하면 ① 의 원래 결과를 그대로 돌려줌 (기존 에러 처리 그대로)
"
" ※ 원화(DMBTR) 있는 건 (저장 시 KI 235) 은 녹화가 없어서
"    저장 대신 =BS 로 0700 에 가보는 방식으로만 시도 (검증 안 됨, 로그 확인)
" ※ 녹화의 BDC_SUBSCR 줄은 넣지 않음 (기존 BDC 와 동일하게 생략)
" ※ ft / tab_msg / ls_ctu / t_ftpost 는 v4 에서 쓰던 실제 이름 그대로
"=====================================================================


"=====================================================================
" 0. 이전 버전에서 넣은 것 제거
"=====================================================================
"  - DO 5 TIMES ... ENDDO 재시도 루프, FORM add_fx_simulation_path / get_fx_line_no
"  - v6 를 넣었다면 v6 의 TOP / FM 시작부 / 래퍼 / FORM 전부 → 이 파일로 교체


"=====================================================================
" 1. TOP include
"=====================================================================
TYPES ty_t_fx_lines TYPE SORTED TABLE OF i WITH UNIQUE KEY table_line.

TYPES: BEGIN OF ty_fx_run,
         subrc     TYPE sysubrc,
         posted    TYPE abap_bool,                   " 전표 생성됨
         msg       TYPE symsg,                       " CALL TRANSACTION 직후 sy-msg*
         stop_prog TYPE bdcmsgcoll-dyname,           " BDC 가 멈춘 화면
         stop_dynp TYPE bdcmsgcoll-dynumb,
         msgs      TYPE STANDARD TABLE OF bdcmsgcoll WITH DEFAULT KEY,
       END OF ty_fx_run.

CONSTANTS gc_fx_max_probe TYPE i VALUE 40.           " 탐색할 최대 라인 수

DATA: gv_fx_kostl   TYPE kostl,                      " 환차 라인에 넣을 코스트센터
      gv_fx_n_input TYPE i,                          " 입력 라인 수 (FTPOST 아이템)
      gt_fx_log     TYPE string_table.               " 실행 기록 (디버거에서 확인)


"=====================================================================
" 2. FM 시작부 : 입력 라인 코스트센터 + 입력 라인 수
"=====================================================================
  CLEAR: gv_fx_kostl, gv_fx_n_input.
  LOOP AT t_ftpost INTO DATA(ls_fx_post) WHERE stype = 'P'.
    IF gv_fx_kostl IS INITIAL
   AND ( ls_fx_post-fnam = 'COBL-KOSTL' OR ls_fx_post-fnam = 'BSEG-KOSTL' )
   AND ls_fx_post-fval IS NOT INITIAL
   AND ls_fx_post-fval <> '/'.
      gv_fx_kostl = ls_fx_post-fval.
    ENDIF.
    IF ls_fx_post-count > gv_fx_n_input.
      gv_fx_n_input = ls_fx_post-count.
    ENDIF.
  ENDLOOP.


"=====================================================================
" 3. CALL TRANSACTION 하는 FORM : 기존 CALL TRANSACTION 문장을 아래로 교체
"=====================================================================
  DATA: lt_fx_ft_org TYPE bdcdata_tab,
        ls_fx_org    TYPE ty_fx_run,
        ls_fx_res    TYPE ty_fx_run.

  lt_fx_ft_org = ft[].
  CLEAR gt_fx_log.

  " ① 기존 BDC 그대로 1회
  PERFORM fx_run USING lt_fx_ft_org ls_ctu CHANGING ls_fx_org.
  ls_fx_res = ls_fx_org.

  " ② 전기 안 됐고 코스트센터 값이 있으면 환차 라인 처리
  IF ls_fx_org-posted = abap_false
 AND gv_fx_kostl IS NOT INITIAL.
    PERFORM fx_handle USING    lt_fx_ft_org ls_fx_org ls_ctu
                      CHANGING ls_fx_res.
  ENDIF.

  " ③ 기존 처리 로직이 보던 값으로 되돌림
  ft[]      = lt_fx_ft_org.
  tab_msg[] = ls_fx_res-msgs.
  PERFORM fx_set_symsg USING ls_fx_res-msg.
  sy-subrc  = ls_fx_res-subrc.                       " 반드시 마지막 문장

  " ↓↓↓ 여기부터 기존 sy-subrc / tab_msg 처리 로직 그대로 ↓↓↓


"=====================================================================
" 4. FORM 들
"=====================================================================

*---------------------------------------------------------------------*
* CALL TRANSACTION 1회 + 결과 정리
*---------------------------------------------------------------------*
FORM fx_run USING    it_ft  TYPE bdcdata_tab
                     is_ctu TYPE ctu_params
            CHANGING cs_run TYPE ty_fx_run.

  DATA: lt_ft  TYPE bdcdata_tab,
        lt_msg TYPE STANDARD TABLE OF bdcmsgcoll WITH DEFAULT KEY.

  CLEAR cs_run.
  lt_ft = it_ft.

  CALL TRANSACTION 'FB05' USING lt_ft
       OPTIONS FROM is_ctu
       MESSAGES INTO lt_msg.

  cs_run-subrc  = sy-subrc.
  cs_run-msg    = VALUE #( msgty = sy-msgty  msgid = sy-msgid  msgno = sy-msgno
                           msgv1 = sy-msgv1  msgv2 = sy-msgv2
                           msgv3 = sy-msgv3  msgv4 = sy-msgv4 ).
  cs_run-msgs   = lt_msg.
  cs_run-posted = xsdbool( cs_run-subrc = 0
                        OR line_exists( lt_msg[ msgid = 'F5' msgnr = '312' ] ) ).

  " 멈춘 화면 : 마지막 00 344 (No batch input data for screen &1 &2)
  LOOP AT lt_msg INTO DATA(ls_msg) WHERE msgid = '00' AND msgnr = '344'.
    cs_run-stop_prog = ls_msg-msgv1.
    cs_run-stop_dynp = ls_msg-msgv2.
  ENDLOOP.

  " 344 없이 끝났으면 마지막 E/A 메시지가 난 화면
  IF cs_run-stop_prog IS INITIAL.
    LOOP AT lt_msg INTO ls_msg WHERE msgtyp = 'E' OR msgtyp = 'A'.
      cs_run-stop_prog = ls_msg-dyname.
      cs_run-stop_dynp = ls_msg-dynumb.
    ENDLOOP.
  ENDIF.

ENDFORM.


*---------------------------------------------------------------------*
* 환차 라인 코스트센터 처리
*---------------------------------------------------------------------*
FORM fx_handle USING    it_ft_org TYPE bdcdata_tab
                        is_org    TYPE ty_fx_run
                        is_ctu    TYPE ctu_params
               CHANGING cs_res    TYPE ty_fx_run.

  DATA: lv_entry TYPE char1,          " P : 저장 그대로 → 0700 (녹화) / S : =BS → 0700
        lv_class TYPE char1,
        lv_line  TYPE i,
        lv_ok    TYPE abap_bool,
        lt_none  TYPE ty_t_fx_lines,
        lt_fx    TYPE ty_t_fx_lines,
        lt_ft    TYPE bdcdata_tab,
        ls_run   TYPE ty_fx_run.

  PERFORM fx_log_run USING 'ORIGINAL' 0 space is_org.

  "--- ① 0700 까지 가는 방법
  IF is_org-stop_prog = 'SAPMF05A' AND is_org-stop_dynp = '0700'.
    lv_entry = 'P'.                                " 녹화와 같은 상황
  ELSEIF line_exists( is_org-msgs[ msgid = 'KI' msgnr = '235' ] ).
    lv_entry = 'S'.                                " 원화 있는 건 (검증 안 됨)
  ELSE.
    PERFORM fx_log USING '환차 코스트센터 에러 아님 → 기존 처리'.
    RETURN.
  ENDIF.

  "--- ② 라인을 하나씩 열어서 코스트센터 팝업이 뜨는 라인 찾기 (전기 안 함)
  lv_line = gv_fx_n_input.                         " 입력 라인은 건너뜀

  DO gc_fx_max_probe TIMES.
    lv_line = lv_line + 1.

    PERFORM fx_build USING    it_ft_org lv_entry lt_none lv_line abap_false
                     CHANGING lt_ft lv_ok.
    IF lv_ok = abap_false.
      PERFORM fx_log USING 'BDC 에서 전기 OK코드(/11, =BU)를 못 찾음'.
      RETURN.
    ENDIF.

    PERFORM fx_run USING lt_ft is_ctu CHANGING ls_run.
    IF ls_run-posted = abap_true.                  " 혹시 전기됐으면 그대로 종료
      PERFORM fx_log_run USING 'PROBE-POSTED' lv_line space ls_run.
      cs_res = ls_run.
      RETURN.
    ENDIF.

    PERFORM fx_classify USING ls_run CHANGING lv_class.
    PERFORM fx_log_run  USING 'PROBE' lv_line lv_class ls_run.

    CASE lv_class.
      WHEN 'N'.                                    " 마지막 라인 지남
        EXIT.
      WHEN 'F'.                                    " 코스트센터 팝업이 뜬 라인
        INSERT lv_line INTO TABLE lt_fx.
      WHEN 'X'.                                    " 0700 까지 못 감
        PERFORM fx_log USING '0700 까지 못 감 → 이 건은 이 경로 불가'.
        RETURN.
      WHEN OTHERS.                                 " O : 일반 라인
    ENDCASE.
  ENDDO.

  IF lt_fx IS INITIAL.
    PERFORM fx_log USING '코스트센터 팝업이 뜨는 라인을 못 찾음'.
    RETURN.
  ENDIF.

  "--- ③ 찾은 라인 전부 코스트센터 입력 후 전기
  PERFORM fx_build USING    it_ft_org lv_entry lt_fx 0 abap_true
                   CHANGING lt_ft lv_ok.
  PERFORM fx_run   USING lt_ft is_ctu CHANGING ls_run.
  PERFORM fx_log_run USING 'POST' 0 space ls_run.

  IF ls_run-posted = abap_true.
    cs_res = ls_run.                               " 성공 결과(F5 312)를 기존 로직에 넘김
  ELSE.
    PERFORM fx_log USING '최종 전기 실패 → 원래 에러로 리턴'.
  ENDIF.

ENDFORM.


*---------------------------------------------------------------------*
* BDC 만들기 (화면/필드/OK코드는 SHDB 녹화 그대로)
*   it_lines : 코스트센터를 넣을 라인들
*   iv_probe : > 0 이면 그 라인을 열고 =RW 후 끝 (탐색)
*   iv_post  : X 면 마지막에 0700 =BU
*---------------------------------------------------------------------*
FORM fx_build USING    it_ft_org TYPE bdcdata_tab
                       iv_entry  TYPE char1
                       it_lines  TYPE ty_t_fx_lines
                       iv_probe  TYPE i
                       iv_post   TYPE abap_bool
              CHANGING ct_ft     TYPE bdcdata_tab
                       cv_ok     TYPE abap_bool.

  DATA: lv_idx   TYPE i,
        lv_end   TYPE i,
        lv_buzei TYPE char3,
        ls_ft    TYPE bdcdata,
        lt_add   TYPE bdcdata_tab.

  cv_ok = abap_false.
  ct_ft = it_ft_org.

  " 1) 전기 OK코드 위치 (ft 안에 하나뿐)
  LOOP AT ct_ft INTO ls_ft
       WHERE fnam = 'BDC_OKCODE'
         AND ( fval = '/11' OR fval = '=BU' ).
    lv_idx = sy-tabix.
  ENDLOOP.
  CHECK lv_idx > 0.

  " 2) S : 저장 대신 시뮬레이션 (P 는 녹화대로 저장 그대로)
  IF iv_entry = 'S'.
    READ TABLE ct_ft INTO ls_ft INDEX lv_idx.
    ls_ft-fval = '=BS'.
    MODIFY ct_ft FROM ls_ft INDEX lv_idx.
  ENDIF.

  " 3) 그 화면 블록이 끝나는 위치
  lv_end = lines( ct_ft ) + 1.
  LOOP AT ct_ft INTO ls_ft FROM lv_idx + 1 WHERE dynbegin = 'X'.
    lv_end = sy-tabix.
    EXIT.
  ENDLOOP.

  " 탐색용은 그 뒤 화면 데이터 삭제 (전기까지 가지 않음)
  IF iv_post = abap_false AND lv_end <= lines( ct_ft ).
    DELETE ct_ft FROM lv_end.
  ENDIF.

  " 4) 환차 라인마다 : 0700 =PI → 0610 번호 → 0300 =RW → 0002 코스트센터 (녹화)
  LOOP AT it_lines INTO DATA(lv_line).
    lv_buzei = |{ lv_line }|.
    APPEND LINES OF VALUE bdcdata_tab(
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
      ( fnam = 'COBL-KOSTL'  fval = gv_fx_kostl ) ) TO lt_add.
  ENDLOOP.

  " 5) 탐색 : 이 라인을 열고 =RW 후 끝 (멈춘 화면으로 판단)
  IF iv_probe > 0.
    lv_buzei = |{ iv_probe }|.
    APPEND LINES OF VALUE bdcdata_tab(
      ( program = 'SAPMF05A' dynpro = '0700' dynbegin = 'X' )
      ( fnam = 'BDC_CURSOR'  fval = 'RF05A-AZSAL' )
      ( fnam = 'BDC_OKCODE'  fval = '=PI' )

      ( program = 'SAPMF05A' dynpro = '0610' dynbegin = 'X' )
      ( fnam = 'BDC_CURSOR'  fval = '*BSEG-BUZEI' )
      ( fnam = 'BDC_OKCODE'  fval = '=ENTR' )
      ( fnam = '*BSEG-BUZEI' fval = lv_buzei )

      ( program = 'SAPMF05A' dynpro = '0300' dynbegin = 'X' )
      ( fnam = 'BDC_CURSOR'  fval = 'BSEG-WRBTR' )
      ( fnam = 'BDC_OKCODE'  fval = '=RW' ) ) TO lt_add.
  ENDIF.

  " 6) 전기 (녹화 마지막 화면)
  IF iv_post = abap_true.
    APPEND LINES OF VALUE bdcdata_tab(
      ( program = 'SAPMF05A' dynpro = '0700' dynbegin = 'X' )
      ( fnam = 'BDC_CURSOR'  fval = 'RF05A-NEWBS' )
      ( fnam = 'BDC_OKCODE'  fval = '=BU' ) ) TO lt_add.
  ENDIF.

  INSERT LINES OF lt_add INTO ct_ft INDEX lv_end.
  cv_ok = abap_true.

ENDFORM.


*---------------------------------------------------------------------*
* 탐색 결과 분류
*   N : 그 번호 라인 없음 (0610 에서 막힘)  → 탐색 끝
*   F : 코스트센터 팝업(SAPLKACB)이 뜬 라인 → 환차 라인
*   X : 0700 까지 못 감 (3100 등)           → 이 경로 불가
*   O : 그 외 (팝업 없이 0700 으로 돌아감 등) → 일반 라인
*---------------------------------------------------------------------*
FORM fx_classify USING    is_run   TYPE ty_fx_run
                 CHANGING cv_class TYPE char1.

  IF ( is_run-stop_prog = 'SAPMF05A' AND is_run-stop_dynp = '0610' )
  OR line_exists( is_run-msgs[ msgtyp = 'E' dyname = 'SAPMF05A' dynumb = '0610' ] ).
    cv_class = 'N'.
  ELSEIF is_run-stop_prog = 'SAPLKACB'.
    cv_class = 'F'.
  ELSEIF is_run-stop_prog IS INITIAL
      OR is_run-stop_prog = 'SAPDF05X'.
    cv_class = 'X'.
  ELSE.
    cv_class = 'O'.
  ENDIF.

ENDFORM.


*---------------------------------------------------------------------*
* sy-msgid / msgty / msgno / msgv1~4 되돌리기
*---------------------------------------------------------------------*
FORM fx_set_symsg USING is_msg TYPE symsg.

  DATA lv_dummy TYPE string ##NEEDED.

  CHECK is_msg-msgid IS NOT INITIAL
    AND is_msg-msgty IS NOT INITIAL.

  MESSAGE ID is_msg-msgid TYPE is_msg-msgty NUMBER is_msg-msgno
          WITH is_msg-msgv1 is_msg-msgv2 is_msg-msgv3 is_msg-msgv4
          INTO lv_dummy.

ENDFORM.


*---------------------------------------------------------------------*
* 로그
*---------------------------------------------------------------------*
FORM fx_log USING iv_text TYPE csequence.
  APPEND CONV string( iv_text ) TO gt_fx_log.
ENDFORM.

FORM fx_log_run USING iv_step  TYPE csequence
                      iv_line  TYPE i
                      iv_class TYPE char1
                      is_run   TYPE ty_fx_run.

  APPEND |{ iv_step } line={ iv_line } class={ iv_class } subrc={ is_run-subrc } | &&
         |posted={ is_run-posted } stop={ is_run-stop_prog } { is_run-stop_dynp }|
         TO gt_fx_log.

  LOOP AT is_run-msgs INTO DATA(ls_m).
    APPEND |    { ls_m-msgtyp } { ls_m-msgid }-{ ls_m-msgnr } @{ ls_m-dyname } { ls_m-dynumb } | &&
           |[{ ls_m-msgv1 }][{ ls_m-msgv2 }][{ ls_m-msgv3 }][{ ls_m-msgv4 }]|
           TO gt_fx_log.
  ENDLOOP.

ENDFORM.


"=====================================================================
" 테스트 (녹화한 건과 같은 데이터로 먼저)
"=====================================================================
"  3. 의 ③ 줄(ft[] = ...)에 브레이크포인트 → gt_fx_log 확인
"   기대값 (입력 라인 1개, 환차 라인 3번)
"     ORIGINAL line=0 ...           stop=SAPMF05A 0700
"     PROBE    line=2 class=O ...   stop=SAPMF05A 0700
"     PROBE    line=3 class=F ...   stop=SAPLKACB 0002
"     PROBE    line=4 class=N ...   stop=SAPMF05A 0610
"     POST     line=0 ... posted=X
"  다르게 나오면 gt_fx_log 전체를 보내주세요
