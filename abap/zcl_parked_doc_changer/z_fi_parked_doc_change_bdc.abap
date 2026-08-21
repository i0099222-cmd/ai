*&---------------------------------------------------------------------*
*& Function Module Z_FI_PARKED_DOC_CHANGE_BDC
*&---------------------------------------------------------------------*
*& 임시전표(파킹 문서) 수정 - CALL TRANSACTION 'FBV2' BDC 래퍼.
*&
*& SE37에서 아래대로 생성:
*&   Function Group : (기존 Z_FI_POST_PARKED_DOC 재사용 또는 신규)
*&   Function Module: Z_FI_PARKED_DOC_CHANGE_BDC
*&
*&   Import 탭
*&     IS_HEADER TYPE ZIF_PARKED_DOC_CHANGER=>TY_HEADER
*&     IT_ITEM   TYPE ZIF_PARKED_DOC_CHANGER=>TT_ITEM   (optional)
*&     IV_MODE   TYPE CTU_PARAMS-DISMODE  Default 'N'   (optional)
*&   Export 탭
*&     EV_MESSAGETYPE TYPE SYMSGTY
*&     EV_MESSAGETEXT TYPE STRING
*&     ET_MESSAGE     TYPE ZIF_PARKED_DOC_CHANGER=>TT_MESSAGE
*&
*&   (TABLES 탭은 쓰지 않음 - IMPORTING/EXPORTING만 사용)
*&
*&   CALL TRANSACTION 은 ABAP Cloud 언어버전에서 금지이므로 이 FM은
*&   Standard ABAP 언어버전 패키지에 두고, SE37 > API State 에서
*&   Local API 로 Release 해야 RAP(ABAP Cloud) 쪽에서 호출 가능하다.
*&
*&   RAP에서 호출할 때는 CALL TRANSACTION 이 자체 COMMIT WORK 를 수행하므로
*&   반드시 SAVE 단계(unmanaged save / late numbering 이후)에서 호출한다.
*&
*& [중요] 아래 화면/OK코드 상수는 클래식 FBV2 흐름 기준 기본값이다.
*&        릴리스/커스터마이징에 따라 화면번호와 OK코드가 다를 수 있으므로
*&        대상 시스템에서 SHDB로 FBV2를 1회 녹화한 뒤 상수 블록만
*&        녹화 결과에 맞춰 교체하면 나머지 로직은 그대로 쓸 수 있다.
*&---------------------------------------------------------------------*
FUNCTION z_fi_parked_doc_change_bdc.

*----------------------------------------------------------------------*
* 화면/OK코드 상수 - SHDB 녹화 결과에 맞춰 이 블록만 조정한다.
*----------------------------------------------------------------------*
  CONSTANTS:
    lc_tcode      TYPE sy-tcode      VALUE 'FBV2',
    " 초기화면(회사코드/전표번호/회계연도)
    lc_prog_init  TYPE bdcdata-program VALUE 'SAPMF05V',
    lc_dynp_init  TYPE bdcdata-dynpro  VALUE '0100',
    " 전표 개요화면(헤더 BKPF 필드 + 명세 테이블컨트롤)
    lc_prog_ovw   TYPE bdcdata-program VALUE 'SAPLF040',
    lc_dynp_ovw   TYPE bdcdata-dynpro  VALUE '0700',
    " 명세 상세화면
    lc_prog_item  TYPE bdcdata-program VALUE 'SAPMF05A',
    lc_dynp_item  TYPE bdcdata-dynpro  VALUE '0302',
    " 명세 상세화면 > 추가 데이터 팝업
    lc_prog_more  TYPE bdcdata-program VALUE 'SAPMF05A',
    lc_dynp_more  TYPE bdcdata-dynpro  VALUE '0331',
    " 개요화면 테이블컨트롤에서 명세를 선택할 때 커서를 놓을 컬럼
    lc_fld_ovwpos TYPE bdcdata-fnam    VALUE 'RF05V-NEWBS',
    " OK 코드
    lc_ok_enter   TYPE bdcdata-fval    VALUE '/00',
    lc_ok_itemdet TYPE bdcdata-fval    VALUE '=PA',    " 명세 상세 진입
    lc_ok_more    TYPE bdcdata-fval    VALUE '=ZK',    " 추가 데이터 팝업
    lc_ok_back    TYPE bdcdata-fval    VALUE '=BACK',  " 개요화면 복귀
    lc_ok_save    TYPE bdcdata-fval    VALUE '=BU'.    " 임시전표 저장

