"! SU3(사용자 기본값·파라미터) 래퍼 · Tier 2
"!
"! 패키지 언어 버전 = Standard ABAP (classic). BAPI·미공개 테이블은 이 클래스에서만 쓴다.
"! 이 클래스, zif_cmup_user_api, zcx_cmup_user_api 를
"! API State → Use System-Internally (Contract C1) + Use in Cloud Development 로 release 한다.
CLASS zcl_cmup_user_api DEFINITION PUBLIC FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    INTERFACES zif_cmup_user_api.

    CLASS-METHODS create
      RETURNING VALUE(ro_api) TYPE REF TO zif_cmup_user_api.

  PRIVATE SECTION.
    TYPES:
      tt_param  TYPE STANDARD TABLE OF bapiparam WITH EMPTY KEY,
      tt_return TYPE STANDARD TABLE OF bapiret2 WITH EMPTY KEY.

    "! RETURN 에 E/A/X 가 있으면 첫 메시지로 예외
    METHODS raise_on_error
      IMPORTING it_return TYPE tt_return
      RAISING   zcx_cmup_user_api.

    METHODS to_iso_language
      IMPORTING iv_spras        TYPE spras
      RETURNING VALUE(rv_laiso) TYPE laiso.

    METHODS to_sap_language
      IMPORTING iv_laiso        TYPE zif_cmup_user_api=>ty_value
      RETURNING VALUE(rv_spras) TYPE spras
      RAISING   zcx_cmup_user_api.
ENDCLASS.


CLASS zcl_cmup_user_api IMPLEMENTATION.

  METHOD create.
    ro_api = NEW zcl_cmup_user_api( ).
  ENDMETHOD.


  METHOD zif_cmup_user_api~get_settings.
    DATA: ls_defaults TYPE bapidefaul,
          ls_logon    TYPE bapilogond,
          lt_param    TYPE tt_param,
          lt_return   TYPE tt_return.

    CALL FUNCTION 'BAPI_USER_GET_DETAIL'
      EXPORTING
        username  = iv_user
      IMPORTING
        defaults  = ls_defaults
        logondata = ls_logon
      TABLES
        parameter = lt_param
        return    = lt_return.
    raise_on_error( lt_return ).

    " 기본값 탭 (타임존만 LOGONDATA 에 있다)
    rt_setting = VALUE #(
      ( item_id = zif_cmup_user_api=>c_default-langu  value = to_iso_language( ls_defaults-langu ) )
      ( item_id = zif_cmup_user_api=>c_default-datfm  value = ls_defaults-datfm )
      ( item_id = zif_cmup_user_api=>c_default-dcpfm  value = ls_defaults-dcpfm )
      ( item_id = zif_cmup_user_api=>c_default-timefm value = ls_defaults-timefm )
      ( item_id = zif_cmup_user_api=>c_default-tzone  value = ls_logon-tzone ) ).

    " 파라미터 탭 (USR05)
    LOOP AT lt_param INTO DATA(ls_param).
      INSERT VALUE #( item_id = ls_param-parid value = ls_param-parva ) INTO TABLE rt_setting.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cmup_user_api~change_settings.
    DATA: ls_defaults  TYPE bapidefaul,
          ls_defaultsx TYPE bapidefax,
          ls_logon     TYPE bapilogond,
          ls_logonx    TYPE bapilogonx,
          lt_param     TYPE tt_param,
          ls_paramx    TYPE bapiparax,
          lt_return    TYPE tt_return.

    IF it_setting IS INITIAL.
      RETURN.
    ENDIF.

    " 1) 현재 파라미터 목록
    "    BAPI_USER_CHANGE 는 파라미터 테이블을 통째로 교체한다.
    "    바꿀 것만 넘기면 나머지 파라미터가 전부 지워지므로 기존 목록에 병합해서 넘긴다.
    CALL FUNCTION 'BAPI_USER_GET_DETAIL'
      EXPORTING
        username  = iv_user
      TABLES
        parameter = lt_param
        return    = lt_return.
    raise_on_error( lt_return ).

    " 2) 넘어온 항목만 반영. 기본값은 X 플래그를 찍은 필드만 바뀐다.
    LOOP AT it_setting INTO DATA(ls_setting).
      CASE ls_setting-item_id.
        WHEN zif_cmup_user_api=>c_default-langu.
          ls_defaults-langu  = to_sap_language( ls_setting-value ).
          ls_defaultsx-langu = abap_true.
        WHEN zif_cmup_user_api=>c_default-datfm.
          ls_defaults-datfm  = ls_setting-value.
          ls_defaultsx-datfm = abap_true.
        WHEN zif_cmup_user_api=>c_default-dcpfm.
          ls_defaults-dcpfm  = ls_setting-value.
          ls_defaultsx-dcpfm = abap_true.
        WHEN zif_cmup_user_api=>c_default-timefm.
          ls_defaults-timefm  = ls_setting-value.
          ls_defaultsx-timefm = abap_true.
        WHEN zif_cmup_user_api=>c_default-tzone.
          ls_logon-tzone  = ls_setting-value.
          ls_logonx-tzone = abap_true.

        WHEN OTHERS.   " 파라미터 ID
          ASSIGN lt_param[ parid = ls_setting-item_id ] TO FIELD-SYMBOL(<ls_param>).
          IF sy-subrc = 0.
            IF ls_setting-value IS INITIAL.
              DELETE lt_param WHERE parid = ls_setting-item_id.
            ELSE.
              <ls_param>-parva = ls_setting-value.
            ENDIF.
          ELSEIF ls_setting-value IS NOT INITIAL.
            APPEND VALUE #( parid = ls_setting-item_id parva = ls_setting-value ) TO lt_param.
          ENDIF.
          ls_paramx = VALUE #( parid = abap_true parva = abap_true ).
      ENDCASE.
    ENDLOOP.

    " 3) 변경 (COMMIT 은 RAP 가 한다)
    CLEAR lt_return.
    CALL FUNCTION 'BAPI_USER_CHANGE'
      EXPORTING
        username   = iv_user
        defaults   = ls_defaults
        defaultsx  = ls_defaultsx
        logondata  = ls_logon
        logondatax = ls_logonx
        parameterx = ls_paramx
      TABLES
        parameter  = lt_param
        return     = lt_return.
    raise_on_error( lt_return ).
  ENDMETHOD.


  METHOD raise_on_error.
    LOOP AT it_return INTO DATA(ls_return) WHERE type CA 'EAX'.
      RAISE EXCEPTION TYPE zcx_cmup_user_api
        EXPORTING
          iv_text = CONV #( ls_return-message ).
    ENDLOOP.
  ENDMETHOD.


  METHOD to_iso_language.
    SELECT SINGLE laiso FROM t002 WHERE spras = @iv_spras INTO @rv_laiso.
  ENDMETHOD.


  METHOD to_sap_language.
    DATA(lv_laiso) = CONV laiso( iv_laiso ).
    SELECT SINGLE spras FROM t002 WHERE laiso = @lv_laiso INTO @rv_spras.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cmup_user_api
        EXPORTING
          iv_text = |언어 코드 { iv_laiso } 가 없습니다|.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
