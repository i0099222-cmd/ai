"! ZR_AtcExemption BO 의 behavior implementation.
"!
"! 이 클래스에는 코드값 리터럴을 두지 않는다. 적용범위 허용 여부, 대상 체크,
"! 유효기간 상한, 승인 레벨은 전부 zcl_atc_config 를 통해 설정 테이블에서 읽는다.
"! ("IF scopetype = 'FND'" 같은 하드코딩은 Phase 2 확장 때 전부 되돌려야 한다)
CLASS zbp_r_atcexemption DEFINITION
  PUBLIC
  ABSTRACT
  FINAL
  FOR BEHAVIOR OF zr_atcexemption.
ENDCLASS.

CLASS zbp_r_atcexemption IMPLEMENTATION.
ENDCLASS.


CLASS lhc_exemption DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    CONSTANTS c_msgclass TYPE symsgid VALUE 'ZATC_EXEMPT'.

    "! 읽기 결과 라인. %tky 에 %is_draft 가 포함되어 있어 이력을 draft/active
    "! 어느 인스턴스에 달아야 하는지가 이 타입으로 전달된다.
    TYPES tt_read TYPE TABLE FOR READ RESULT zr_atcexemption.
    TYPES ty_read TYPE LINE OF tt_read.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR exemption RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR exemption RESULT result.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR exemption RESULT result.

    METHODS setinitialvalues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR exemption~setinitialvalues.

    METHODS derivecheckgroup FOR DETERMINE ON MODIFY
      IMPORTING keys FOR exemption~derivecheckgroup.

    METHODS derivepackage FOR DETERMINE ON MODIFY
      IMPORTING keys FOR exemption~derivepackage.

    METHODS deriveprereg FOR DETERMINE ON SAVE
      IMPORTING keys FOR exemption~deriveprereg.

    METHODS validatescope FOR VALIDATE ON SAVE
      IMPORTING keys FOR exemption~validatescope.

    METHODS validatevariant FOR VALIDATE ON SAVE
      IMPORTING keys FOR exemption~validatevariant.

    METHODS validaterulescope FOR VALIDATE ON SAVE
      IMPORTING keys FOR exemption~validaterulescope.

    METHODS validatevalidity FOR VALIDATE ON SAVE
      IMPORTING keys FOR exemption~validatevalidity.

    METHODS validatereason FOR VALIDATE ON SAVE
      IMPORTING keys FOR exemption~validatereason.

    METHODS validateoverlap FOR VALIDATE ON SAVE
      IMPORTING keys FOR exemption~validateoverlap.

    METHODS submit FOR MODIFY
      IMPORTING keys FOR ACTION exemption~submit RESULT result.

    METHODS withdraw FOR MODIFY
      IMPORTING keys FOR ACTION exemption~withdraw RESULT result.

    METHODS approve FOR MODIFY
      IMPORTING keys FOR ACTION exemption~approve RESULT result.

    METHODS reject FOR MODIFY
      IMPORTING keys FOR ACTION exemption~reject RESULT result.

    METHODS revoke FOR MODIFY
      IMPORTING keys FOR ACTION exemption~revoke RESULT result.

    METHODS extendvalidity FOR MODIFY
      IMPORTING keys FOR ACTION exemption~extendvalidity RESULT result.

    METHODS simulateimpact FOR MODIFY
      IMPORTING keys FOR ACTION exemption~simulateimpact RESULT result.

    METHODS createfromfinding FOR MODIFY
      IMPORTING keys FOR ACTION exemption~createfromfinding RESULT result.

    "! 상태 전이 1건을 이력에 남긴다. 감사 대응의 유일한 근거이므로 모든 액션이 호출한다.
    "! 키를 UUID 가 아니라 읽기 결과 라인으로 받는다. draft 활성 BO 에서는
    "! %tky 에 %is_draft 가 들어 있어야 이력이 올바른 인스턴스에 달린다.
    METHODS write_log
      IMPORTING is_row     TYPE ty_read
                iv_action  TYPE char10
                iv_from    TYPE char2
                iv_to      TYPE char2
                iv_comment TYPE string OPTIONAL.

    "! 현재 사용자가 이 예외를 승인할 수 있는지.
    "! 적용범위에 따라 요구 승인 레벨이 다르다 (PKG 는 더 높은 레벨).
    METHODS is_approver
      IMPORTING is_exemption     TYPE ztatcexempt
      RETURNING VALUE(rv_can)    TYPE abap_boolean.

    METHODS new_error
      IMPORTING iv_number        TYPE symsgno
                iv_v1            TYPE any OPTIONAL
                iv_v2            TYPE any OPTIONAL
      RETURNING VALUE(ro_msg)    TYPE REF TO if_abap_behv_message.

ENDCLASS.