*----------------------------------------------------------------------*
* 로컬 타입
*----------------------------------------------------------------------*
  TYPES:
    ty_t_bdc TYPE STANDARD TABLE OF bdcdata WITH DEFAULT KEY,
    " 구조 컴포넌트명 -> 화면 필드명 매핑
    BEGIN OF ty_map,
      comp   TYPE string,
      dynfld TYPE bdcdata-fnam,
      " 1 = 명세 상세화면, 2 = 추가 데이터 팝업
      block  TYPE i,
    END OF ty_map,
    ty_t_map TYPE STANDARD TABLE OF ty_map WITH EMPTY KEY,
    " 명세별로 미리 만들어 둔 화면 필드
    BEGIN OF ty_item_bdc,
      posid TYPE i,
      t_f1  TYPE ty_t_bdc,
      t_f2  TYPE ty_t_bdc,
    END OF ty_item_bdc,
    ty_t_item_bdc TYPE STANDARD TABLE OF ty_item_bdc WITH EMPTY KEY.

  DATA:
    lt_bdc      TYPE ty_t_bdc,
    lt_hdr_fld  TYPE ty_t_bdc,
    lt_item_bdc TYPE ty_t_item_bdc,
    ls_item_bdc TYPE ty_item_bdc,
    lt_message  TYPE zif_parked_doc_changer=>tt_message,
    lv_fval     TYPE bdcdata-fval,
    lv_change   TYPE abap_bool,
    lv_cursor   TYPE bdcdata-fval,
    lv_okcode   TYPE bdcdata-fval.

  FIELD-SYMBOLS:
    <lv_val> TYPE any,
    <lv_upd> TYPE any.

  CLEAR: ev_messagetype, ev_messagetext, et_message.

*----------------------------------------------------------------------*
* 0) 키 검증
*----------------------------------------------------------------------*
  IF is_header-bukrs IS INITIAL
  OR is_header-belnr IS INITIAL
  OR is_header-gjahr IS INITIAL.
    ev_messagetype = zif_parked_doc_changer=>gc_msgtype-error.
    ev_messagetext = zif_parked_doc_changer=>gc_text_error.
    RETURN.
  ENDIF.

*----------------------------------------------------------------------*
* 1) 헤더 변경 필드 준비 (BKTXT, XBLNR 만 허용)
*----------------------------------------------------------------------*
  DATA(lt_hdr_map) = VALUE ty_t_map(
    ( comp = `BKTXT` dynfld = 'BKPF-BKTXT' block = 0 )
    ( comp = `XBLNR` dynfld = 'BKPF-XBLNR' block = 0 ) ).

  " 변경지시자(UPD)를 하나도 안 넘기면 "값이 채워진 필드만 변경"으로 동작한다.
  " 지시자를 넘기면 공란 지정으로 필드 값 삭제도 가능하다.
  DATA(lv_hdr_by_flag) = xsdbool( is_header-upd IS NOT INITIAL ).

  " IMPORTING 파라미터는 읽기전용이므로 ASSIGN 대상은 로컬 복사본을 쓴다.
  DATA(ls_header) = is_header.

  LOOP AT lt_hdr_map INTO DATA(ls_hdr_map).

    UNASSIGN: <lv_val>, <lv_upd>.
    ASSIGN COMPONENT ls_hdr_map-comp OF STRUCTURE ls_header TO <lv_val>.
    CHECK <lv_val> IS ASSIGNED.
    ASSIGN COMPONENT ls_hdr_map-comp OF STRUCTURE ls_header-upd TO <lv_upd>.

    CLEAR lv_change.
    IF lv_hdr_by_flag = abap_true.
      IF <lv_upd> IS ASSIGNED.
        lv_change = xsdbool( <lv_upd> = abap_true ).
      ENDIF.
    ELSE.
      lv_change = xsdbool( <lv_val> IS NOT INITIAL ).
    ENDIF.
    CHECK lv_change = abap_true.

    CLEAR lv_fval.
    IF <lv_val> IS NOT INITIAL.
      WRITE <lv_val> TO lv_fval LEFT-JUSTIFIED.
    ENDIF.

    APPEND VALUE #( fnam = ls_hdr_map-dynfld fval = lv_fval ) TO lt_hdr_fld.

  ENDLOOP.

