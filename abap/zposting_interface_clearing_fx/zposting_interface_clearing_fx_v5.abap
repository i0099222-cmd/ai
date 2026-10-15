"=====================================================================
" Z POSTING_INTERFACE_CLEARING : 환차 라인 코스트센터 (v5)
"
" v1~v4 를 접는 이유
"  - 환차 라인은 FB05 가 저장/시뮬레이션 순간 스스로 만드는 라인
"  - BDC 로 그 라인에 코스트센터를 넣으려면 개요화면(0700)의 라인번호를 알아야 하는데
"    그 번호를 확정할 방법이 없음 → v2~v4 는 추측 위에 추측을 쌓은 구조
"      · KI 235 "계정 &1 &2 ... CO 오브젝트 필요" 의 &2(MSGV2)는 보통 관리회계영역(KOKRS)
"        예) MSGV2 = '1000' → lv_line = 1000 → lv_buzei(char3) = '*00' → 0610 에서 실패
"        예) MSGV2 = 'KR01' → 숫자 변환 실패 → CONTINUE → 재시도 안 함
"      · get_fx_line_no 계산식
"        - BSIS 조회에 GJAHR 조건 없음 (전표번호는 연도마다 재사용)
"        - G/L(agkoa = 'S') + BELNR 선택만 셈 (고객/구매처 반제, 다른 선택필드는 0)
"        - 병렬통화(그룹통화)에서 환차익/환차손이 갈리면 환차 라인이 2개 이상
"        - 번호가 하나만 틀려도 0300 → 팝업 대신 0700 → 00 344 → 루프 종료
"  - BDC 화면에서 저장하면 팝업(SAPLKACB 0002)이 안 뜨는 것은 이미 확인됨
"    → 0002 를 끼워 넣는 방식(fx_kostl, fx_retry)도 매칭될 수 없음
"
" v5 방향
"  - BDC 는 원래대로 둠 (v1~v4 추가분 전부 원복)
"  - 환차 라인이 생성되는 순간 SAP 가 코스트센터를 채우게 함
"      방법 A : OKB9 기본 계정지정            (설정만, 코드 없음, 코스트센터 고정)
"      방법 B : FI 대체(OBBH) exit + ABAP 메모리 (인터페이스 라인의 코스트센터 사용)
"
" ※ t_ftpost / ft / tab_msg / ls_ctu 는 v4 에서 쓰던 실제 이름 그대로
"=====================================================================


"=====================================================================
" 0. 원복 : v1~v4 에서 넣은 것 전부 제거
"=====================================================================
"  - DO 5 TIMES ... ENDDO 재시도 루프 → 원래 CALL TRANSACTION 한 번으로
"  - FORM add_fx_simulation_path / get_fx_line_no / add_fx_kostl_popup
"  - TYPES ty_t_fx_lines
"  - '/11', '=BU' → '=BS' 로 바꾸는 로직
"  (gv_fx_kostl 과 FM 시작부의 코스트센터 읽기는 방법 B 에서 그대로 사용)


"=====================================================================
" 방법 A : OKB9 (코드 수정 없음)
"=====================================================================
"  OKB9 → 신규 항목
"    회사코드   : 반제 회사코드
"    원가요소   : 환차손 계정, 환차익 계정 (OBA1 → KDF 에 지정된 계정) 각각 1줄
"    코스트센터 : 환차 처리용 코스트센터
"
"  - CO 오브젝트 없이 원가요소로 들어오는 라인(= 환차 라인)에 자동으로 채워짐
"  - 화면/BDC 와 무관하게 동작하므로 가장 확실함
"  - 단, 회사코드(+ 사업영역/손익센터) 단위로 고정값
"    → 인터페이스 건마다 코스트센터가 달라야 하면 방법 B


"=====================================================================
" 방법 B : FI 대체 exit + ABAP 메모리
"   Z FM 이 CALL TRANSACTION 직전에 코스트센터를 메모리에 넣고
"   FB05 가 환차 라인(BSEG-KTOSL = 'KDF')을 만들 때 대체 exit 이 꺼내서 채움
"   (CALL TRANSACTION 은 같은 호출 체인이라 ABAP 메모리 공유)
"=====================================================================


"---------------------------------------------------------------------
" B-1. Z 함수그룹 TOP include
"---------------------------------------------------------------------
DATA gv_fx_kostl TYPE kostl.

CONSTANTS gc_fx_kostl_mem TYPE char30 VALUE 'ZFI_FX_KOSTL'.


"---------------------------------------------------------------------
" B-2. FM 시작부 : 입력 라인의 코스트센터를 환차 라인에도 사용 (v2 와 동일)
"      BSEG-KOSTL 은 내부형식으로 들어가야 하므로 ALPHA 변환
"---------------------------------------------------------------------
  CLEAR gv_fx_kostl.
  LOOP AT t_ftpost INTO DATA(ls_ftpost)
       WHERE stype = 'P'
         AND ( fnam = 'COBL-KOSTL' OR fnam = 'BSEG-KOSTL' )
         AND fval IS NOT INITIAL
         AND fval <> '/'.
    gv_fx_kostl = |{ CONV kostl( ls_ftpost-fval ) ALPHA = IN }|.
    EXIT.
  ENDLOOP.


