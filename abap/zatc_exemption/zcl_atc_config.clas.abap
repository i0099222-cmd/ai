"! 설정 테이블(ztatccheck / ztatcscope) 조회 전담 클래스.
"! 체크 ID, 적용범위 허용 여부, 유효기간 상한 같은 정책값은 전부 여기를 통해
"! 읽는다. behavior pool 이나 화면에서 'FND' 같은 값을 직접 비교하지 않는다.
CLASS zcl_atc_config DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    CLASS-METHODS get
      RETURNING VALUE(ro_config) TYPE REF TO zcl_atc_config.

    "! 체크 ID/메시지 ID 로 체크그룹을 파생한다.
    "! 메시지 ID 로 등록된 행이 우선하고, 없으면 체크 전체 행(messageid 공란)을 쓴다.
    METHODS derive_checkgroup
      IMPORTING iv_checkid         TYPE char30
                iv_messageid       TYPE char30 OPTIONAL
      RETURNING VALUE(rv_checkgroup) TYPE char10.

    "! 앱이 취급하는 활성 체크인지
    METHODS is_check_active
      IMPORTING iv_checkid       TYPE char30
                iv_messageid     TYPE char30 OPTIONAL
      RETURNING VALUE(rv_active) TYPE abap_boolean.

    "! 예외 신청을 허용하는 최대 Priority. 0 이면 제한 없음.
    METHODS get_max_priority
      IMPORTING iv_checkid     TYPE char30
                iv_messageid   TYPE char30 OPTIONAL
      RETURNING VALUE(rv_prio) TYPE int1.

    "! (체크그룹, 적용범위) 조합의 설정. 미등록이면 초기값(=비활성)을 돌려준다.
    METHODS get_scope
      IMPORTING iv_checkgroup   TYPE char10
                iv_scopetype    TYPE char3
      RETURNING VALUE(rs_scope) TYPE zif_atc_exemption=>ty_scopecfg.

    "! 해당 체크그룹에서 현재 사용 가능한 적용범위 목록.
    "! 화면 드롭다운은 이 결과로 동적 생성한다.
    METHODS get_active_scopes
      IMPORTING iv_checkgroup    TYPE char10
      RETURNING VALUE(rt_scope)  TYPE zif_atc_exemption=>tt_scopecfg.

  PRIVATE SECTION.

    CLASS-DATA go_instance TYPE REF TO zcl_atc_config.

    TYPES:
      BEGIN OF ty_check_buf,
        checkid     TYPE char30,
        messageid   TYPE char30,
        checkgroup  TYPE char10,
        activeflg   TYPE abap_boolean,
        maxpriority TYPE int1,
      END OF ty_check_buf.

    DATA mt_check TYPE SORTED TABLE OF ty_check_buf
                    WITH UNIQUE KEY checkid messageid.
    DATA mt_scope TYPE SORTED TABLE OF zif_atc_exemption=>ty_scopecfg
                    WITH UNIQUE KEY checkgroup scopetype.
    DATA mv_loaded TYPE abap_boolean.

    METHODS load_buffer.

    "! 메시지 ID 행 우선, 없으면 체크 전체 행
    METHODS find_check
      IMPORTING iv_checkid      TYPE char30
                iv_messageid    TYPE char30
      RETURNING VALUE(rs_check) TYPE ty_check_buf.

ENDCLASS.


CLASS zcl_atc_config IMPLEMENTATION.

  METHOD get.
    IF go_instance IS NOT BOUND.
      go_instance = NEW #( ).
    ENDIF.
    ro_config = go_instance.
  ENDMETHOD.


  METHOD load_buffer.

    " 설정 테이블은 행 수가 적고 변경이 드물어 세션 단위로 한 번만 읽는다.
    IF mv_loaded = abap_true.
      RETURN.
    ENDIF.

    SELECT checkid, messageid, checkgroup, activeflg, maxpriority
      FROM ztatccheck
      INTO CORRESPONDING FIELDS OF TABLE @mt_check.

    SELECT checkgroup, scopetype, activeflg, apprlevel, maxvalidmon, reasonreq
      FROM ztatcscope
      INTO CORRESPONDING FIELDS OF TABLE @mt_scope.

    mv_loaded = abap_true.

  ENDMETHOD.


  METHOD find_check.

    load_buffer( ).

    " 메시지 단위 설정이 있으면 그것이 우선한다.
    rs_check = VALUE #( mt_check[ checkid   = iv_checkid
                                  messageid = iv_messageid ] OPTIONAL ).

    IF rs_check IS INITIAL.
      rs_check = VALUE #( mt_check[ checkid   = iv_checkid
                                    messageid = space ] OPTIONAL ).
    ENDIF.

  ENDMETHOD.


  METHOD derive_checkgroup.
    rv_checkgroup = find_check( iv_checkid   = iv_checkid
                                iv_messageid = iv_messageid )-checkgroup.
  ENDMETHOD.


  METHOD is_check_active.
    rv_active = find_check( iv_checkid   = iv_checkid
                            iv_messageid = iv_messageid )-activeflg.
  ENDMETHOD.


  METHOD get_max_priority.
    rv_prio = find_check( iv_checkid   = iv_checkid
                          iv_messageid = iv_messageid )-maxpriority.
  ENDMETHOD.


  METHOD get_scope.

    load_buffer( ).

    " 미등록 조합은 "허용하지 않음" 으로 본다. 설정에 행을 추가해야만 열린다.
    rs_scope = VALUE #( mt_scope[ checkgroup = iv_checkgroup
                                  scopetype  = iv_scopetype ] OPTIONAL ).

  ENDMETHOD.


  METHOD get_active_scopes.

    load_buffer( ).

    LOOP AT mt_scope INTO DATA(ls_scope)
         WHERE checkgroup = iv_checkgroup
           AND activeflg  = abap_true.
      APPEND ls_scope TO rt_scope.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