*----------------------------------------------------------------------*
* 2) 명세 변경 필드 준비 (요청된 필드만 허용)
*----------------------------------------------------------------------*
  " block 1 : 명세 상세화면에 있는 필드
  " block 2 : 추가 데이터 팝업에 있는 필드
  DATA(lt_item_map) = VALUE ty_t_map(
    ( comp = `SGTXT` dynfld = 'BSEG-SGTXT' block = 1 )
    ( comp = `ZUONR` dynfld = 'BSEG-ZUONR' block = 1 )
    ( comp = `BVTYP` dynfld = 'BSEG-BVTYP' block = 1 )
    ( comp = `HBKID` dynfld = 'BSEG-HBKID' block = 1 )
    ( comp = `ZTERM` dynfld = 'BSEG-ZTERM' block = 1 )
    ( comp = `ZFBDT` dynfld = 'BSEG-ZFBDT' block = 1 )
    ( comp = `ZBD1T` dynfld = 'BSEG-ZBD1T' block = 1 )
    ( comp = `ZBD1P` dynfld = 'BSEG-ZBD1P' block = 1 )
    ( comp = `ZBD2T` dynfld = 'BSEG-ZBD2T' block = 1 )
    ( comp = `ZBD2P` dynfld = 'BSEG-ZBD2P' block = 1 )
    ( comp = `ZBD3T` dynfld = 'BSEG-ZBD3T' block = 1 )
    ( comp = `ZLSCH` dynfld = 'BSEG-ZLSCH' block = 1 )
    ( comp = `ZLSPR` dynfld = 'BSEG-ZLSPR' block = 1 )
    ( comp = `ZBFIX` dynfld = 'BSEG-ZBFIX' block = 1 )
    ( comp = `RSTGR` dynfld = 'BSEG-RSTGR' block = 1 )
    ( comp = `HZUON` dynfld = 'BSEG-HZUON' block = 2 )
    ( comp = `XREF1` dynfld = 'BSEG-XREF1' block = 2 )
    ( comp = `XREF2` dynfld = 'BSEG-XREF2' block = 2 )
    ( comp = `XREF3` dynfld = 'BSEG-XREF3' block = 2 ) ).

  LOOP AT it_item INTO DATA(ls_item).

    CLEAR ls_item_bdc.
    ls_item_bdc-posid = COND #( WHEN ls_item-posid IS NOT INITIAL
                                THEN ls_item-posid
                                ELSE ls_item-buzei ).

    DATA(lv_item_by_flag) = xsdbool( ls_item-upd IS NOT INITIAL ).

    LOOP AT lt_item_map INTO DATA(ls_item_map).

      UNASSIGN: <lv_val>, <lv_upd>.
      ASSIGN COMPONENT ls_item_map-comp OF STRUCTURE ls_item TO <lv_val>.
      CHECK <lv_val> IS ASSIGNED.
      ASSIGN COMPONENT ls_item_map-comp OF STRUCTURE ls_item-upd TO <lv_upd>.

      CLEAR lv_change.
      IF lv_item_by_flag = abap_true.
        IF <lv_upd> IS ASSIGNED.
          lv_change = xsdbool( <lv_upd> = abap_true ).
        ENDIF.
      ELSE.
        lv_change = xsdbool( <lv_val> IS NOT INITIAL ).
      ENDIF.
      CHECK lv_change = abap_true.

      " 날짜/수치 필드도 사용자 설정 포맷으로 변환해서 전송해야 한다.
      CLEAR lv_fval.
      IF <lv_val> IS NOT INITIAL.
        WRITE <lv_val> TO lv_fval LEFT-JUSTIFIED.
      ENDIF.

      IF ls_item_map-block = 2.
        APPEND VALUE #( fnam = ls_item_map-dynfld fval = lv_fval ) TO ls_item_bdc-t_f2.
      ELSE.
        APPEND VALUE #( fnam = ls_item_map-dynfld fval = lv_fval ) TO ls_item_bdc-t_f1.
      ENDIF.

    ENDLOOP.

    " 바뀌는 필드가 없는 명세는 화면 진입 자체를 생략한다.
    CHECK ls_item_bdc-t_f1 IS NOT INITIAL OR ls_item_bdc-t_f2 IS NOT INITIAL.
    APPEND ls_item_bdc TO lt_item_bdc.

  ENDLOOP.

  " 변경 대상이 하나도 없으면 트랜잭션을 타지 않고 정상 종료한다.
  IF lt_hdr_fld IS INITIAL AND lt_item_bdc IS INITIAL.
    ev_messagetype = zif_parked_doc_changer=>gc_msgtype-success.
    ev_messagetext = zif_parked_doc_changer=>gc_text_success.
    RETURN.
  ENDIF.

