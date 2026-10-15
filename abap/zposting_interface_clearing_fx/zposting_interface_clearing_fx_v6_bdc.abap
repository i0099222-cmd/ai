"=====================================================================
" Z POSTING_INTERFACE_CLEARING : 환차 라인 코스트센터 (v6, BDC)
"
" v4 까지와 다른 점
"  - 환차 라인 번호를 추측하지 않음 (KI 235 MSGV2, 계산식 둘 다 버림)
"    → 개요화면(0700)에서 라인을 1개씩 열어보고
"      "코스트센터 팝업이 뜨는 라인"을 실제 실행 결과로 찾음
"    → 탐색용 실행은 전기(=BU) 전에 끝나므로 전표가 생기지 않음
"  - 팝업 화면(프로그램/번호)과 팝업 후 돌아오는 화면도 실행 결과로 확인 후 사용
"  - 0700 까지 가는 방법은 원래 실패 형태로 결정
"      저장하면 0700 이 다시 뜨는 건 (원화 없는 건) : 저장 그대로 → 0700
"      저장하면 KI 235 로 끝나는 건 (원화 있는 건) : 저장 대신 시뮬레이션(=BS) → 0700
"  - sy-subrc / sy-msg* / tab_msg 를 해당 CALL TRANSACTION 직후 값으로 되돌림
"      v2~v4 는 루프 뒤 sy-subrc 가 LOOP/INSERT 결과(4)로 바뀌어
"      환차 없는 정상 전기도 기존 로직에서 실패로 보일 수 있었음
"  - 모든 실행 결과를 gt_fx_log 에 남김 → 실패하면 어디서 막혔는지 바로 보임
"
" 흐름
"  ① 기존 BDC 그대로 1회 → 전기되면 끝
"  ② 환차 코스트센터 에러면 (0700 다시 뜸 / KI 235)
"     입력 라인 다음 번호부터 하나씩 : 0700 =PI → 0610 라인번호 → 0300 =RW → (BDC 끝)
"       멈춘 화면 0610           : 그 번호 라인 없음 → 탐색 끝
"       멈춘 화면 0700 / 03xx    : 일반 라인
"       멈춘 화면 팝업(SAPLKACB) : 코스트센터 필요 라인 (F)
"       0300 + KI 235            : 코스트센터 필요 라인, 팝업 대신 에러 (M) → '더보기'로 팝업
"  ③ 찾은 첫 라인으로 팝업에 코스트센터 입력 → 돌아오는 화면 확인 (전기 안 함)
"  ④ 찾은 라인 전부 코스트센터 입력 → 0700 =BU 전기
"  실패하면 ① 의 원래 결과를 그대로 돌려줌 (기존 에러 처리 그대로)
"
" 안전장치
"  - 탐색/확인 실행 중 전표가 생기면(F5 312 또는 sy-subrc 0) 즉시 그 결과로 종료
"
" 확인 필요 (gt_fx_log 의 첫 PROBE 줄에 바로 나타남)
"  - 0700 커서 RF05A-AZHAB + =PI → 0610 라인번호 팝업 → 0300 =RW
"    v1 부터 쓰던 화면 흐름. 첫 PROBE 의 stop 이 0610/0700/03xx/팝업 이외면 흐름이 다른 것
"
" ※ ft / tab_msg / ls_ctu / t_ftpost 는 v4 에서 쓰던 실제 이름 그대로
"=====================================================================


"=====================================================================
" 0. v4 에서 넣은 것 제거
"=====================================================================
"  - DO 5 TIMES ... ENDDO 재시도 루프
"  - FORM add_fx_simulation_path / get_fx_line_no
"  - FM 시작부 gv_fx_kostl 읽기 → 아래 2. 로 교체
"  - TYPES ty_t_fx_lines → 아래 1. 에 다시 있음


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

