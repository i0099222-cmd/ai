"! 컨트롤 테이블(ztatccfg) 조회 전담 클래스.
"!
"! 앱의 동작 규칙은 전부 여기를 통해 읽는다. behavior pool 이나 화면에서
"! 'FND' 같은 값을 직접 비교하지 않는다. 그렇게 해두면 Phase 2 에서 체크그룹을
"! 추가할 때 코드를 고치지 않고 설정 행만 넣으면 된다.
CLASS zcl_atc_config DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    CLASS-METHODS get
      RETURNING VALUE(ro_config) TYPE REF TO zcl_atc_config.

    "! 체크 ID/메시지 ID 에 해당하는 설정 1행.
    "! 메시지 단위 행이 체크 전체 행보다 우선한다.
    "! 미등록이면 초기값(= 전부 비활성)을 돌려주므로, 설정에 행을 넣어야만 열린다.
    METHODS get_config
      IMPORTING iv_checkid       TYPE char30
                iv_messageid     TYPE char30 OPTIONAL
      RETURNING VALUE(rs_config) TYPE zif_atc_exemption=>ty_config.

    "! 해당 체크에서 이 적용범위를 쓸 수 있는가.
    "! 요건 "패키지/오브젝트 단위로만 등록" 이 판정되는 지점.
    METHODS is_scope_allowed
      IMPORTING iv_checkid        TYPE char30
                iv_messageid      TYPE char30 OPTIONAL
                iv_scopetype      TYPE char3
      RETURNING VALUE(rv_allowed) TYPE abap_boolean.

    "! 앱이 취급하는 활성 체크인지
    METHODS is_check_active
      IMPORTING iv_checkid       TYPE char30
                iv_messageid     TYPE char30 OPTIONAL
      RETURNING VALUE(rv_active) TYPE abap_boolean.

    "! 활성 체크 전체. 조회 뷰와 배치가 대상 범위를 잡을 때 쓴다.
    METHODS get_active_checks
      RETURNING VALUE(rt_config) TYPE zif_atc_exemption=>tt_config.

  PRIVATE SECTION.

    CLASS-DATA go_instance TYPE REF TO zcl_atc_config.

    DATA mt_config TYPE SORTED TABLE OF zif_atc_exemption=>ty_config
                     WITH UNIQUE KEY checkid messageid.
    DATA mv_loaded TYPE abap_boolean.

    METHODS load_buffer.

ENDCLASS.


CLASS zcl_atc_config IMPLEMENTATION.

  METHOD get.
    IF go_instance IS NOT BOUND.
      go_instance = NEW #( ).
    ENDIF.
    ro_config = go_instance.
  ENDMETHOD.


  METHOD load_buffer.

    " 컨트롤 테이블은 행 수가 적고 변경이 드물어 세션 단위로 한 번만 읽는다.
    IF mv_loaded = abap_true.
      RETURN.
    ENDIF.

    SELECT checkid, messageid, checkgroup, activeflg,
           fndactive, objactive, pkgactive,
           maxvalidmon, reasonreq, maxpriority
      FROM ztatccfg
      INTO CORRESPONDING FIELDS OF TABLE @mt_config.

    mv_loaded = abap_true.

  ENDMETHOD.


  METHOD get_config.

    load_buffer( ).

    " 메시지 단위 설정이 있으면 그것이 우선한다.
    rs_config = VALUE #( mt_config[ checkid   = iv_checkid
                                    messageid = iv_messageid ] OPTIONAL ).

    IF rs_config IS INITIAL.
      rs_config = VALUE #( mt_config[ checkid   = iv_checkid
                                      messageid = space ] OPTIONAL ).
    ENDIF.

  ENDMETHOD.


  METHOD is_scope_allowed.

    DATA(ls_config) = get_config( iv_checkid   = iv_checkid
                                  iv_messageid = iv_messageid ).

    " 취급 대상이 아닌 체크는 어떤 범위도 허용하지 않는다.
    IF ls_config-activeflg <> abap_true.
      RETURN.
    ENDIF.

    CASE iv_scopetype.
      WHEN zif_atc_exemption=>scope-fnd.
        rv_allowed = ls_config-fndactive.
      WHEN zif_atc_exemption=>scope-obj.
        rv_allowed = ls_config-objactive.
      WHEN zif_atc_exemption=>scope-pkg.
        rv_allowed = ls_config-pkgactive.
      WHEN OTHERS.
        " 알 수 없는 코드값은 허용하지 않는다.
        rv_allowed = abap_false.
    ENDCASE.

  ENDMETHOD.


  METHOD is_check_active.
    rv_active = get_config( iv_checkid   = iv_checkid
                            iv_messageid = iv_messageid )-activeflg.
  ENDMETHOD.


  METHOD get_active_checks.

    load_buffer( ).

    LOOP AT mt_config INTO DATA(ls_config) WHERE activeflg = abap_true.
      APPEND ls_config TO rt_config.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
