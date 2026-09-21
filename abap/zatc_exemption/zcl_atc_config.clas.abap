"! 컨트롤 테이블(ztatccfg) 조회 전담 클래스.
"!
"! 앱의 동작 규칙은 전부 여기를 통해 읽는다. behavior pool 이나 화면에서
"! 'FND' 같은 값을 직접 비교하지 않는다. 그렇게 해두면 Phase 2 에서 체크 변형을
"! 추가할 때 코드를 고치지 않고 설정 행만 넣으면 된다.
"!
"! 정책의 키는 체크 변형이다. 체크 목록 관리는 표준(체크 변형)에 위임하고,
"! 우리는 변형 단위로만 정책을 얹는다.
CLASS zcl_atc_config DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    CLASS-METHODS get
      RETURNING VALUE(ro_config) TYPE REF TO zcl_atc_config.

    "! 체크 변형에 해당하는 정책 1행.
    "! 미등록이면 초기값(= 전부 비활성)을 돌려주므로, 설정에 행을 넣어야만 열린다.
    METHODS get_config
      IMPORTING iv_checkvariant  TYPE char30
      RETURNING VALUE(rs_config) TYPE zif_atc_exemption=>ty_config.

    "! 이 변형의 결과가 앱 관리 대상인지
    METHODS is_variant_active
      IMPORTING iv_checkvariant  TYPE char30
      RETURNING VALUE(rv_active) TYPE abap_boolean.

    "! 이 변형에서 해당 적용범위를 쓸 수 있는가.
    "! 요건 "패키지/오브젝트 단위로만 등록" 이 판정되는 지점.
    METHODS is_scope_allowed
      IMPORTING iv_checkvariant   TYPE char30
                iv_scopetype      TYPE char4
      RETURNING VALUE(rv_allowed) TYPE abap_boolean.

    "! 활성 변형 전체. 조회 뷰와 배치가 대상 범위를 잡을 때 쓴다.
    METHODS get_active_variants
      RETURNING VALUE(rt_config) TYPE zif_atc_exemption=>tt_config.

  PRIVATE SECTION.

    CLASS-DATA go_instance TYPE REF TO zcl_atc_config.

    DATA mt_config TYPE SORTED TABLE OF zif_atc_exemption=>ty_config
                     WITH UNIQUE KEY checkvariant.
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

    " 변형 단위라 행 수가 한 자릿수다. 세션 단위로 한 번만 읽는다.
    IF mv_loaded = abap_true.
      RETURN.
    ENDIF.

    SELECT checkvariant, checkgroup, activeflg,
           fndactive, objactive, pkgactive,
           maxvalidmon, reasonreq, notiftype, maxpriority, defapprover
      FROM ztatccfg
      INTO CORRESPONDING FIELDS OF TABLE @mt_config.

    mv_loaded = abap_true.

  ENDMETHOD.


  METHOD get_config.

    load_buffer( ).

    rs_config = VALUE #( mt_config[ checkvariant = iv_checkvariant ] OPTIONAL ).

  ENDMETHOD.


  METHOD is_variant_active.
    rv_active = get_config( iv_checkvariant )-activeflg.
  ENDMETHOD.


  METHOD is_scope_allowed.

    DATA(ls_config) = get_config( iv_checkvariant ).

    " 관리 대상이 아닌 변형은 어떤 범위도 허용하지 않는다.
    IF ls_config-activeflg <> abap_true.
      RETURN.
    ENDIF.

    CASE iv_scopetype.
      WHEN zif_atc_exemption=>scope-fnd.
        rv_allowed = ls_config-fndactive.
      WHEN zif_atc_exemption=>scope-obj.
        rv_allowed = ls_config-objactive.
      WHEN zif_atc_exemption=>scope-pckg.
        rv_allowed = ls_config-pkgactive.
      WHEN OTHERS.
        " 알 수 없는 코드값은 허용하지 않는다.
        rv_allowed = abap_false.
    ENDCASE.

  ENDMETHOD.


  METHOD get_active_variants.

    load_buffer( ).

    LOOP AT mt_config INTO DATA(ls_config) WHERE activeflg = abap_true.
      APPEND ls_config TO rt_config.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