DATA: gv_fx_kostl    TYPE kostl,                     " 환차 라인에 넣을 코스트센터
      gv_fx_n_input  TYPE i,                         " 입력 라인 수 (FTPOST 아이템)
      gv_fx_pop_prog TYPE bdcdata-program,           " 코스트센터 팝업 화면
      gv_fx_pop_dynp TYPE bdcdata-dynpro,
      gt_fx_log      TYPE string_table.              " 실행 기록 (디버거에서 확인)


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

  DATA: lv_entry TYPE char1,          " P : 저장 그대로 → 0700 / S : =BS → 0700
        lv_mode  TYPE char1,          " F : =RW 때 팝업 / M : 더보기로 팝업
        lv_after TYPE char1,          " 팝업 후 돌아오는 화면 7 : 0700 / 3 : 0300
        lv_class TYPE char1,
        lv_line  TYPE i,
        lv_ok    TYPE abap_bool,
        lt_none  TYPE ty_t_fx_lines,
        lt_fx    TYPE ty_t_fx_lines,
        lt_first TYPE ty_t_fx_lines,
        lt_ft    TYPE bdcdata_tab,
        ls_run   TYPE ty_fx_run.

  PERFORM fx_log_run USING 'ORIGINAL' 0 space is_org.

  "--- ① 환차 코스트센터 에러인지 + 0700 까지 가는 방법
  IF is_org-stop_prog = 'SAPMF05A' AND is_org-stop_dynp = '0700'.
    lv_entry = 'P'.
  ELSEIF line_exists( is_org-msgs[ msgid = 'KI' msgnr = '235' ] ).
    lv_entry = 'S'.
  ELSE.
    PERFORM fx_log USING '환차 코스트센터 에러 아님 → 기존 처리'.
    RETURN.
  ENDIF.

  "--- ② 라인을 하나씩 열어서 코스트센터 팝업이 뜨는 라인 찾기 (전기 안 함)
  CLEAR: gv_fx_pop_prog, gv_fx_pop_dynp.
  lv_line = gv_fx_n_input.                         " 입력 라인은 건너뜀

  DO gc_fx_max_probe TIMES.
    lv_line = lv_line + 1.

    PERFORM fx_build USING    it_ft_org lv_entry lt_none space space lv_line abap_false
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
      WHEN 'F' OR 'M'.                             " 코스트센터 필요한 라인
        INSERT lv_line INTO TABLE lt_fx.
        IF lv_mode IS INITIAL.
          lv_mode = lv_class.
          IF lv_class = 'F'.
            gv_fx_pop_prog = ls_run-stop_prog.
            gv_fx_pop_dynp = ls_run-stop_dynp.
          ENDIF.
        ENDIF.
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

  IF gv_fx_pop_prog IS INITIAL.                    " M : 더보기로 띄우는 표준 팝업
    gv_fx_pop_prog = 'SAPLKACB'.
    gv_fx_pop_dynp = '0002'.
  ENDIF.

  "--- ③ 첫 라인으로 팝업에 코스트센터 입력 → 돌아오는 화면 확인 (전기 안 함)
  lv_line = lt_fx[ 1 ].
  INSERT lv_line INTO TABLE lt_first.

  PERFORM fx_build USING    it_ft_org lv_entry lt_first lv_mode space 0 abap_false
                   CHANGING lt_ft lv_ok.
  PERFORM fx_run   USING lt_ft is_ctu CHANGING ls_run.
  PERFORM fx_log_run USING 'LANDING' lv_line space ls_run.

  IF ls_run-posted = abap_true.
    cs_res = ls_run.
    RETURN.
  ENDIF.

  IF ls_run-stop_prog = 'SAPMF05A' AND ls_run-stop_dynp = '0700'.
    lv_after = '7'.
  ELSEIF ls_run-stop_prog = 'SAPMF05A' AND ls_run-stop_dynp = '0300'.
    lv_after = '3'.
  ELSE.
    PERFORM fx_log USING '팝업 입력 후 예상 밖 화면 (코스트센터 값 / 팝업 필드 확인)'.
    RETURN.
  ENDIF.

  "--- ④ 찾은 라인 전부 코스트센터 입력 후 전기
  PERFORM fx_build USING    it_ft_org lv_entry lt_fx lv_mode lv_after 0 abap_true
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
* BDC 만들기
*   it_lines : 코스트센터를 넣을 라인들
*   iv_mode  : F = 0300 =RW 때 팝업 / M = 0300 더보기(DKACB-FMORE)로 팝업
*   iv_after : 팝업 후 7 = 0700 / 3 = 0300(=RW 한 번 더) / 공백 = 거기서 끝
*   iv_probe : > 0 이면 그 라인을 열고 =RW 후 끝 (탐색)
*   iv_post  : X 면 마지막에 0700 =BU
*---------------------------------------------------------------------*
FORM fx_build USING    it_ft_org TYPE bdcdata_tab
                       iv_entry  TYPE char1
                       it_lines  TYPE ty_t_fx_lines
                       iv_mode   TYPE char1
                       iv_after  TYPE char1
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

  " 2) S : 저장 대신 시뮬레이션
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

  " 탐색/확인용은 그 뒤 화면 데이터 삭제 (전기까지 가지 않음)
  IF iv_post = abap_false AND lv_end <= lines( ct_ft ).
    DELETE ct_ft FROM lv_end.
  ENDIF.

  " 4) 코스트센터 넣을 라인들
  LOOP AT it_lines INTO DATA(lv_line).
    lv_buzei = |{ lv_line }|.

    APPEND LINES OF VALUE bdcdata_tab(
      ( program = 'SAPMF05A' dynpro = '0700' dynbegin = 'X' )
      ( fnam = 'BDC_CURSOR'  fval = 'RF05A-AZHAB' )
      ( fnam = 'BDC_OKCODE'  fval = '=PI' )
      ( program = 'SAPMF05A' dynpro = '0610' dynbegin = 'X' )
      ( fnam = '*BSEG-BUZEI' fval = lv_buzei )
      ( fnam = 'BDC_OKCODE'  fval = '=ENTR' ) ) TO lt_add.

    IF iv_mode = 'M'.
      APPEND LINES OF VALUE bdcdata_tab(
        ( program = 'SAPMF05A' dynpro = '0300' dynbegin = 'X' )
        ( fnam = 'DKACB-FMORE' fval = 'X' )
        ( fnam = 'BDC_OKCODE'  fval = '/00' ) ) TO lt_add.
    ELSE.
      APPEND LINES OF VALUE bdcdata_tab(
        ( program = 'SAPMF05A' dynpro = '0300' dynbegin = 'X' )
        ( fnam = 'BDC_OKCODE'  fval = '=RW' ) ) TO lt_add.
    ENDIF.

    APPEND LINES OF VALUE bdcdata_tab(
      ( program = gv_fx_pop_prog dynpro = gv_fx_pop_dynp dynbegin = 'X' )
      ( fnam = 'BDC_CURSOR'  fval = 'COBL-KOSTL' )
      ( fnam = 'COBL-KOSTL'  fval = gv_fx_kostl )
      ( fnam = 'BDC_OKCODE'  fval = '=ENTE' ) ) TO lt_add.

    IF iv_after = '3'.
      APPEND LINES OF VALUE bdcdata_tab(
        ( program = 'SAPMF05A' dynpro = '0300' dynbegin = 'X' )
        ( fnam = 'BDC_OKCODE'  fval = '=RW' ) ) TO lt_add.
    ENDIF.
  ENDLOOP.

  " 5) 탐색 : 이 라인을 열고 =RW 후 끝 (멈춘 화면으로 판단)
  IF iv_probe > 0.
    lv_buzei = |{ iv_probe }|.
    APPEND LINES OF VALUE bdcdata_tab(
      ( program = 'SAPMF05A' dynpro = '0700' dynbegin = 'X' )
      ( fnam = 'BDC_CURSOR'  fval = 'RF05A-AZHAB' )
      ( fnam = 'BDC_OKCODE'  fval = '=PI' )
      ( program = 'SAPMF05A' dynpro = '0610' dynbegin = 'X' )
      ( fnam = '*BSEG-BUZEI' fval = lv_buzei )
      ( fnam = 'BDC_OKCODE'  fval = '=ENTR' )
      ( program = 'SAPMF05A' dynpro = '0300' dynbegin = 'X' )
      ( fnam = 'BDC_OKCODE'  fval = '=RW' ) ) TO lt_add.
  ENDIF.

  " 6) 전기
  IF iv_post = abap_true.
    APPEND LINES OF VALUE bdcdata_tab(
      ( program = 'SAPMF05A' dynpro = '0700' dynbegin = 'X' )
      ( fnam = 'BDC_OKCODE'  fval = '=BU' ) ) TO lt_add.
  ENDIF.

  INSERT LINES OF lt_add INTO ct_ft INDEX lv_end.
  cv_ok = abap_true.

