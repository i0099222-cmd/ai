"! FBV0(임시전표 확정 전기)를 BDC(CALL TRANSACTION)로 구동하는 공통 클래스.
"! ------------------------------------------------------------------
"! 주의: CALL TRANSACTION은 ABAP Cloud(엄격 문법)에서 금지된 obsolete
"! statement이다. 이 클래스는 반드시 Standard ABAP 언어버전 패키지에
"! 두고, RAP behavior class(Cloud 언어버전)에서 호출할 수 있도록
"! Local API로 Release해야 한다.
"! ------------------------------------------------------------------
CLASS zcl_parked_doc_poster DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_parked_doc_poster.

  PRIVATE SECTION.
    TYPES tt_bdcdata TYPE STANDARD TABLE OF bdcdata WITH DEFAULT KEY.

    "! 임시전표 1건을 FBV0 BDC로 확정 전기한다.
    METHODS post_one
      IMPORTING
        is_key           TYPE zif_parked_doc_poster=>ty_key
      RETURNING
        VALUE(rs_result) TYPE zif_parked_doc_poster=>ty_result.

ENDCLASS.


CLASS zcl_parked_doc_poster IMPLEMENTATION.

  METHOD zif_parked_doc_poster~post_all.

    " FBV0는 BDC로 한 번에 문서 1건만 처리 가능하므로 키 단위로 순차 호출한다.
    LOOP AT it_keys INTO DATA(ls_key).
      APPEND post_one( ls_key ) TO rt_result.
    ENDLOOP.

  ENDMETHOD.


  METHOD post_one.

    " SHDB 녹화(FBV0) 기반 BDC 데이터.
    " 화면1: SAPMF05V 0100  - 회사코드/전표번호/회계연도 입력 후 Enter(=ENTR)
    " 화면2: SAPLF040 0700  - 헤더텍스트 확인 후 전기(=BU)
    " TODO: 세금코드 경고 등 조건부로 추가 화면이 뜨는 케이스는 아직
    " 반영 안 되어 있음 - 해당 케이스 재녹화 후 화면 블록 추가 필요.
    DATA(lt_bdcdata) = VALUE tt_bdcdata(
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
      updmode = 'S' ).  " 동기 업데이트 - 액션 응답 시점에 결과 확정

    DATA lt_message TYPE zif_parked_doc_poster=>tt_message.

    CALL TRANSACTION 'FBV0' USING lt_bdcdata
      OPTIONS FROM ls_options
      MESSAGES INTO lt_message.

    DATA(lv_success) = xsdbool( NOT line_exists( lt_message[ msgtyp = 'E' ] )
                             AND NOT line_exists( lt_message[ msgtyp = 'A' ] ) ).

    rs_result = VALUE #(
      bukrs     = is_key-bukrs
      belnr     = is_key-belnr
      gjahr     = is_key-gjahr
      belnr_new = is_key-belnr   " FBV0 확정 전기는 파킹 시 번호를 그대로 유지
      success   = lv_success
      t_message = lt_message ).

  ENDMETHOD.

ENDCLASS.