CLASS lhc_exemption IMPLEMENTATION.

  METHOD get_instance_features.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption)
      FAILED failed.

    LOOP AT lt_exemption INTO DATA(ls_exemption).

      DATA(lv_is_requester) = xsdbool( ls_exemption-requester = sy-uname ).
      DATA(lv_is_approver)  = is_approver( CORRESPONDING #( ls_exemption ) ).

      " 버튼 활성화 규칙. 같은 화면에서 신청자와 승인자를 구분하는 지점이다.
      "   신청자 : 본인 초안에서만 Submit/Delete, 승인대기에서 Withdraw
      "   승인자 : 승인대기에서만 Approve/Reject, 승인 건에서 Revoke
      "   자기승인은 금지한다.
      APPEND VALUE #(
        %tky                        = ls_exemption-%tky

        %action-submit              = COND #(
          WHEN ls_exemption-exemptstatus = zif_atc_exemption=>status-draft
           AND lv_is_requester = abap_true
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )

        %action-withdraw            = COND #(
          WHEN ls_exemption-exemptstatus = zif_atc_exemption=>status-pending
           AND lv_is_requester = abap_true
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )

        %action-approve             = COND #(
          WHEN ls_exemption-exemptstatus = zif_atc_exemption=>status-pending
           AND lv_is_approver = abap_true
           AND lv_is_requester = abap_false
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )

        %action-reject              = COND #(
          WHEN ls_exemption-exemptstatus = zif_atc_exemption=>status-pending
           AND lv_is_approver = abap_true
           AND lv_is_requester = abap_false
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )

        %action-revoke              = COND #(
          WHEN ls_exemption-exemptstatus = zif_atc_exemption=>status-approved
           AND lv_is_approver = abap_true
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )

        %action-extendvalidity      = COND #(
          WHEN ls_exemption-exemptstatus = zif_atc_exemption=>status-approved
           AND lv_is_requester = abap_true
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )

        " 영향도는 누구나 확인할 수 있어야 승인 판단에 쓸 수 있다.
        %action-simulateimpact      = if_abap_behv=>fc-o-enabled

        " 삭제는 초안만. 승인/반려 건을 지우면 감사 근거가 사라진다.
        %delete                     = COND #(
          WHEN ls_exemption-exemptstatus = zif_atc_exemption=>status-draft
           AND lv_is_requester = abap_true
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )

        " 초안 상태에서만 편집할 수 있다.
        %assoc-_Item                = COND #(
          WHEN ls_exemption-exemptstatus = zif_atc_exemption=>status-draft
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )

      ) TO result.

    ENDLOOP.

  ENDMETHOD.


  METHOD get_instance_authorizations.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption)
      FAILED failed.

    LOOP AT lt_exemption INTO DATA(ls_exemption).

      " 권한 오브젝트는 체크그룹 + 패키지 + 적용범위 + 액티비티 4개 필드다.
      " Phase 1 에서 값이 비어 있어도 필드는 지금 만들어 둔다. 나중에 필드를
      " 추가하면 PFCG 역할을 전수 재작업해야 한다.
      AUTHORITY-CHECK OBJECT zif_atc_exemption=>authobject-name
        ID 'CHECKGRP'  FIELD ls_exemption-checkgroup
        ID 'DEVCLASS'  FIELD ls_exemption-devclass
        ID 'SCOPETYPE' FIELD ls_exemption-scopetype
        ID 'ACTVT'     FIELD zif_atc_exemption=>authobject-actvt_chng.

      DATA(lv_update) = COND #( WHEN sy-subrc = 0
                                THEN if_abap_behv=>auth-allowed
                                ELSE if_abap_behv=>auth-unauthorized ).

      DATA(lv_approve) = COND #( WHEN is_approver( CORRESPONDING #( ls_exemption ) ) = abap_true
                                 THEN if_abap_behv=>auth-allowed
                                 ELSE if_abap_behv=>auth-unauthorized ).

      APPEND VALUE #( %tky             = ls_exemption-%tky
                      %update          = lv_update
                      %delete          = lv_update
                      %action-approve  = lv_approve
                      %action-reject   = lv_approve
                      %action-revoke   = lv_approve ) TO result.

    ENDLOOP.

  ENDMETHOD.


  METHOD get_global_authorizations.

    " 생성 권한은 인스턴스가 없으므로 전역에서 판정한다.
    " 패키지/체크그룹은 이 시점에 모르니 더미로 넘기고, 실제 범위 제한은
    " get_instance_authorizations 와 validation 이 담당한다.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.

      AUTHORITY-CHECK OBJECT zif_atc_exemption=>authobject-name
        ID 'CHECKGRP'  DUMMY
        ID 'DEVCLASS'  DUMMY
        ID 'SCOPETYPE' DUMMY
        ID 'ACTVT'     FIELD zif_atc_exemption=>authobject-actvt_crea.

      result-%create = COND #( WHEN sy-subrc = 0
                               THEN if_abap_behv=>auth-allowed
                               ELSE if_abap_behv=>auth-unauthorized ).

    ENDIF.

  ENDMETHOD.


  METHOD is_approver.

    " 승인 권한은 권한 오브젝트 하나로 판정한다. SCOPETYPE 필드가 있으므로
    " "누가 어느 범위를 승인할 수 있는지" 는 PFCG 역할에서 표현된다.
    "   팀리더   : SCOPETYPE = OBJ
    "   아키텍트 : SCOPETYPE = OBJ, PKG
    "   보안담당 : CHECKGRP = SECURITY
    " 컨트롤 테이블에 승인 레벨을 따로 두면 같은 것을 두 군데서 관리하게 된다.
    AUTHORITY-CHECK OBJECT zif_atc_exemption=>authobject-name
      ID 'CHECKGRP'  FIELD is_exemption-checkgroup
      ID 'DEVCLASS'  FIELD is_exemption-devclass
      ID 'SCOPETYPE' FIELD is_exemption-scopetype
      ID 'ACTVT'     FIELD zif_atc_exemption=>authobject-actvt_appr.

    rv_can = xsdbool( sy-subrc = 0 ).

  ENDMETHOD.


  METHOD setinitialvalues.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        FIELDS ( validfrom rulescope )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption).

    DATA lt_update TYPE TABLE FOR UPDATE zr_atcexemption.

    LOOP AT lt_exemption INTO DATA(ls_exemption).

      APPEND VALUE #( %tky         = ls_exemption-%tky
                      exemptstatus = zif_atc_exemption=>status-draft
                      requester    = sy-uname
                      validfrom    = COND #( WHEN ls_exemption-validfrom IS INITIAL
                                             THEN sy-datum ELSE ls_exemption-validfrom )
                      rulescope    = COND #( WHEN ls_exemption-rulescope IS INITIAL
                                             THEN zif_atc_exemption=>rulescope-message
                                             ELSE ls_exemption-rulescope ) )
             TO lt_update.

      write_log( is_row    = ls_exemption
                 iv_action = zif_atc_exemption=>logaction-create
                 iv_from   = space
                 iv_to     = zif_atc_exemption=>status-draft ).

    ENDLOOP.

    MODIFY ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        UPDATE FIELDS ( exemptstatus requester validfrom rulescope )
        WITH lt_update
      REPORTED DATA(lt_reported).

    " 이미 담긴 메시지를 덮지 않도록 덧붙인다.
    APPEND LINES OF lt_reported-exemption TO reported-exemption.

  ENDMETHOD.


  METHOD derivecheckgroup.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        FIELDS ( checkvariant )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption).

    DATA lt_update TYPE TABLE FOR UPDATE zr_atcexemption.

    LOOP AT lt_exemption INTO DATA(ls_exemption).

      " 체크그룹은 사용자가 고르는 값이 아니라 변형 정책에서 파생된다.
      APPEND VALUE #( %tky       = ls_exemption-%tky
                      checkgroup = zcl_atc_config=>get( )->get_config(
                                     ls_exemption-checkvariant )-checkgroup )
             TO lt_update.

    ENDLOOP.

    MODIFY ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        UPDATE FIELDS ( checkgroup )
        WITH lt_update.

  ENDMETHOD.


  METHOD derivepackage.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        FIELDS ( objecttype objectname devclass )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption).

    DATA lt_update TYPE TABLE FOR UPDATE zr_atcexemption.

    LOOP AT lt_exemption INTO DATA(ls_exemption)
         WHERE objecttype IS NOT INITIAL
           AND objectname IS NOT INITIAL.

      " 오브젝트를 지정하면 패키지는 TADIR 에서 파생한다. 손으로 넣게 두면
      " 오브젝트와 패키지가 어긋난 예외가 생긴다.
      SELECT SINGLE devclass
        FROM tadir
        WHERE pgmid    = 'R3TR'
          AND object   = @ls_exemption-objecttype
          AND obj_name = @ls_exemption-objectname
        INTO @DATA(lv_devclass).

      IF sy-subrc = 0 AND lv_devclass <> ls_exemption-devclass.
        APPEND VALUE #( %tky     = ls_exemption-%tky
                        devclass = lv_devclass ) TO lt_update.
      ENDIF.

    ENDLOOP.

    MODIFY ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        UPDATE FIELDS ( devclass )
        WITH lt_update.

  ENDMETHOD.


  METHOD deriveprereg.

    " 선등록(pre-registration) = finding 없이 등록된 예외.
    "
    " 패키지 스코프는 본래 앞을 보는 등록이다. "앞으로 이 패키지에 만들 것은
    " 네이밍 체크를 건너뛴다" 는 신청에는 아직 위반이 없다. 반대로 finding 에서
    " 만든 신청은 실재하는 위반을 증빙으로 달고 온다. 감사 관점에서 이 둘은
    " 전혀 다른 건이라 구분해 둬야 한다.
    "
    " 플래그를 사용자나 액션이 직접 넣게 하면 두 경로가 늘 때마다 빠뜨릴 수
    " 있다. 증빙 아이템 유무라는 사실에서 판정하면 경로가 몇 개든 맞는다.
    " 아이템이 다 붙은 뒤여야 하므로 on save 다.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption BY \_Item
        FIELDS ( itemno )
        WITH CORRESPONDING #( keys )
      LINK DATA(lt_link).

    DATA lt_update TYPE TABLE FOR UPDATE zr_atcexemption.

    LOOP AT keys INTO DATA(ls_key).

      DATA(lv_hasitem) = abap_false.

      LOOP AT lt_link INTO DATA(ls_link).
        IF ls_link-source-%tky = ls_key-%tky.
          lv_hasitem = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.

      APPEND VALUE #( %tky       = ls_key-%tky
                      preregflag = xsdbool( lv_hasitem = abap_false ) ) TO lt_update.

    ENDLOOP.

    MODIFY ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        UPDATE FIELDS ( preregflag )
        WITH lt_update.

  ENDMETHOD.


  METHOD validatescope.

    " 적용범위 관련 검증을 한 곳에 모았다. 셋 다 같은 필드에 걸려 있어
    " 나눠 두면 같은 인스턴스를 세 번 읽게 되고 얻는 게 없다.
    "   1) 이 변형에서 그 범위를 쓸 수 있는가        -> 요건 "패키지/오브젝트 단위로만"
    "   2) 범위에 맞는 필드가 채워졌는가
    "   3) 대상이 실재하고 고객 네임스페이스인가
    " 앞 단계가 실패하면 뒤는 보지 않는다. 범위가 틀렸는데 필드 조합을
    " 따지는 메시지까지 같이 나오면 사용자가 무엇을 고쳐야 할지 흐려진다.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        FIELDS ( checkvariant scopetype devclass objecttype objectname )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption).

    LOOP AT lt_exemption INTO DATA(ls_exemption).

      " --- 1) 범위 허용 여부 ---
      " 값을 코드로 비교하지 않고 컨트롤 테이블을 조회한다. Phase 1 네이밍 변형은
      " fndactive 가 공란이라 FND 가 거부되고, Phase 2 에서 설정 행만 바꾸면 열린다.
      IF zcl_atc_config=>get( )->is_scope_allowed(
           iv_checkvariant = ls_exemption-checkvariant
           iv_scopetype    = ls_exemption-scopetype ) = abap_false.

        APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky               = ls_exemption-%tky
                        %state_area        = 'VALIDATE_SCOPE'
                        %element-scopetype = if_abap_behv=>mk-on
                        %msg = new_error( iv_number = '001'
                                          iv_v1     = ls_exemption-scopetype
                                          iv_v2     = ls_exemption-checkvariant ) )
               TO reported-exemption.
        CONTINUE.

      ENDIF.

      " --- 2) 범위별 필수 필드 ---
      DATA lv_error TYPE symsgno.
      CLEAR lv_error.

      CASE ls_exemption-scopetype.

        WHEN zif_atc_exemption=>scope-pckg.
          " 패키지 스코프도 출발점 오브젝트가 필요하다.
          " 표준 create_exemption 이 오브젝트를 필수로 받고, 그 뒤에
          " set_object_scope( ) 로 패키지까지 넓히는 순서이기 때문이다.
          " 효력은 패키지 전체이고, 이 오브젝트는 어디서 시작했는지의 기록이다.
          IF ls_exemption-devclass IS INITIAL.
            lv_error = '002'.
          ELSEIF ls_exemption-objecttype IS INITIAL
              OR ls_exemption-objectname IS INITIAL.
            lv_error = '003'.
          ENDIF.

        WHEN zif_atc_exemption=>scope-obj.
          IF ls_exemption-objecttype IS INITIAL
          OR ls_exemption-objectname IS INITIAL.
            lv_error = '004'.
          ENDIF.

        WHEN zif_atc_exemption=>scope-fnd.
          " Phase 2 대비. 대상 finding 은 아이템 1건이고 식별자(checksum)도 거기 있다.
          " 헤더에는 어느 오브젝트의 건인지만 있으면 된다.
          IF ls_exemption-objecttype IS INITIAL
          OR ls_exemption-objectname IS INITIAL.
            lv_error = '005'.
          ENDIF.

      ENDCASE.

      IF lv_error IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky               = ls_exemption-%tky
                        %state_area        = 'VALIDATE_SCOPE'
                        %element-scopetype = if_abap_behv=>mk-on
                        %msg = new_error( iv_number = lv_error
                                          iv_v1     = ls_exemption-scopetype ) )
               TO reported-exemption.
        CONTINUE.
      ENDIF.

      " --- 3) 대상 실재 여부 ---
      " 고객 네임스페이스만 허용한다. 표준 패키지/오브젝트에 예외를 거는 것은
      " 이 앱의 목적이 아니다.
      IF ls_exemption-devclass IS NOT INITIAL
     AND ls_exemption-devclass(1) <> 'Z'
     AND ls_exemption-devclass(1) <> 'Y'
     AND ls_exemption-devclass(1) <> '/'.
        APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky              = ls_exemption-%tky
                        %state_area       = 'VALIDATE_SCOPE'
                        %element-devclass = if_abap_behv=>mk-on
                        %msg = new_error( iv_number = '006'
                                          iv_v1     = ls_exemption-devclass ) )
               TO reported-exemption.
        CONTINUE.
      ENDIF.

      IF ls_exemption-devclass IS NOT INITIAL.
        SELECT SINGLE @abap_true FROM tdevc
          WHERE devclass = @ls_exemption-devclass
          INTO @DATA(lv_pkg_exists).
        IF lv_pkg_exists <> abap_true.
          APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
          APPEND VALUE #( %tky              = ls_exemption-%tky
                          %state_area       = 'VALIDATE_SCOPE'
                          %element-devclass = if_abap_behv=>mk-on
                          %msg = new_error( iv_number = '007'
                                            iv_v1     = ls_exemption-devclass ) )
                 TO reported-exemption.
          CONTINUE.
        ENDIF.
      ENDIF.

      IF ls_exemption-objectname IS NOT INITIAL.
        SELECT SINGLE @abap_true FROM tadir
          WHERE pgmid    = 'R3TR'
            AND object   = @ls_exemption-objecttype
            AND obj_name = @ls_exemption-objectname
          INTO @DATA(lv_obj_exists).
        IF lv_obj_exists <> abap_true.
          APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
          APPEND VALUE #( %tky                = ls_exemption-%tky
                          %state_area         = 'VALIDATE_SCOPE'
                          %element-objectname = if_abap_behv=>mk-on
                          %msg = new_error( iv_number = '008'
                                            iv_v1     = ls_exemption-objectname ) )
                 TO reported-exemption.
        ENDIF.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD validatevariant.

    " 변형 관련 검증 두 가지를 한 곳에 모았다. 트리거가 CheckVariant 로 같아
    " 나눠 둘 이유가 없었다.
    "   1) 이 변형이 앱의 관리 대상인가      -> 요건 "네이밍 건만"
    "   2) 증빙 finding 의 Priority 가 허용 범위인가

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        FIELDS ( checkvariant )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption)
      ENTITY exemption BY \_Item
        FIELDS ( priority )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    LOOP AT lt_exemption INTO DATA(ls_exemption).

      DATA(ls_config) = zcl_atc_config=>get( )->get_config( ls_exemption-checkvariant ).

      " --- 1) 관리 대상 변형인가 ---
      " Phase 1 은 네이밍 변형만 활성이므로 요건 "네이밍 건만" 이 코드 수정 없이 지켜진다.
      IF ls_config-activeflg <> abap_true.
        APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky                  = ls_exemption-%tky
                        %state_area           = 'VALIDATE_VARIANT'
                        %element-checkvariant = if_abap_behv=>mk-on
                        %msg = new_error( iv_number = '009'
                                          iv_v1     = ls_exemption-checkvariant ) )
               TO reported-exemption.
        CONTINUE.
      ENDIF.

      " --- 2) Priority 상한 ---
      " 심각도가 높은 위반은 예외로 덮지 못하게 막는다.
      " Priority 는 1 이 가장 심각하므로, 허용 상한보다 작은 값이면 거부한다.
      IF ls_config-maxpriority <= 0.
        CONTINUE.
      ENDIF.

      LOOP AT lt_item INTO DATA(ls_item)
           WHERE exemptuuid = ls_exemption-exemptuuid
             AND priority   > 0
             AND priority   < ls_config-maxpriority.

        APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky        = ls_exemption-%tky
                        %state_area = 'VALIDATE_VARIANT'
                        %msg = new_error( iv_number = '018'
                                          iv_v1     = ls_item-priority
                                          iv_v2     = ls_config-maxpriority ) )
               TO reported-exemption.
        EXIT.

      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.


  METHOD validaterulescope.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        FIELDS ( rulescope )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption).

    LOOP AT lt_exemption INTO DATA(ls_exemption).

      " 표준 set_check_scope 는 FND / MSG / CHK / ALL 을 받지만, 이 앱은
      " MSG 와 CHK 만 허용한다.
      "   ALL 은 대상 오브젝트/패키지의 ATC 체크를 통째로 끈다. 네이밍 예외를
      "     신청했는데 성능·보안 체크까지 같이 면제되는 셈이라 요건을 정면으로 깬다.
      "     패키지 스코프와 겹치면 그 패키지의 모든 검증이 사라진다.
      "   FND 는 건 단위이므로 적용범위(ScopeType)에서 이미 다루고 있다.
      IF ls_exemption-rulescope = zif_atc_exemption=>rulescope-message
      OR ls_exemption-rulescope = zif_atc_exemption=>rulescope-check.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
      APPEND VALUE #( %tky               = ls_exemption-%tky
                      %state_area        = 'VALIDATE_RULESCOPE'
                      %element-rulescope = if_abap_behv=>mk-on
                      %msg = new_error( iv_number = '019'
                                        iv_v1     = ls_exemption-rulescope ) )
             TO reported-exemption.

    ENDLOOP.

  ENDMETHOD.


  METHOD validatevalidity.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        FIELDS ( checkvariant validfrom validto )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption).

    LOOP AT lt_exemption INTO DATA(ls_exemption).

      " 유효기간은 필수다. 무기한 예외는 사실상 규칙 해제이고, 시간이 지나면
      " 아무도 그 예외가 왜 있는지 모르게 된다.
      IF ls_exemption-validto IS INITIAL
      OR ls_exemption-validto <= ls_exemption-validfrom.
        APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky             = ls_exemption-%tky
                        %state_area      = 'VALIDATE_VALIDITY'
                        %element-validto = if_abap_behv=>mk-on
                        %msg = new_error( iv_number = '010' ) )
               TO reported-exemption.
        CONTINUE.
      ENDIF.

      " 상한은 컨트롤 테이블의 체크별 설정값이다. 보안 체크는 3개월, 네이밍은
      " 12개월처럼 다르게 둘 수 있다. 0 이면 제한 없음.
      DATA(ls_config) = zcl_atc_config=>get( )->get_config( ls_exemption-checkvariant ).

      IF ls_config-maxvalidmon <= 0.
        CONTINUE.
      ENDIF.

      " 개월 상한을 일수로 환산한다. 월말 경계까지 엄격히 볼 필요는 없어
      " 30일 근사로 충분하다.
      DATA(lv_max_date) = CONV d( ls_exemption-validfrom ).
      lv_max_date = lv_max_date + ( ls_config-maxvalidmon * 30 ).

      IF ls_exemption-validto > lv_max_date.
        APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky             = ls_exemption-%tky
                        %state_area      = 'VALIDATE_VALIDITY'
                        %element-validto = if_abap_behv=>mk-on
                        %msg = new_error( iv_number = '011'
                                          iv_v1     = ls_config-maxvalidmon ) )
               TO reported-exemption.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD validatereason.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        FIELDS ( checkvariant reasoncode reasontext )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption).

    LOOP AT lt_exemption INTO DATA(ls_exemption).

      IF zcl_atc_config=>get( )->get_config(
           ls_exemption-checkvariant )-reasonreq <> abap_true.
        CONTINUE.
      ENDIF.

      " 근거 텍스트는 감사 대응 시 남는 유일한 서술이다. 한 단어짜리 형식적
      " 사유를 막기 위해 최소 길이를 본다.
      IF ls_exemption-reasoncode IS NOT INITIAL
     AND strlen( ls_exemption-reasontext ) >= zif_atc_exemption=>min_reason_length.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
      APPEND VALUE #( %tky                = ls_exemption-%tky
                      %state_area         = 'VALIDATE_REASON'
                      %element-reasontext = if_abap_behv=>mk-on
                      %msg = new_error( iv_number = '012'
                                        iv_v1     = zif_atc_exemption=>min_reason_length ) )
             TO reported-exemption.

    ENDLOOP.

  ENDMETHOD.


  METHOD validateoverlap.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption).

    LOOP AT lt_exemption INTO DATA(ls_exemption).

      " 같은 범위·같은 규칙의 유효한 예외가 이미 있으면 중복이다.
      " 중복을 허용하면 어느 예외가 실제로 덮고 있는지 추적할 수 없게 된다.
      SELECT SINGLE @abap_true
        FROM ztatcexempt
        WHERE exemptuuid <> @ls_exemption-exemptuuid
          AND scopetype   = @ls_exemption-scopetype
          AND devclass    = @ls_exemption-devclass
          AND objecttype  = @ls_exemption-objecttype
          AND objectname  = @ls_exemption-objectname
          AND checkclass     = @ls_exemption-checkclass
          AND checkcode   = @ls_exemption-checkcode
          AND exemptstat IN ( @zif_atc_exemption=>status-pending,
                              @zif_atc_exemption=>status-approved )
          AND validto    >= @ls_exemption-validfrom
          AND validfrom  <= @ls_exemption-validto
        INTO @DATA(lv_duplicate).

      IF lv_duplicate <> abap_true.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
      APPEND VALUE #( %tky        = ls_exemption-%tky
                      %state_area = 'VALIDATE_OVERLAP'
                      " 중복 건은 WHERE 조건상 범위와 체크가 이 건과 같다.
                      " 그래서 상대를 조회하지 않고 이 건의 값으로 메시지를 만든다.
                      %msg = new_error( iv_number = '013'
                                        " devclass(CHAR30) 와 objectname(CHAR40) 은
                                        " 길이가 달라 COND 의 공통 타입에서 잘린다.
                                        " 문자열로 만들어 넘긴다.
                                        iv_v1     = COND string(
                                          WHEN ls_exemption-scopetype = zif_atc_exemption=>scope-pckg
                                          THEN |{ ls_exemption-devclass }|
                                          ELSE |{ ls_exemption-objectname }| )
                                        iv_v2     = ls_exemption-checkclass ) )
             TO reported-exemption.

    ENDLOOP.

  ENDMETHOD.


  METHOD submit.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption).

    DATA lt_update TYPE TABLE FOR UPDATE zr_atcexemption.

    DATA(lo_reader) = NEW zcl_atc_finding_reader( ).


    LOOP AT lt_exemption INTO DATA(ls_exemption).

      " 상태가 맞지 않으면 조용히 건너뛰지 않고 거부한다. 그냥 넘기면 액션이
      " 성공한 것처럼 끝나서 사용자는 왜 아무 일도 없었는지 알 수 없다.
      IF ls_exemption-exemptstatus <> zif_atc_exemption=>status-draft.
        APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky = ls_exemption-%tky
                        %msg = new_error( iv_number = '020'
                                          iv_v1     = ls_exemption-exemptstatus ) )
               TO reported-exemption.
        CONTINUE.
      ENDIF.

      " 승인은 표준 Fiori 앱에서도 이뤄질 수 있고, 거기에는 영향도 화면이 없다.
      " 그래서 상신 시점에 영향 건수를 계산해 근거 텍스트에 붙여 둔다.
      " 어느 화면에서 결재하든 승인자가 파급 효과를 읽을 수 있게 하는 장치다.
      DATA(lt_impact) = lo_reader->simulate_impact(
                          iv_checkvariant = ls_exemption-checkvariant
                          iv_scopetype  = ls_exemption-scopetype
                          iv_devclass   = ls_exemption-devclass
                          iv_inclsubpkg = ls_exemption-inclsubpkg
                          iv_objecttype = ls_exemption-objecttype
                          iv_objectname = ls_exemption-objectname
                          " 체크까지 좁히지 않으면 다른 체크의 위반까지 세어
                          " 승인자에게 부풀려진 영향도를 보이게 된다.
                          iv_checkclass = ls_exemption-checkclass
                          iv_checkcode  = COND #( WHEN ls_exemption-rulescope =
                                                       zif_atc_exemption=>rulescope-check
                                                  THEN space
                                                  ELSE ls_exemption-checkcode ) ).

      DATA(lv_reason) = ls_exemption-reasontext.
      lv_reason = |{ lv_reason }\n---\n| &&
                  |[자동] 적용범위: { ls_exemption-scopetype } { ls_exemption-devclass } | &&
                  |{ ls_exemption-objecttype } { ls_exemption-objectname }\n| &&
                  |[자동] 신청 시점 면제 대상: { lines( lt_impact ) }건\n|.

      IF ls_exemption-scopetype = zif_atc_exemption=>scope-pckg.
        lv_reason = |{ lv_reason }[자동] 주의: 이 패키지에 향후 생성되는 | &&
                    |오브젝트도 자동 면제됩니다.\n|.
      ENDIF.

      APPEND VALUE #( %tky               = ls_exemption-%tky
                      exemptstatus       = zif_atc_exemption=>status-pending
                      reasontext         = lv_reason ) TO lt_update.

      write_log( is_row     = ls_exemption
                 iv_action  = zif_atc_exemption=>logaction-submit
                 iv_from    = ls_exemption-exemptstatus
                 iv_to      = zif_atc_exemption=>status-pending
                 iv_comment = |면제 대상 { lines( lt_impact ) }건| ).

    ENDLOOP.

    MODIFY ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        UPDATE FIELDS ( exemptstatus reasontext )
        WITH lt_update.

    " 실패한 건은 result 에 넣지 않는다. keys 로 다시 읽으면 거부된 건까지
    " 성공한 것처럼 돌려주게 된다.
    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( lt_update )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_res IN lt_result
                      ( %tky = ls_res-%tky %param = CORRESPONDING #( ls_res ) ) ).

  ENDMETHOD.


  METHOD withdraw.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption).

    DATA lt_update TYPE TABLE FOR UPDATE zr_atcexemption.


    LOOP AT lt_exemption INTO DATA(ls_exemption).

      " 상태가 맞지 않으면 조용히 건너뛰지 않고 거부한다. 그냥 넘기면 액션이
      " 성공한 것처럼 끝나서 사용자는 왜 아무 일도 없었는지 알 수 없다.
      IF ls_exemption-exemptstatus <> zif_atc_exemption=>status-pending.
        APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky = ls_exemption-%tky
                        %msg = new_error( iv_number = '020'
                                          iv_v1     = ls_exemption-exemptstatus ) )
               TO reported-exemption.
        CONTINUE.
      ENDIF.

      " 철회는 상신 취소다. 레코드는 남고 상태만 초안으로 돌아간다.
      " 삭제와 구분된다 - 삭제는 이력까지 사라지므로 초안에서만 허용한다.
      APPEND VALUE #( %tky               = ls_exemption-%tky
                      exemptstatus       = zif_atc_exemption=>status-draft ) TO lt_update.

      write_log( is_row    = ls_exemption
                 iv_action = zif_atc_exemption=>logaction-withdraw
                 iv_from   = ls_exemption-exemptstatus
                 iv_to     = zif_atc_exemption=>status-draft ).

    ENDLOOP.

    MODIFY ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        UPDATE FIELDS ( exemptstatus )
        WITH lt_update.

    " 실패한 건은 result 에 넣지 않는다. keys 로 다시 읽으면 거부된 건까지
    " 성공한 것처럼 돌려주게 된다.
    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( lt_update )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_res IN lt_result
                      ( %tky = ls_res-%tky %param = CORRESPONDING #( ls_res ) ) ).

  ENDMETHOD.


  METHOD approve.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption).

    DATA lt_update TYPE TABLE FOR UPDATE zr_atcexemption.

    GET TIME STAMP FIELD DATA(lv_now).

    LOOP AT lt_exemption INTO DATA(ls_exemption).

      " 상태가 맞지 않으면 조용히 건너뛰지 않고 거부한다. 그냥 넘기면 액션이
      " 성공한 것처럼 끝나서 사용자는 왜 아무 일도 없었는지 알 수 없다.
      IF ls_exemption-exemptstatus <> zif_atc_exemption=>status-pending.
        APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky = ls_exemption-%tky
                        %msg = new_error( iv_number = '020'
                                          iv_v1     = ls_exemption-exemptstatus ) )
               TO reported-exemption.
        CONTINUE.
      ENDIF.

      " 자기승인 금지. features 에서도 막지만, OData 를 직접 호출하는 경로가
      " 있으므로 액션에서 한 번 더 본다.
      IF ls_exemption-requester = sy-uname.
        APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky = ls_exemption-%tky
                        %msg = new_error( iv_number = '014' ) ) TO reported-exemption.
        CONTINUE.
      ENDIF.

      " 여기서는 CBO 대장의 결재만 기록한다.
      " 표준 예외 생성은 저장 시퀀스(saver 의 save_modified)에서 한다. 액션에서
      " 부르면 DB 를 바꾸고 잠금을 잡는 호출이 저장 전에 일어나므로, 사용자가
      " 초안을 버리거나 저장이 실패하면 CBO 기록 없는 표준 예외만 남는다.
      APPEND VALUE #( %tky         = ls_exemption-%tky
                      exemptstatus = zif_atc_exemption=>status-approved
                      approver     = sy-uname
                      approvedat   = lv_now ) TO lt_update.

      write_log( is_row    = ls_exemption
                 iv_action = zif_atc_exemption=>logaction-approve
                 iv_from   = ls_exemption-exemptstatus
                 iv_to     = zif_atc_exemption=>status-approved ).

    ENDLOOP.

    MODIFY ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        UPDATE FIELDS ( exemptstatus approver approvedat )
        WITH lt_update.

    " 실패한 건은 result 에 넣지 않는다. keys 로 다시 읽으면 거부된 건까지
    " 성공한 것처럼 돌려주게 된다.
    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( lt_update )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_res IN lt_result
                      ( %tky = ls_res-%tky %param = CORRESPONDING #( ls_res ) ) ).

  ENDMETHOD.


  METHOD reject.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption).

    DATA lt_update TYPE TABLE FOR UPDATE zr_atcexemption.

    GET TIME STAMP FIELD DATA(lv_now).

    LOOP AT keys INTO DATA(ls_key).

      DATA(ls_exemption) = VALUE #( lt_exemption[ %tky = ls_key-%tky ] OPTIONAL ).

      IF ls_exemption-exemptstatus <> zif_atc_exemption=>status-pending.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_error( iv_number = '020'
                                          iv_v1     = ls_exemption-exemptstatus ) )
               TO reported-exemption.
        CONTINUE.
      ENDIF.

      " 반려 사유는 필수다. 사유 없는 반려는 신청자가 무엇을 고쳐야 할지 모른다.
      IF ls_key-%param-rejectreason IS INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_error( iv_number = '015' ) ) TO reported-exemption.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky               = ls_key-%tky
                      exemptstatus       = zif_atc_exemption=>status-rejected
                      approver           = sy-uname
                      approvedat         = lv_now ) TO lt_update.

      write_log( is_row     = ls_exemption
                 iv_action  = zif_atc_exemption=>logaction-reject
                 iv_from    = ls_exemption-exemptstatus
                 iv_to      = zif_atc_exemption=>status-rejected
                 iv_comment = ls_key-%param-rejectreason ).

    ENDLOOP.

    MODIFY ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        UPDATE FIELDS ( exemptstatus approver approvedat )
        WITH lt_update.

    " 실패한 건은 result 에 넣지 않는다. keys 로 다시 읽으면 거부된 건까지
    " 성공한 것처럼 돌려주게 된다.
    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( lt_update )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_res IN lt_result
                      ( %tky = ls_res-%tky %param = CORRESPONDING #( ls_res ) ) ).

  ENDMETHOD.


  METHOD revoke.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption).

    DATA lt_update TYPE TABLE FOR UPDATE zr_atcexemption.

    LOOP AT lt_exemption INTO DATA(ls_exemption).

      " 상태가 맞지 않으면 조용히 건너뛰지 않고 거부한다. 그냥 넘기면 액션이
      " 성공한 것처럼 끝나서 사용자는 왜 아무 일도 없었는지 알 수 없다.
      IF ls_exemption-exemptstatus <> zif_atc_exemption=>status-approved.
        APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky = ls_exemption-%tky
                        %msg = new_error( iv_number = '020'
                                          iv_v1     = ls_exemption-exemptstatus ) )
               TO reported-exemption.
        CONTINUE.
      ENDIF.

      " 표준 쪽 무효화도 저장 시퀀스에서 한다 (승인과 같은 이유).
      APPEND VALUE #( %tky               = ls_exemption-%tky
                      exemptstatus       = zif_atc_exemption=>status-revoked ) TO lt_update.

      write_log( is_row    = ls_exemption
                 iv_action = zif_atc_exemption=>logaction-revoke
                 iv_from   = ls_exemption-exemptstatus
                 iv_to     = zif_atc_exemption=>status-revoked ).

    ENDLOOP.

    MODIFY ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        UPDATE FIELDS ( exemptstatus )
        WITH lt_update.

    " 실패한 건은 result 에 넣지 않는다. keys 로 다시 읽으면 거부된 건까지
    " 성공한 것처럼 돌려주게 된다.
    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( lt_update )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_res IN lt_result
                      ( %tky = ls_res-%tky %param = CORRESPONDING #( ls_res ) ) ).

  ENDMETHOD.


  METHOD extendvalidity.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption).

    DATA lt_update TYPE TABLE FOR UPDATE zr_atcexemption.


    LOOP AT keys INTO DATA(ls_key).

      DATA(ls_exemption) = VALUE #( lt_exemption[ %tky = ls_key-%tky ] OPTIONAL ).

      IF ls_exemption-exemptstatus <> zif_atc_exemption=>status-approved.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_error( iv_number = '020'
                                          iv_v1     = ls_exemption-exemptstatus ) )
               TO reported-exemption.
        CONTINUE.
      ENDIF.

      IF ls_key-%param-newvalidto <= ls_exemption-validto.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_error( iv_number = '016' ) ) TO reported-exemption.
        CONTINUE.
      ENDIF.

      " 연장은 자동 승인이 아니다. 승인대기로 되돌려 재승인을 받게 한다.
      " 그러지 않으면 한 번 승인된 예외가 무한히 연장된다.
      APPEND VALUE #( %tky               = ls_key-%tky
                      validto            = ls_key-%param-newvalidto
                      exemptstatus       = zif_atc_exemption=>status-pending
                      approver           = space
                      approvedat         = space ) TO lt_update.

      write_log( is_row     = ls_exemption
                 iv_action  = zif_atc_exemption=>logaction-submit
                 iv_from    = ls_exemption-exemptstatus
                 iv_to      = zif_atc_exemption=>status-pending
                 iv_comment = |유효기간 연장 신청: { ls_key-%param-newvalidto } | &&
                              |/ { ls_key-%param-extendreason }| ).

    ENDLOOP.

    MODIFY ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        UPDATE FIELDS ( validto exemptstatus approver approvedat )
        WITH lt_update.

    " 실패한 건은 result 에 넣지 않는다. keys 로 다시 읽으면 거부된 건까지
    " 성공한 것처럼 돌려주게 된다.
    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( lt_update )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_res IN lt_result
                      ( %tky = ls_res-%tky %param = CORRESPONDING #( ls_res ) ) ).

  ENDMETHOD.


  METHOD simulateimpact.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption).

    DATA(lo_reader) = NEW zcl_atc_finding_reader( ).

    LOOP AT lt_exemption INTO DATA(ls_exemption).

      " 패키지 단위 승인의 유일한 안전장치. 이게 없으면 승인자는 자기가
      " 무엇을 승인하는지 모른 채 패키지 전체의 규칙을 해제하게 된다.
      DATA(lt_impact) = lo_reader->simulate_impact(
                          iv_checkvariant = ls_exemption-checkvariant
                          iv_scopetype  = ls_exemption-scopetype
                          iv_devclass   = ls_exemption-devclass
                          iv_inclsubpkg = ls_exemption-inclsubpkg
                          iv_objecttype = ls_exemption-objecttype
                          iv_objectname = ls_exemption-objectname
                          " 체크까지 좁히지 않으면 다른 체크의 위반까지 세어
                          " 승인자에게 부풀려진 영향도를 보이게 된다.
                          iv_checkclass = ls_exemption-checkclass
                          iv_checkcode  = COND #( WHEN ls_exemption-rulescope =
                                                       zif_atc_exemption=>rulescope-check
                                                  THEN space
                                                  ELSE ls_exemption-checkcode ) ).

      DATA(lv_text) = |이 예외 승인 시 면제되는 현재 위반: { lines( lt_impact ) }건|.

      IF ls_exemption-scopetype = zif_atc_exemption=>scope-pckg.
        lv_text = |{ lv_text } (이 패키지에 향후 생성되는 오브젝트도 자동 면제됩니다)|.
      ENDIF.

      APPEND VALUE #( %tky = ls_exemption-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-information
                               text     = lv_text ) ) TO reported-exemption.

    ENDLOOP.

    result = VALUE #( FOR ls_res IN lt_exemption
                      ( %tky = ls_res-%tky %param = CORRESPONDING #( ls_res ) ) ).

  ENDMETHOD.


  METHOD createfromfinding.

    DATA lt_create TYPE TABLE FOR CREATE zr_atcexemption.
    DATA lt_item   TYPE TABLE FOR CREATE zr_atcexemption\_Item.
    DATA ls_item   LIKE LINE OF lt_item.

    DATA(lo_reader) = NEW zcl_atc_finding_reader( ).

    LOOP AT keys INTO DATA(ls_key).

      DATA(ls_param) = ls_key-%param.
      DATA(lv_scope) = ls_param-scopetype.

      " 증빙으로 쓸 finding 을 다시 읽는다. 파라미터로 라인 정보를 받지 않고
      " 여기서 채우는 이유는, 신청서 헤더에 라인을 올리지 않는다는 원칙을
      " 호출자 쪽에서도 지키게 하려는 것이다.
      DATA(lt_finding) = lo_reader->select( VALUE #(
                           checkvariant = ls_param-checkvariant
                           devclass     = ls_param-devclass
                           objecttype   = ls_param-objecttype
                           objectname   = ls_param-objectname
                           checkclass   = ls_param-checkclass
                           checkcode    = ls_param-checkcode
                           only_mine    = abap_false ) ).

      IF lt_finding IS INITIAL.
        APPEND VALUE #( %cid = ls_key-%cid ) TO failed-exemption.
        APPEND VALUE #( %cid = ls_key-%cid
                        %msg = new_error( iv_number = '017' ) ) TO reported-exemption.
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        %cid         = ls_key-%cid
        checkvariant = ls_param-checkvariant
        scopetype  = lv_scope
        devclass   = ls_param-devclass
        " 패키지 스코프에서도 오브젝트를 채운다. 표준 create_exemption 이
        " 오브젝트를 필수로 받고 set_object_scope( ) 로 범위를 넓히는 구조라,
        " 출발점 오브젝트가 없으면 표준에 반영할 수 없다.
        objecttype = ls_param-objecttype
        objectname = ls_param-objectname
        " 뷰가 주는 값을 그대로 옮긴다. 표준 create_exemption 이 받는 값과 같다.
        checkclass = ls_param-checkclass
        checkcode  = ls_param-checkcode
        rulescope  = zif_atc_exemption=>rulescope-message
        " preregflag 는 넣지 않는다. derivePreReg 가 증빙 유무로 판정한다.
        validfrom  = sy-datum ) TO lt_create.

      " 선택한 오브젝트의 위반 건을 증빙으로 붙인다.
      " PKG 스코프라도 증빙은 출발점이 된 오브젝트의 것만 담는다. 효력 범위와
      " 증빙 범위는 다르며, 그 구분이 이 설계의 전제다.
      CLEAR ls_item.
      ls_item-%cid_ref = ls_key-%cid.

      DATA(lv_itemno) = 0.
      LOOP AT lt_finding INTO DATA(ls_finding).
        lv_itemno = lv_itemno + 1.
        APPEND VALUE #( %cid        = |{ ls_key-%cid }_I{ lv_itemno }|
                        itemno      = lv_itemno
                        objecttype  = ls_finding-objecttype
                        objectname  = ls_finding-objectname
                        checksum    = ls_finding-checksum
                        checkclass   = ls_finding-checkclass
                        checkcode    = ls_finding-checkcode
                        priority    = ls_finding-priority
                        messagetext = ls_finding-msgtext )
               TO ls_item-%target.
      ENDLOOP.

      APPEND ls_item TO lt_item.

    ENDLOOP.

    MODIFY ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        CREATE FIELDS ( checkvariant scopetype devclass objecttype objectname
                        checkclass checkcode rulescope validfrom )
        WITH lt_create
      ENTITY exemption
        CREATE BY \_Item
        FIELDS ( itemno objecttype objectname checksum
                 checkclass checkcode priority messagetext )
        WITH lt_item
      MAPPED DATA(lt_mapped)
      FAILED DATA(lt_failed)
      REPORTED DATA(lt_reported).

    " 앞서 담은 "finding 없음" 메시지를 덮지 않도록 덧붙인다.
    mapped = CORRESPONDING #( DEEP lt_mapped ).
    APPEND LINES OF lt_failed-exemption   TO failed-exemption.
    APPEND LINES OF lt_reported-exemption TO reported-exemption.

    result = VALUE #( FOR ls_map IN lt_mapped-exemption
                      ( %cid = ls_map-%cid %tky = ls_map-%tky ) ).

  ENDMETHOD.


  METHOD write_log.

    DATA lt_log TYPE TABLE FOR CREATE zr_atcexemption\_Log.

    GET TIME STAMP FIELD DATA(lv_now).

    " 이력 순번은 기존 건수 + 1. 활성 인스턴스 기준으로 센다.
    SELECT COUNT( * )
      FROM ztatcexemptlog
      WHERE exemptuuid = @is_row-exemptuuid
      INTO @DATA(lv_count).

    lt_log = VALUE #( ( %tky    = is_row-%tky
                        %target = VALUE #( ( %cid        = |LOG_{ lv_count + 1 }|
                                             seqnr       = lv_count + 1
                                             actioncode  = iv_action
                                             fromstatus  = iv_from
                                             tostatus    = iv_to
                                             commenttext = iv_comment
                                             actionby    = sy-uname
                                             actionat    = lv_now ) ) ) ).

    " 이력 필드는 전부 readonly 지만 IN LOCAL MODE 는 필드 제어를 우회하므로
    " behavior pool 에서는 쓸 수 있다. 화면에서는 여전히 못 고친다.
    MODIFY ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        CREATE BY \_Log
        FIELDS ( seqnr actioncode fromstatus tostatus commenttext actionby actionat )
        WITH lt_log
      FAILED   DATA(lt_log_failed)
      REPORTED DATA(lt_log_reported).

    " 여기가 실패하면 감사 이력 한 줄이 사라진다. 호출자가 determination 이라
    " 트랜잭션을 되돌릴 수단이 없어 진행은 시키지만, 결과를 버리지는 않는다.
    " 조용히 버리는 바람에 _Log 에 create 가 없던 것을 한참 못 찾았다.
    ASSERT lt_log_failed IS INITIAL.

  ENDMETHOD.


  METHOD new_error.

    ro_msg = new_message( id       = c_msgclass
                          number   = iv_number
                          severity = if_abap_behv_message=>severity-error
                          v1       = iv_v1
                          v2       = iv_v2 ).

  ENDMETHOD.