ENDFORM.


*---------------------------------------------------------------------*
* 탐색 결과 분류
*   N : 그 번호 라인 없음 (0610 에서 막힘)        → 탐색 끝
*   O : 일반 라인 (팝업 없이 0700 / 고객·구매처 라인 화면)
*   F : =RW 때 팝업이 뜬 라인                     → 코스트센터 필요
*   M : 0300 에서 KI 235 로 멈춘 라인             → 코스트센터 필요
*   X : 0700 까지 못 감 (3100 등)                 → 이 경로 불가
*---------------------------------------------------------------------*
FORM fx_classify USING    is_run   TYPE ty_fx_run
                 CHANGING cv_class TYPE char1.

  CLEAR cv_class.

  IF is_run-stop_prog = 'SAPMF05A'.
    IF is_run-stop_dynp = '0610'
    OR line_exists( is_run-msgs[ msgtyp = 'E' dyname = 'SAPMF05A' dynumb = '0610' ] ).
      cv_class = 'N'.
    ELSEIF is_run-stop_dynp = '0700'.
      cv_class = 'O'.
    ELSEIF is_run-stop_dynp(2) = '03'.
      IF line_exists( is_run-msgs[ msgid = 'KI' msgnr = '235' dynumb = is_run-stop_dynp ] ).
        cv_class = 'M'.
      ELSE.
        cv_class = 'O'.
      ENDIF.
    ELSE.
      cv_class = 'X'.
    ENDIF.
  ELSEIF is_run-stop_prog IS INITIAL
      OR is_run-stop_prog = 'SAPDF05X'.
    cv_class = 'X'.
  ELSE.
    cv_class = 'F'.
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
" 테스트
"=====================================================================
"  1) 환차가 생기는 건 2가지
"       - 입력 라인에 원화(DMBTR) 있는 건  (원래 KI 235 로 끝나던 건)
"       - 원화 없는 건                    (원래 0700 이 다시 뜨던 건)
"  2) 3. 의 ③ 줄(ft[] = ...)에 브레이크포인트 → gt_fx_log 확인
"       정상 예)
"         ORIGINAL line=0 ... stop=SAPMF05A 0700
"         PROBE line=2 class=O ... stop=SAPMF05A 0700
"         PROBE line=3 class=F ... stop=SAPLKACB 0002
"         PROBE line=4 class=N ... stop=SAPMF05A 0610
"         LANDING line=3 ... stop=SAPMF05A 0700
"         POST line=0 ... posted=X
"  3) 실패하면 gt_fx_log 전체를 그대로 보내주세요
"     (특히 첫 PROBE 줄 = 0700 → 0610 → 0300 화면 흐름이 맞는지)