"---------------------------------------------------------------------
" B-3. CALL TRANSACTION 하는 FORM : 앞뒤로 메모리만 추가
"---------------------------------------------------------------------
  FREE MEMORY ID gc_fx_kostl_mem.
  IF gv_fx_kostl IS NOT INITIAL.
    EXPORT fx_kostl = gv_fx_kostl TO MEMORY ID gc_fx_kostl_mem.
  ENDIF.

  " ↓↓↓ 기존 CALL TRANSACTION 문장 그대로 (재시도 루프 없음) ↓↓↓
  CALL TRANSACTION 'FB05' USING ft
       OPTIONS FROM ls_ctu
       MESSAGES INTO tab_msg.
  " ↑↑↑ 기존 CALL TRANSACTION 문장 그대로 ↑↑↑

  FREE MEMORY ID gc_fx_kostl_mem.     " 다른 FB05 전기에 영향 없도록

  " 이후 기존 sy-subrc / tab_msg 에러 처리 로직 그대로


"---------------------------------------------------------------------
" B-4. 대체 exit 프로그램 (RGGBS000 복사본, 예: ZGGBS000)
"      GCX2 에서 GBLS 에 ZGGBS000 이 지정돼 있는지 확인
"---------------------------------------------------------------------

*  FORM get_exit_titles 안, 다른 exits APPEND 들 옆에 추가
  exits-name  = 'U900'.
  exits-param = c_exit_param_field.
  exits-title = 'FB05 환차라인 코스트센터(인터페이스)'.
  APPEND exits.


*---------------------------------------------------------------------*
*  FORM U900 : FB05 환차 라인 코스트센터
*   - Z POSTING_INTERFACE_CLEARING 이 메모리에 넣어둔 값만 사용
*   - 메모리가 없으면(일반 FB05, 외화평가 등) 아무것도 안 함
*   - 이미 코스트센터가 있으면 건드리지 않음
*---------------------------------------------------------------------*
FORM u900 USING cv_kostl.

  DATA lv_kostl TYPE kostl.

  CHECK cv_kostl IS INITIAL.

  IMPORT fx_kostl = lv_kostl FROM MEMORY ID 'ZFI_FX_KOSTL'.
  CHECK sy-subrc = 0
    AND lv_kostl IS NOT INITIAL.

  cv_kostl = lv_kostl.

ENDFORM.                                                    "U900


"---------------------------------------------------------------------
" B-5. 설정 (GGB1 / OBBH)
"---------------------------------------------------------------------
"  GGB1 : 재무회계 → 개별항목(호출점 2) → 대체 신규
"    단계 1
"      전제조건 : BKPF-TCODE = 'FB05' AND BSEG-KTOSL = 'KDF'
"      대체필드 : BSEG-KOSTL
"      대체방법 : Exit  U900
"  OBBH : 회사코드 / 호출점 2 / 위 대체 / 활성화 레벨 1
"  GB01 : BSEG / KOSTL 이 '제외(X)' 아닌지 확인 (보통 대체 가능)


"=====================================================================
" 테스트
"=====================================================================
"  1) 환차가 생기는 건으로 2가지 모두
"       - 입력 라인에 원화(DMBTR) 있는 건  (예전 KI 235 로 끝나던 건)
"       - 원화 없는 건                    (예전 0700 이 다시 뜨던 건)
"  2) 전기된 전표의 BSEG 에서 KTOSL = 'KDF' 라인의 KOSTL 확인
"  3) 그래도 KI 235 / 0700 으로 끝나면
"       → 이 릴리즈에서는 환차 라인의 CO 체크가 대체(호출점 2)보다 먼저 도는 것
"       → 방법 A(OKB9) 로 가거나, 환차 계정을 원가요소가 아닌 계정으로 (S/4 : 계정유형 N)
"     이때는 아래 진단 코드로 tab_msg 를 그대로 보내주세요


"=====================================================================
" (진단용) CALL TRANSACTION 직후 메시지 전부 확인
"=====================================================================
  LOOP AT tab_msg INTO DATA(ls_dbg).
    MESSAGE ID ls_dbg-msgid TYPE 'I' NUMBER ls_dbg-msgnr
            WITH ls_dbg-msgv1 ls_dbg-msgv2 ls_dbg-msgv3 ls_dbg-msgv4
            INTO DATA(lv_dbg_txt).
    " 디버거에서 확인할 값
    "   ls_dbg-msgtyp / msgid / msgnr / msgv1~4 / dyname / dynumb / lv_dbg_txt
  ENDLOOP.