ENDCLASS.


"! 저장 시퀀스. 표준 ATC 예외 저장소 반영을 여기서 수행한다.
"!
"! 액션이 아니라 저장 시점인 이유: create_exemption 은 DB 를 바꾸고 잠금을 잡는다.
"! RAP 에서 그런 호출은 저장 시퀀스 안에서만 해야 한다. 액션에서 부르면
"! 사용자가 초안을 버리거나 저장이 실패했을 때 CBO 기록 없는 표준 예외가 남는다.
"!
"! 기존 샘플은 같은 이유로 BGPF 를 썼지만, 우리는 백그라운드 처리가 필요 없으므로
"! RAP 의 additional save 로 충분하다.
CLASS lsc_zr_atcexemption DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.

ENDCLASS.


CLASS lsc_zr_atcexemption IMPLEMENTATION.

  METHOD save_modified.

    DATA(lo_sync) = NEW zcl_atc_exempt_sync( ).

    " 이번 저장에서 승인/철회로 바뀐 건만 표준에 반영한다.
    LOOP AT update-exemption INTO DATA(ls_exemption).

      " 승인되었는데 아직 표준 예외가 없는 건 -> 생성
      IF ls_exemption-exemptstatus = zif_atc_exemption=>status-approved
     AND ls_exemption-extexemptid IS INITIAL.

        SELECT SINGLE * FROM ztatcexempt
          WHERE exemptuuid = @ls_exemption-exemptuuid
          INTO @DATA(ls_db).

        DATA(ls_created) = lo_sync->create_exemption( ls_db ).

        " 표준 반영이 실패해도 CBO 승인 기록은 되돌리지 않는다. 대장이 원천이고
        " 표준 반영은 뒤따르는 구조다. 실패한 건은 extexemptid 가 비어 있으므로
        " 정합성 점검 배치가 찾아낸다.
        UPDATE ztatcexempt
          SET extexemptid = @ls_created-extexemptid
          WHERE exemptuuid = @ls_exemption-exemptuuid.

        INSERT ztatcexemptlog FROM @( VALUE #(
          loguuid    = cl_system_uuid=>create_uuid_x16_static( )
          exemptuuid = ls_exemption-exemptuuid
          seqnr      = 0
          actioncode = zif_atc_exemption=>logaction-sync
          fromstat   = zif_atc_exemption=>status-approved
          tostat     = zif_atc_exemption=>status-approved
          commenttxt = ls_created-message
          actionby   = sy-uname ) ).

      ENDIF.

      " 철회/만료되었는데 표준 예외가 남아 있는 건 -> 무효화
      IF ( ls_exemption-exemptstatus = zif_atc_exemption=>status-revoked
        OR ls_exemption-exemptstatus = zif_atc_exemption=>status-expired )
     AND ls_exemption-extexemptid IS NOT INITIAL.

        DATA(ls_revoked) = lo_sync->revoke_exemption(
                             iv_extexemptid = ls_exemption-extexemptid
                             iv_reason      = COND #(
                               WHEN ls_exemption-exemptstatus = zif_atc_exemption=>status-expired
                               THEN |유효기간 경과로 자동 만료|
                               ELSE |CBO 대장에서 철회| ) ).

        INSERT ztatcexemptlog FROM @( VALUE #(
          loguuid    = cl_system_uuid=>create_uuid_x16_static( )
          exemptuuid = ls_exemption-exemptuuid
          seqnr      = 0
          actioncode = zif_atc_exemption=>logaction-sync
          fromstat   = zif_atc_exemption=>status-approved
          tostat     = ls_exemption-exemptstatus
          commenttxt = ls_revoked-message
          actionby   = sy-uname ) ).

      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