*----------------------------------------------------------------------*
* 3) BDC 생성 - 초기화면
*----------------------------------------------------------------------*
  APPEND VALUE #( program = lc_prog_init dynpro = lc_dynp_init dynbegin = abap_true ) TO lt_bdc.
  APPEND VALUE #( fnam = 'BDC_CURSOR'   fval = 'RF05V-BELNR' )      TO lt_bdc.
  APPEND VALUE #( fnam = 'BDC_OKCODE'   fval = lc_ok_enter )        TO lt_bdc.
  APPEND VALUE #( fnam = 'RF05V-BUKRS'  fval = is_header-bukrs )    TO lt_bdc.
  APPEND VALUE #( fnam = 'RF05V-BELNR'  fval = is_header-belnr )    TO lt_bdc.
  APPEND VALUE #( fnam = 'RF05V-GJAHR'  fval = is_header-gjahr )    TO lt_bdc.

*----------------------------------------------------------------------*
* 4) BDC 생성 - 개요화면(헤더 변경) + 첫 명세 진입/저장
*----------------------------------------------------------------------*
  CLEAR lv_cursor.
  IF lt_item_bdc IS INITIAL.
    lv_okcode = lc_ok_save.
  ELSE.
    lv_okcode = lc_ok_itemdet.
    lv_cursor = |{ lc_fld_ovwpos }({ lt_item_bdc[ 1 ]-posid WIDTH = 2 PAD = '0' ALIGN = RIGHT })|.
  ENDIF.

  APPEND VALUE #( program = lc_prog_ovw dynpro = lc_dynp_ovw dynbegin = abap_true ) TO lt_bdc.
  APPEND VALUE #( fnam = 'BDC_OKCODE' fval = lv_okcode ) TO lt_bdc.
  IF lv_cursor IS NOT INITIAL.
    APPEND VALUE #( fnam = 'BDC_CURSOR' fval = lv_cursor ) TO lt_bdc.
  ENDIF.
  APPEND LINES OF lt_hdr_fld TO lt_bdc.

