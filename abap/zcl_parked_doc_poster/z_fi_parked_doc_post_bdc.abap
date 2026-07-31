*&---------------------------------------------------------------------*
*& Function Module Z_FI_PARKED_DOC_POST_BDC
*&---------------------------------------------------------------------*
*& SE37에서 아래대로 생성:
*&   Function Group : (신규, 예: Z_FI_POST_PARKED_DOC)
*&   Function Module: Z_FI_PARKED_DOC_POST_BDC
*&
*&   Import  탭 : IS_KEY    TYPE ZIF_PARKED_DOC_POSTER=>TY_KEY
*&   Export  탭 : ES_RESULT TYPE ZIF_PARKED_DOC_POSTER=>TY_RESULT
*&
*&   (TABLES 탭은 쓰지 않음 - IMPORTING/EXPORTING만 사용)
*&
*&   생성 후 이 함수그룹/FM은 반드시 Standard ABAP 언어버전 패키지에
*&   위치해야 하고, CALL TRANSACTION 사용 때문에 SE37 > API State에서
*&   Local API로 Release해야 ABAP Cloud(RAP) 쪽에서 호출 가능하다.
*&
*&   아래 내용은 Source Code(처리 로직) 탭에 그대로 붙여넣으면 됨.
*&---------------------------------------------------------------------*
FUNCTION z_fi_parked_doc_post_bdc.

  " SHDB 녹화(FBV0) 기반 BDC 데이터.
  " 화면1: SAPMF05V 0100  - 회사코드/전표번호/회계연도 입력 후 Enter(=ENTR)
  " 화면2: SAPLF040 0700  - 헤더텍스트 확인 후 전기(=BU)
  " TODO: 세금코드 경고 등 조건부로 추가 화면이 뜨는 케이스는 아직
  " 반영 안 되어 있음 - 해당 케이스 재녹화 후 화면 블록 추가 필요.
  DATA: lt_bdcdata TYPE STANDARD TABLE OF bdcdata WITH DEFAULT KEY,
        lt_message TYPE zif_parked_doc_poster=>tt_message.

  lt_bdcdata = VALUE #(
    ( program = 'SAPMF05V' dynpro = '0100' dynbegin = 'X' )
    ( fnam = 'BDC_CURSOR'  fval = 'RF05V-BELNR' )
    ( fnam = 'BDC_OKCODE'  fval = '=ENTR' )
    ( fnam = 'RF05V-BUKRS' fval = is_key-bukrs )
    ( fnam = 'RF05V-BELNR' fval = is_key-belnr )
    ( fnam = 'RF05V-GJAHR' fval = is_key-gjahr )

    ( program = 'SAPLF040' dynpro = '0700' dynbegin = 'X' )
    ( fnam = 'BDC_CURSOR'  fval = 'BKPF-XBLNR' )
    ( fnam = 'BDC_OKCODE'  fval = '=BU' )
  ).

  " TODO: CATTMODE/DEFSIZE/RACOMMIT 등 추가 옵션이 필요하면 여기에 보완
  DATA(ls_options) = VALUE ctu_params(
    dismode = 'N'     " 화면 표시 없이 실행
    updmode = 'S' ).  " 동기 업데이트 - 호출자 응답 시점에 결과 확정

  CALL TRANSACTION 'FBV0' USING lt_bdcdata
    OPTIONS FROM ls_options
    MESSAGES INTO lt_message.

  es_result = VALUE #(
    bukrs     = is_key-bukrs
    belnr     = is_key-belnr
    gjahr     = is_key-gjahr
    belnr_new = is_key-belnr   " FBV0 확정 전기는 파킹 시 번호를 그대로 유지
    success   = xsdbool( NOT line_exists( lt_message[ msgtyp = 'E' ] )
                      AND NOT line_exists( lt_message[ msgtyp = 'A' ] ) )
    t_message = lt_message ).

ENDFUNCTION.
