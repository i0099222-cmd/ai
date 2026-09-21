"! 컨트롤 테이블(ztatccfg) 유지보수.
"!
"! SE16 으로 직접 넣어도 되지만, 값이 서로 맞물려 있어 하나만 틀려도 앱이
"! 조용히 멈춘다. 실제로 겪은 것들이다.
"!   - defapprover 가 비면 상신이 막힌다 (표준이 승인자를 필수로 받는다)
"!   - activeflg 가 꺼져 있으면 조회 화면이 빈 채로 뜬다
"!   - objactive/pkgactive 가 둘 다 꺼져 있으면 어떤 범위로도 신청할 수 없다
"! 그래서 넣기 전에 검증한다. 이 클래스를 쓰면 위 셋은 저장 자체가 안 된다.
"!
"! 읽기는 zcl_atc_config 가 한다. 이 클래스는 쓰기 전담이다.
"!
"! 🔴 ztatccfg 는 delivery class C(커스터마이징)다. 이 클래스의 직접 INSERT 는
"!   이송 요청에 기록되지 않는다. DEV -> QAS 이송이 필요하면 유지보수 뷰를
"!   생성해 SM30 으로 넣거나, 테이블 엔트리를 이송에 수동으로 담아야 한다.
"!   운영 시스템에는 이 앱이 필요 없을 가능성이 높으므로(ATC 는 개발 시스템에서
"!   돈다) 대개는 DEV 에서 이 클래스로 넣는 것으로 충분하다.
CLASS zcl_atc_config_setup DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_result,
        success TYPE abap_boolean,
        message TYPE string,
      END OF ty_result.

    "! 체크 변형 1건의 정책을 등록하거나 덮어쓴다.
    "!
    "! 기본값은 Phase 1 요건에 맞춰 두었다.
    "!   - fndactive  = 공란  finding 단위 신청 차단 (요건: 패키지/오브젝트만)
    "!   - objactive  = X
    "!   - pkgactive  = X
    "!   - maxpriority = 2    우선순위 1(가장 심각)은 예외 불가
    "!
    "! @parameter iv_defapprover | 표준 예외의 결재 요청을 받을 사용자.
    "!   실제 결재자는 우리 이력에 sy-uname 으로 남으므로 공용 계정이어도 된다.
    CLASS-METHODS set_variant
      IMPORTING iv_checkvariant  TYPE c
                iv_defapprover   TYPE syuname
                iv_checkgroup    TYPE c              DEFAULT 'NAMING'
                iv_maxvalidmon   TYPE i              DEFAULT 12
                iv_maxpriority   TYPE i              DEFAULT 2
                iv_notiftype     TYPE c              DEFAULT 'REJ'
                iv_reasonreq     TYPE abap_boolean   DEFAULT abap_true
                iv_fndactive     TYPE abap_boolean   DEFAULT abap_false
                iv_objactive     TYPE abap_boolean   DEFAULT abap_true
                iv_pkgactive     TYPE abap_boolean   DEFAULT abap_true
                iv_activeflg     TYPE abap_boolean   DEFAULT abap_true
      RETURNING VALUE(rs_result) TYPE ty_result.

    "! 삭제하지 않고 끈다. 이력을 남기면서 앱 대상에서 빼고 싶을 때 쓴다.
    "! 끄면 그 변형의 finding 이 조회 화면에서 사라지고 신규 신청도 막힌다.
    "! 이미 승인된 예외는 표준 저장소에 있으므로 계속 유효하다.
    CLASS-METHODS deactivate
      IMPORTING iv_checkvariant  TYPE c
      RETURNING VALUE(rs_result) TYPE ty_result.

    CLASS-METHODS delete_variant
      IMPORTING iv_checkvariant  TYPE c
      RETURNING VALUE(rs_result) TYPE ty_result.

    "! 현재 설정 전체. 무엇이 켜져 있는지 확인용.
    CLASS-METHODS list
      RETURNING VALUE(rt_config) TYPE zif_atc_exemption=>tt_config.

  PRIVATE SECTION.

    "! 저장 전 검증. 앱이 조용히 멈추는 조합을 여기서 막는다.
    CLASS-METHODS validate
      IMPORTING iv_checkvariant TYPE c
                iv_defapprover  TYPE syuname
                iv_maxvalidmon  TYPE i
                iv_maxpriority  TYPE i
                iv_notiftype    TYPE c
                iv_fndactive    TYPE abap_boolean
                iv_objactive    TYPE abap_boolean
                iv_pkgactive    TYPE abap_boolean
      RETURNING VALUE(rv_error) TYPE string.

ENDCLASS.