*----------------------------------------------------------------------*
* 5) BDC 생성 - 명세별 상세화면 / 추가 데이터 팝업
*----------------------------------------------------------------------*
  LOOP AT lt_item_bdc INTO ls_item_bdc.

    DATA(lv_idx) = sy-tabix.

    " 5-1) 명세 상세화면
    APPEND VALUE #( program = lc_prog_item dynpro = lc_dynp_item dynbegin = abap_true ) TO lt_bdc.
    APPEND VALUE #( fnam = 'BDC_OKCODE'
                    fval = COND #( WHEN ls_item_bdc-t_f2 IS NOT INITIAL
                                   THEN lc_ok_more ELSE lc_ok_back ) ) TO lt_bdc.
    APPEND LINES OF ls_item_bdc-t_f1 TO lt_bdc.

    " 5-2) 추가 데이터 팝업(HZUON, XREF1~3)
    IF ls_item_bdc-t_f2 IS NOT INITIAL.
      APPEND VALUE #( program = lc_prog_more dynpro = lc_dynp_more dynbegin = abap_true ) TO lt_bdc.
      APPEND VALUE #( fnam = 'BDC_OKCODE' fval = lc_ok_enter ) TO lt_bdc.
      APPEND LINES OF ls_item_bdc-t_f2 TO lt_bdc.

      " 팝업 확인 후 다시 명세 상세화면 -> 개요화면 복귀
      APPEND VALUE #( program = lc_prog_item dynpro = lc_dynp_item dynbegin = abap_true ) TO lt_bdc.
      APPEND VALUE #( fnam = 'BDC_OKCODE' fval = lc_ok_back ) TO lt_bdc.
    ENDIF.

    " 5-3) 개요화면 - 다음 명세로 이동하거나 마지막이면 저장
    CLEAR lv_cursor.
    IF lv_idx < lines( lt_item_bdc ).
      lv_okcode = lc_ok_itemdet.
      lv_cursor = |{ lc_fld_ovwpos }({ lt_item_bdc[ lv_idx + 1 ]-posid WIDTH = 2 PAD = '0' ALIGN = RIGHT })|.
    ELSE.
      lv_okcode = lc_ok_save.
    ENDIF.

    APPEND VALUE #( program = lc_prog_ovw dynpro = lc_dynp_ovw dynbegin = abap_true ) TO lt_bdc.
    APPEND VALUE #( fnam = 'BDC_OKCODE' fval = lv_okcode ) TO lt_bdc.
    IF lv_cursor IS NOT INITIAL.
      APPEND VALUE #( fnam = 'BDC_CURSOR' fval = lv_cursor ) TO lt_bdc.
    ENDIF.

  ENDLOOP.

*----------------------------------------------------------------------*
* 6) 실행
*----------------------------------------------------------------------*
  DATA(ls_options) = VALUE ctu_params(
    dismode = COND #( WHEN iv_mode IS NOT INITIAL THEN iv_mode ELSE 'N' )
    updmode = 'S'          " 동기 업데이트 - 호출자 응답 시점에 결과 확정
    defsize = abap_true ). " 화면 크기 고정(배치 실행 시 필드 위치 어긋남 방지)

  CALL TRANSACTION lc_tcode USING lt_bdc
    OPTIONS FROM ls_options
    MESSAGES INTO lt_message.

  DATA(lv_subrc) = sy-subrc.

*----------------------------------------------------------------------*
* 7) 결과 처리
*----------------------------------------------------------------------*
  et_message = lt_message.

  IF lv_subrc = 0
  AND NOT line_exists( lt_message[ msgtyp = 'E' ] )
  AND NOT line_exists( lt_message[ msgtyp = 'A' ] ).
    ev_messagetype = zif_parked_doc_changer=>gc_msgtype-success.
    ev_messagetext = zif_parked_doc_changer=>gc_text_success.
  ELSE.
    ev_messagetype = zif_parked_doc_changer=>gc_msgtype-error.
    ev_messagetext = zif_parked_doc_changer=>gc_text_error.
  ENDIF.

ENDFUNCTION.