CLASS zcl_atc_config_setup IMPLEMENTATION.

  METHOD validate.

    IF iv_checkvariant IS INITIAL.
      rv_error = |체크 변형이 비어 있습니다.|.
      RETURN.
    ENDIF.

    " 표준이 승인자 1명을 필수로 요구한다. 비면 상신이 메시지 021 로 막힌다.
    IF iv_defapprover IS INITIAL.
      rv_error = |기본 승인자(defapprover)가 필요합니다. | &&
                 |표준 예외는 승인자 없이 만들 수 없습니다.|.
      RETURN.
    ENDIF.

    " TODO 확인 필요: USR02 의 API State. ABAP Cloud 에서 직접 SELECT 가
    "   막히면 이 검사만 빼면 된다. 그 경우 잘못된 사용자 ID 는 상신 시점에
    "   표준이 거부하는 것으로 드러난다.
    SELECT SINGLE @abap_true FROM usr02
      WHERE bname = @iv_defapprover
      INTO @DATA(lv_user_exists).

    IF lv_user_exists <> abap_true.
      rv_error = |사용자 { iv_defapprover } 가 이 시스템에 없습니다.|.
      RETURN.
    ENDIF.

    " 셋 다 꺼져 있으면 어떤 적용범위로도 신청할 수 없다.
    IF iv_fndactive = abap_false
   AND iv_objactive = abap_false
   AND iv_pkgactive = abap_false.
      rv_error = |적용범위를 최소 하나는 열어야 합니다 (FND / OBJ / PCKG).|.
      RETURN.
    ENDIF.

    " 0 이면 validateValidity 가 기간 상한 검사를 건너뛴다. 무제한 예외가 된다.
    IF iv_maxvalidmon <= 0.
      rv_error = |최대 유효 개월(maxvalidmon)은 1 이상이어야 합니다.|.
      RETURN.
    ENDIF.

    IF iv_maxpriority < 0 OR iv_maxpriority > 9.
      rv_error = |maxpriority 는 0~9 범위입니다.|.
      RETURN.
    ENDIF.

    IF iv_notiftype <> zif_atc_exemption=>notification-on_rejection
   AND iv_notiftype <> zif_atc_exemption=>notification-always
   AND iv_notiftype <> zif_atc_exemption=>notification-never.
      rv_error = |알림 유형은 REJ / ALWS / NEVR 중 하나입니다.|.
      RETURN.
    ENDIF.

  ENDMETHOD.


  METHOD set_variant.

    DATA(lv_error) = validate( iv_checkvariant = iv_checkvariant
                               iv_defapprover  = iv_defapprover
                               iv_maxvalidmon  = iv_maxvalidmon
                               iv_maxpriority  = iv_maxpriority
                               iv_notiftype    = iv_notiftype
                               iv_fndactive    = iv_fndactive
                               iv_objactive    = iv_objactive
                               iv_pkgactive    = iv_pkgactive ).

    IF lv_error IS NOT INITIAL.
      rs_result = VALUE #( success = abap_false message = lv_error ).
      RETURN.
    ENDIF.

    " 덮어쓰기다. 같은 변형을 두 번 부르면 나중 값이 남는다.
    MODIFY ztatccfg FROM @( VALUE #(
      checkvariant = iv_checkvariant
      checkgroup   = iv_checkgroup
      activeflg    = iv_activeflg
      fndactive    = iv_fndactive
      objactive    = iv_objactive
      pkgactive    = iv_pkgactive
      maxvalidmon  = iv_maxvalidmon
      reasonreq    = iv_reasonreq
      notiftype    = iv_notiftype
      maxpriority  = iv_maxpriority
      defapprover  = iv_defapprover ) ).

    IF sy-subrc <> 0.
      rs_result = VALUE #( success = abap_false
                           message = |저장 실패 (sy-subrc { sy-subrc }).| ).
      RETURN.
    ENDIF.

    COMMIT WORK.

    rs_result = VALUE #( success = abap_true
                         message = |{ iv_checkvariant } 설정 저장. | &&
                                   |적용범위 { COND string( WHEN iv_objactive = abap_true THEN 'OBJ ' ) }| &&
                                   |{ COND string( WHEN iv_pkgactive = abap_true THEN 'PCKG ' ) }| &&
                                   |{ COND string( WHEN iv_fndactive = abap_true THEN 'FND ' ) }| &&
                                   |/ 최대 { iv_maxvalidmon }개월 / 승인자 { iv_defapprover }| ).

  ENDMETHOD.


  METHOD deactivate.

    UPDATE ztatccfg
      SET activeflg = @abap_false
      WHERE checkvariant = @iv_checkvariant.

    IF sy-subrc <> 0.
      rs_result = VALUE #( success = abap_false
                           message = |{ iv_checkvariant } 설정이 없습니다.| ).
      RETURN.
    ENDIF.

    COMMIT WORK.

    rs_result = VALUE #( success = abap_true
                         message = |{ iv_checkvariant } 비활성화. | &&
                                   |조회 화면에서 이 변형의 finding 이 사라집니다.| ).

  ENDMETHOD.


  METHOD delete_variant.

    " 이미 이 변형으로 신청된 건이 있으면 지우지 않는다. 설정이 사라지면
    " deriveCheckGroup 과 검증들이 기준을 잃고, 기존 신청서의 승인·철회가
    " 막힌다. 그럴 땐 deactivate( ) 를 쓴다.
    SELECT SINGLE @abap_true FROM ztatcexempt
      WHERE checkvariant = @iv_checkvariant
      INTO @DATA(lv_in_use).

    IF lv_in_use = abap_true.
      rs_result = VALUE #( success = abap_false
                           message = |{ iv_checkvariant } 로 신청된 건이 있어 | &&
                                     |삭제할 수 없습니다. deactivate( ) 를 쓰세요.| ).
      RETURN.
    ENDIF.

    DELETE FROM ztatccfg WHERE checkvariant = @iv_checkvariant.

    IF sy-subrc <> 0.
      rs_result = VALUE #( success = abap_false
                           message = |{ iv_checkvariant } 설정이 없습니다.| ).
      RETURN.
    ENDIF.

    COMMIT WORK.

    rs_result = VALUE #( success = abap_true
                         message = |{ iv_checkvariant } 설정 삭제.| ).

  ENDMETHOD.


  METHOD list.

    SELECT checkvariant, checkgroup, activeflg,
           fndactive, objactive, pkgactive,
           maxvalidmon, reasonreq, notiftype, maxpriority, defapprover
      FROM ztatccfg
      ORDER BY checkvariant
      INTO CORRESPONDING FIELDS OF TABLE @rt_config.

  ENDMETHOD.

ENDCLASS.
