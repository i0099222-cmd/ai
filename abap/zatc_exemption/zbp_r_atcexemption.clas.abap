"! ZR_AtcExemption BO 의 behavior implementation.
"!
"! 요청서(헤더) + 대상(아이템) 구조. 대상 한 줄 = 표준 예외 1건이고,
"! 상신·승인·반려·철회는 요청서 단위로 전부 성공해야 성공이다.
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



"! 대상 줄 규칙. 요청서 핸들러(상신 직전 확인)와 대상 핸들러(저장 검증)가 같이 쓴다.
CLASS lcl_rules DEFINITION FINAL.

  PUBLIC SECTION.

    "! 다른 요청서의 대기·승인 대상과 겹치는가.
    "!   PCKG : 오브젝트를 비교하지 않는다.
    "!   CHK  : 체크 코드를 비교하지 않는다. 한쪽이라도 CHK 면 그 체크의 모든 코드를 덮는다.
    "! 빈 range 는 IN 에서 전부 통과하므로 "비교하지 않음" 이 된다.
    CLASS-METHODS has_overlap
      IMPORTING is_header       TYPE ztatcexempt
                is_item         TYPE ztatcexempti
      RETURNING VALUE(rv_found) TYPE abap_boolean.

ENDCLASS.


CLASS lcl_rules IMPLEMENTATION.

  METHOD has_overlap.

    DATA lr_objtype TYPE RANGE OF ztatcexempti-objecttype.
    DATA lr_objname TYPE RANGE OF ztatcexempti-objectname.
    DATA lr_code    TYPE RANGE OF ztatcexempti-checkcode.

    IF is_item-scopetype <> zif_atc_exemption=>scope-pckg.
      lr_objtype = VALUE #( ( sign = 'I' option = 'EQ' low = is_item-objecttype ) ).
      lr_objname = VALUE #( ( sign = 'I' option = 'EQ' low = is_item-objectname ) ).
    ENDIF.

    IF is_item-rulescope <> zif_atc_exemption=>rulescope-check.
      lr_code = VALUE #( ( sign = 'I' option = 'EQ' low = is_item-checkcode ) ).
    ENDIF.

    SELECT SINGLE @abap_true
      FROM ztatcexempti AS item
      INNER JOIN ztatcexempt AS hdr ON hdr~exemptuuid = item~exemptuuid
      WHERE hdr~exemptuuid  <> @is_header-exemptuuid
        AND item~scopetype   = @is_item-scopetype
        AND item~devclass    = @is_item-devclass
        AND item~objecttype IN @lr_objtype
        AND item~objectname IN @lr_objname
        AND hdr~checkclass   = @is_header-checkclass
        AND ( item~rulescope = @zif_atc_exemption=>rulescope-check
           OR item~checkcode IN @lr_code )
        AND hdr~exemptstat  IN ( @zif_atc_exemption=>status-pending,
                                 @zif_atc_exemption=>status-approved )
        AND hdr~validto     >= @is_header-validfrom
        AND hdr~validfrom   <= @is_header-validto
      INTO @rv_found.

  ENDMETHOD.

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

    METHODS validatevariant FOR VALIDATE ON SAVE
      IMPORTING keys FOR exemption~validatevariant.

    METHODS validatevalidity FOR VALIDATE ON SAVE
      IMPORTING keys FOR exemption~validatevalidity.

    METHODS validatereason FOR VALIDATE ON SAVE
      IMPORTING keys FOR exemption~validatereason.

    METHODS submit FOR MODIFY
      IMPORTING keys FOR ACTION exemption~submit RESULT result.

    METHODS withdraw FOR MODIFY
      IMPORTING keys FOR ACTION exemption~withdraw RESULT result.

    METHODS approve FOR MODIFY
      IMPORTING keys FOR ACTION exemption~approve RESULT result.

    METHODS reject FOR MODIFY
      IMPORTING keys FOR ACTION exemption~reject RESULT result.

    METHODS extendvalidity FOR MODIFY
      IMPORTING keys FOR ACTION exemption~extendvalidity RESULT result.

    METHODS simulateimpact FOR MODIFY
      IMPORTING keys FOR ACTION exemption~simulateimpact RESULT result.

    "! 상태 전이 1건을 이력에 남긴다. 감사 대응의 유일한 근거이므로 모든 액션이 호출한다.
    METHODS write_log
      IMPORTING is_row     TYPE ty_read
                iv_action  TYPE char10
                iv_from    TYPE char2
                iv_to      TYPE char2
                iv_comment TYPE string OPTIONAL.

    "! 요청서 1건의 표준 반영을 별도 LUW 에서 수행하고 결과를 돌려준다.
    "!
    "! 액션에서 부르는 이유: RAP 저장 시퀀스(save_modified)는 COMMIT 도 RFC 도
    "! 금지한다. 표준 API 는 내부에서 COMMIT 을 하고 cl_abap_parallel 은 aRFC 를
    "! 쓰므로, 저장 시퀀스에서는 어떤 형태로도 부를 수 없다.
    "!
    "! 결과의 대상별 상태는 성공 여부와 무관하게 아이템에 반영한다. 그래서 표준
    "! 반영이 실패한 경우 failed 를 올리지 않는다 - 올리면 요청 전체가 롤백돼 이미
    "! 표준에서 바뀐 줄의 상태까지 사라진다. 실패는 에러 메시지로만 알린다.
    METHODS sync_standard
      IMPORTING is_exemption     TYPE ztatcexempt
                it_item          TYPE zif_atc_exemption=>tt_item
                iv_operation     TYPE char10
                iv_reason        TYPE string OPTIONAL
      RETURNING VALUE(rs_result) TYPE zif_atc_exemption=>ty_batch_result.

    METHODS new_error
      IMPORTING iv_number     TYPE symsgno
                iv_v1         TYPE any OPTIONAL
                iv_v2         TYPE any OPTIONAL
      RETURNING VALUE(ro_msg) TYPE REF TO if_abap_behv_message.

ENDCLASS.


CLASS lhc_exemption IMPLEMENTATION.

  METHOD get_instance_features.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        FIELDS ( exemptstatus requester ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption)
      FAILED failed.

    " 승인 권한은 행과 무관하다. 한 번만 본다.
    DATA(lv_is_approver) = zcl_atc_exempt_sync=>is_approver( ).

    LOOP AT lt_exemption INTO DATA(ls_exemption).

      DATA(lv_is_requester) = xsdbool( ls_exemption-requester = sy-uname ).
      DATA(lv_own_draft)    = xsdbool( ls_exemption-exemptstatus = zif_atc_exemption=>status-draft
                                       AND lv_is_requester = abap_true ).

      " 버튼 활성화 규칙. 같은 화면에서 신청자와 승인자를 구분하는 지점이다.
      "   신청자 : 본인 초안에서만 Edit/Submit/Delete, 승인대기에서 Withdraw
      "   승인자 : 승인대기에서 Approve/Reject, 승인 건에서도 Reject
      "   자기승인은 금지한다.
      APPEND VALUE #(
        %tky                   = ls_exemption-%tky

        " 초안만 고친다. 상신 뒤에 대상이 바뀌면 표준에 만든 예외와 어긋난다.
        %action-edit           = COND #( WHEN lv_own_draft = abap_true
                                         THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )

        %action-submit         = COND #( WHEN lv_own_draft = abap_true
                                         THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )

        %action-withdraw       = COND #(
          WHEN ls_exemption-exemptstatus = zif_atc_exemption=>status-pending
           AND lv_is_requester = abap_true
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )

        %action-approve        = COND #(
          WHEN ls_exemption-exemptstatus = zif_atc_exemption=>status-pending
           AND lv_is_approver = abap_true
           AND lv_is_requester = abap_false
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )

        " 승인 건에서도 반려할 수 있다. 표준이 승인된 예외에 Reject 를 허용하고,
        " 그것이 표준의 무효화 경로다.
        %action-reject         = COND #(
          WHEN ( ls_exemption-exemptstatus = zif_atc_exemption=>status-pending
              OR ls_exemption-exemptstatus = zif_atc_exemption=>status-approved )
           AND lv_is_approver = abap_true
           AND lv_is_requester = abap_false
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )

        %action-extendvalidity = COND #(
          WHEN ls_exemption-exemptstatus = zif_atc_exemption=>status-approved
           AND lv_is_requester = abap_true
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )

        " 영향도는 누구나 확인할 수 있어야 승인 판단에 쓸 수 있다.
        %action-simulateimpact = if_abap_behv=>fc-o-enabled

        " 삭제는 초안만. 승인/반려 건을 지우면 감사 근거가 사라진다.
        %delete                = COND #( WHEN lv_own_draft = abap_true
                                         THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )

        %assoc-_item           = COND #(
          WHEN ls_exemption-exemptstatus = zif_atc_exemption=>status-draft
          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )

      ) TO result.

    ENDLOOP.

  ENDMETHOD.


  METHOD get_instance_authorizations.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        FIELDS ( requester ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption)
      FAILED failed.

    DATA(lv_approve) = COND #( WHEN zcl_atc_exempt_sync=>is_approver( ) = abap_true
                               THEN if_abap_behv=>auth-allowed
                               ELSE if_abap_behv=>auth-unauthorized ).

    LOOP AT lt_exemption INTO DATA(ls_exemption).

      " 수정/삭제는 신청자 본인만. 별도 권한 오브젝트를 두지 않는다.
      " 승인자의 상태 변경은 액션 안에서 LOCAL MODE 로 하므로 여기 걸리지 않는다.
      DATA(lv_update) = COND #( WHEN ls_exemption-requester = sy-uname
                                THEN if_abap_behv=>auth-allowed
                                ELSE if_abap_behv=>auth-unauthorized ).

      APPEND VALUE #( %tky             = ls_exemption-%tky
                      %update          = lv_update
                      %delete          = lv_update
                      %action-approve  = lv_approve
                      %action-reject   = lv_approve ) TO result.

    ENDLOOP.

  ENDMETHOD.


  METHOD get_global_authorizations.

    " 신청은 누구나 할 수 있다. 표준 ADT 에서도 개발자는 누구나 예외를 신청한다.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.

  ENDMETHOD.


  METHOD setinitialvalues.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        FIELDS ( validfrom )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption).

    MODIFY ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        UPDATE FIELDS ( exemptstatus requester validfrom )
        WITH VALUE #( FOR ls_exemption IN lt_exemption
                      ( %tky         = ls_exemption-%tky
                        exemptstatus = zif_atc_exemption=>status-draft
                        requester    = sy-uname
                        validfrom    = COND #( WHEN ls_exemption-validfrom IS INITIAL
                                               THEN sy-datum ELSE ls_exemption-validfrom ) ) )
      FAILED DATA(lt_init_failed).

    " 여기서 쓰는 값은 방금 계산한 것이라, 실패한다면 사용자에게 보여줄 메시지가
    " 아니라 결함이다.
    ASSERT lt_init_failed IS INITIAL.

  ENDMETHOD.


  METHOD derivecheckgroup.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        FIELDS ( checkvariant checkclass checkgroup )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption)
      ENTITY exemption BY \_Item
        FIELDS ( exemptuuid checkclass )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    DATA lt_update      TYPE TABLE FOR UPDATE zr_atcexemption.
    DATA lt_item_update TYPE TABLE FOR UPDATE zr_atcexemption\\exemptionitem.

    LOOP AT lt_exemption INTO DATA(ls_exemption).

      " 체크 클래스가 비어 있고 그 변형의 체크가 하나뿐이면 채운다.
      " 둘 이상이면 고르게 둔다 - 값 도움이 변형으로 걸러 준다.
      DATA(lv_checkclass) = ls_exemption-checkclass.
      IF lv_checkclass IS INITIAL.
        SELECT checkclass FROM zi_atccheckclassvh
          WHERE checkvariant = @ls_exemption-checkvariant
          INTO TABLE @DATA(lt_class)
          UP TO 2 ROWS.
        IF lines( lt_class ) = 1.
          lv_checkclass = lt_class[ 1 ]-checkclass.
        ENDIF.
      ENDIF.

      " 체크그룹은 사용자가 고르는 값이 아니라 변형 정책에서 파생된다.
      DATA(lv_checkgroup) = zcl_atc_config=>get( )->get_config( ls_exemption-checkvariant )-checkgroup.

      IF lv_checkclass <> ls_exemption-checkclass OR lv_checkgroup <> ls_exemption-checkgroup.
        APPEND VALUE #( %tky       = ls_exemption-%tky
                        checkgroup = lv_checkgroup
                        checkclass = lv_checkclass ) TO lt_update.
      ENDIF.

      " 대상 줄의 체크 클래스는 값 도움 필터용 사본이다. 요청서와 같게 맞춘다.
      LOOP AT lt_item INTO DATA(ls_item)
           WHERE exemptuuid = ls_exemption-exemptuuid
             AND checkclass <> lv_checkclass.
        APPEND VALUE #( %tky       = ls_item-%tky
                        checkclass = lv_checkclass ) TO lt_item_update.
      ENDLOOP.

    ENDLOOP.

    MODIFY ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        UPDATE FIELDS ( checkgroup checkclass )
        WITH lt_update
      ENTITY exemptionitem
        UPDATE FIELDS ( checkclass )
        WITH lt_item_update.

  ENDMETHOD.


  METHOD validatevariant.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        FIELDS ( checkvariant )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption).

    LOOP AT lt_exemption INTO DATA(ls_exemption).

      " 컨트롤 테이블에 활성으로 등록된 변형만 신청할 수 있다.
      IF zcl_atc_config=>get( )->get_config( ls_exemption-checkvariant )-activeflg = abap_true.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
      APPEND VALUE #( %tky                  = ls_exemption-%tky
                      %state_area           = 'VALIDATE_VARIANT'
                      %element-checkvariant = if_abap_behv=>mk-on
                      %msg = new_error( iv_number = '009'
                                        iv_v1     = ls_exemption-checkvariant ) )
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

      " 상한은 컨트롤 테이블의 변형별 설정값이다. 0 이면 제한 없음.
      DATA(ls_config) = zcl_atc_config=>get( )->get_config( ls_exemption-checkvariant ).

      IF ls_config-maxvalidmon <= 0.
        CONTINUE.
      ENDIF.

      " 개월 상한을 일수로 환산한다. 30일 근사로 충분하다.
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

      " 사유 코드는 표준이 값 목록을 가진다(SATC_CI_REASONS). 거기서 확인한다.
      SELECT SINGLE requirecomment FROM zi_atcreasonvh
        WHERE reasoncode = @ls_exemption-reasoncode
        INTO @DATA(lv_require_comment).

      DATA(lv_known) = xsdbool( sy-subrc = 0 ).

      " 서술을 요구하는 경우는 둘이다.
      "   1) 표준이 그 사유에 요구한다 (require_comment: FPOS, OTHR).
      "      여기서 막지 않으면 표준 등록이 별도 LUW 에서 원인 없이 실패한다.
      "   2) 우리 설정이 요구한다 (reasonreq).
      DATA(lv_text_required) = xsdbool(
        lv_require_comment = abap_true
        OR zcl_atc_config=>get( )->get_config(
             ls_exemption-checkvariant )-reasonreq = abap_true ).

      IF lv_known = abap_true
     AND ( lv_text_required = abap_false
        OR strlen( ls_exemption-reasontext ) >= zif_atc_exemption=>min_reason_length ).
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


  METHOD submit.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption)
      ENTITY exemption BY \_Item
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    DATA lt_update      TYPE TABLE FOR UPDATE zr_atcexemption.
    DATA lt_item_update TYPE TABLE FOR UPDATE zr_atcexemption\\exemptionitem.

    DATA(lo_reader) = NEW zcl_atc_finding_reader( ).

    LOOP AT lt_exemption INTO DATA(ls_exemption).

      " 상태가 맞지 않으면 조용히 건너뛰지 않고 거부한다.
      IF ls_exemption-exemptstatus <> zif_atc_exemption=>status-draft.
        APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky = ls_exemption-%tky
                        %msg = new_error( iv_number = '020'
                                          iv_v1     = ls_exemption-exemptstatus ) )
               TO reported-exemption.
        CONTINUE.
      ENDIF.

      " 표준은 승인자 1명이 지정되어야 승인대기로 올릴 수 있다. 미리 막는다.
      IF zcl_atc_config=>get( )->get_config( ls_exemption-checkvariant )-defapprover IS INITIAL.
        APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky = ls_exemption-%tky
                        %msg = new_error( iv_number = '021'
                                          iv_v1     = ls_exemption-checkvariant ) )
               TO reported-exemption.
        CONTINUE.
      ENDIF.

      DATA(ls_hdr) = CORRESPONDING ztatcexempt( ls_exemption MAPPING FROM ENTITY ).
      DATA(lt_target) = VALUE zif_atc_exemption=>tt_item(
                          FOR ls_i IN lt_item WHERE ( exemptuuid = ls_exemption-exemptuuid )
                          ( CORRESPONDING #( ls_i MAPPING FROM ENTITY ) ) ).
      SORT lt_target BY itemno.

      IF lt_target IS INITIAL.
        APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky = ls_exemption-%tky
                        %msg = new_error( iv_number = '023' ) ) TO reported-exemption.
        CONTINUE.
      ENDIF.

      " 표준을 부르기 전에 중복을 한 번 더 본다. 저장 검증이 있지만 그 뒤에
      " 다른 요청이 먼저 상신됐을 수 있다. 부른 뒤에 걸리면 표준에만 예외가 남는다.
      " 영향도(면제될 현재 위반 건수)는 이력에 남겨 승인자가 읽게 한다.
      DATA(lv_overlap) = VALUE string( ).
      DATA(lv_impact)  = 0.
      LOOP AT lt_target INTO DATA(ls_target).
        IF lcl_rules=>has_overlap( is_header = ls_hdr is_item = ls_target ) = abap_true.
          lv_overlap = |{ ls_target-devclass } { ls_target-objectname }|.
          EXIT.
        ENDIF.
        lv_impact = lv_impact + lines( lo_reader->simulate_impact(
                                         iv_checkvariant = ls_hdr-checkvariant
                                         iv_scopetype    = ls_target-scopetype
                                         iv_devclass     = ls_target-devclass
                                         iv_objecttype   = ls_target-objecttype
                                         iv_objectname   = ls_target-objectname
                                         iv_checkclass   = ls_hdr-checkclass
                                         iv_checkcode    = COND #( WHEN ls_target-rulescope =
                                                                        zif_atc_exemption=>rulescope-check
                                                                   THEN space
                                                                   ELSE ls_target-checkcode ) ) ).
      ENDLOOP.

      IF lv_overlap IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky = ls_exemption-%tky
                        %msg = new_error( iv_number = '013'
                                          iv_v1     = lv_overlap
                                          iv_v2     = ls_hdr-checkclass ) ) TO reported-exemption.
        CONTINUE.
      ENDIF.

      " 대상 전부를 표준에 승인대기로 만든다. 하나라도 실패하면 만든 것을 지운다.
      DATA(ls_sync) = sync_standard( is_exemption = ls_hdr
                                     it_item      = lt_target
                                     iv_operation = zcl_atc_exempt_parallel=>operation-register ).

      LOOP AT ls_sync-items INTO DATA(ls_res).
        APPEND VALUE #( %is_draft   = ls_exemption-%is_draft
                        itemuuid    = ls_res-itemuuid
                        extexemptid = ls_res-extexemptid
                        stdstatus   = ls_res-stdstatus ) TO lt_item_update.
      ENDLOOP.

      IF ls_sync-success = abap_false.
        APPEND VALUE #( %tky = ls_exemption-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Submit failed, nothing was registered: { ls_sync-message }| ) )
               TO reported-exemption.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky         = ls_exemption-%tky
                      exemptstatus = zif_atc_exemption=>status-pending ) TO lt_update.

      write_log( is_row     = ls_exemption
                 iv_action  = zif_atc_exemption=>logaction-submit
                 iv_from    = ls_exemption-exemptstatus
                 iv_to      = zif_atc_exemption=>status-pending
                 iv_comment = |대상 { lines( lt_target ) }줄 / 면제 대상 현재 위반 { lv_impact }건| ).

    ENDLOOP.

    MODIFY ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        UPDATE FIELDS ( exemptstatus )
        WITH lt_update
      ENTITY exemptionitem
        UPDATE FIELDS ( extexemptid stdstatus )
        WITH lt_item_update.

    " 실패한 건은 result 에 넣지 않는다.
    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( lt_update )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_r IN lt_result
                      ( %tky = ls_r-%tky %param = CORRESPONDING #( ls_r ) ) ).

  ENDMETHOD.


  METHOD withdraw.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption)
      ENTITY exemption BY \_Item
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    DATA lt_update      TYPE TABLE FOR UPDATE zr_atcexemption.
    DATA lt_item_update TYPE TABLE FOR UPDATE zr_atcexemption\\exemptionitem.

    LOOP AT lt_exemption INTO DATA(ls_exemption).

      IF ls_exemption-exemptstatus <> zif_atc_exemption=>status-pending.
        APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky = ls_exemption-%tky
                        %msg = new_error( iv_number = '020'
                                          iv_v1     = ls_exemption-exemptstatus ) )
               TO reported-exemption.
        CONTINUE.
      ENDIF.

      " 철회는 상신 취소다. 표준 예외를 지우고 요청서는 초안으로 돌아간다.
      " 지우지 못한 줄이 있으면 철회하지 않는다 - 그 줄은 표준 앱에서 그대로
      " 승인할 수 있게 된다. 지운 줄은 비워 두고, 다시 누르면 남은 줄만 지운다.
      DATA(ls_sync) = sync_standard(
                        is_exemption = CORRESPONDING #( ls_exemption MAPPING FROM ENTITY )
                        it_item      = VALUE #( FOR ls_i IN lt_item WHERE ( exemptuuid = ls_exemption-exemptuuid )
                                                ( CORRESPONDING #( ls_i MAPPING FROM ENTITY ) ) )
                        iv_operation = zcl_atc_exempt_parallel=>operation-withdraw
                        iv_reason    = |신청자 철회| ).

      LOOP AT ls_sync-items INTO DATA(ls_res).
        APPEND VALUE #( %is_draft   = ls_exemption-%is_draft
                        itemuuid    = ls_res-itemuuid
                        extexemptid = ls_res-extexemptid
                        stdstatus   = ls_res-stdstatus ) TO lt_item_update.
      ENDLOOP.

      IF ls_sync-success = abap_false.
        APPEND VALUE #( %tky = ls_exemption-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Withdraw incomplete, run it again to remove the rest: { ls_sync-message }| ) )
               TO reported-exemption.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky         = ls_exemption-%tky
                      exemptstatus = zif_atc_exemption=>status-draft ) TO lt_update.

      write_log( is_row     = ls_exemption
                 iv_action  = zif_atc_exemption=>logaction-withdraw
                 iv_from    = ls_exemption-exemptstatus
                 iv_to      = zif_atc_exemption=>status-draft ).

    ENDLOOP.

    MODIFY ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        UPDATE FIELDS ( exemptstatus )
        WITH lt_update
      ENTITY exemptionitem
        UPDATE FIELDS ( extexemptid stdstatus )
        WITH lt_item_update.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( lt_update )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_r IN lt_result
                      ( %tky = ls_r-%tky %param = CORRESPONDING #( ls_r ) ) ).

  ENDMETHOD.


  METHOD approve.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption)
      ENTITY exemption BY \_Item
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    DATA lt_update      TYPE TABLE FOR UPDATE zr_atcexemption.
    DATA lt_item_update TYPE TABLE FOR UPDATE zr_atcexemption\\exemptionitem.

    GET TIME STAMP FIELD DATA(lv_now).

    LOOP AT lt_exemption INTO DATA(ls_exemption).

      IF ls_exemption-exemptstatus <> zif_atc_exemption=>status-pending.
        APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky = ls_exemption-%tky
                        %msg = new_error( iv_number = '020'
                                          iv_v1     = ls_exemption-exemptstatus ) )
               TO reported-exemption.
        CONTINUE.
      ENDIF.

      " 자기승인 금지. features 에서도 막지만 OData 를 직접 부르는 경로가 있다.
      IF ls_exemption-requester = sy-uname.
        APPEND VALUE #( %tky = ls_exemption-%tky ) TO failed-exemption.
        APPEND VALUE #( %tky = ls_exemption-%tky
                        %msg = new_error( iv_number = '014' ) ) TO reported-exemption.
        CONTINUE.
      ENDIF.

      " 대상 전부를 승인한다. 표준은 한 건씩 승인해서 중간에 실패하면 앞서 승인된
      " 줄은 되돌릴 수 없다. 요청서는 승인대기로 남고, 다시 누르면 남은 줄만 승인한다.
      DATA(ls_sync) = sync_standard(
                        is_exemption = CORRESPONDING #( ls_exemption MAPPING FROM ENTITY )
                        it_item      = VALUE #( FOR ls_i IN lt_item WHERE ( exemptuuid = ls_exemption-exemptuuid )
                                                ( CORRESPONDING #( ls_i MAPPING FROM ENTITY ) ) )
                        iv_operation = zcl_atc_exempt_parallel=>operation-approve ).

      LOOP AT ls_sync-items INTO DATA(ls_res).
        APPEND VALUE #( %is_draft   = ls_exemption-%is_draft
                        itemuuid    = ls_res-itemuuid
                        extexemptid = ls_res-extexemptid
                        stdstatus   = ls_res-stdstatus ) TO lt_item_update.
      ENDLOOP.

      IF ls_sync-success = abap_false.
        APPEND VALUE #( %tky = ls_exemption-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Approval stopped, approve again to continue: { ls_sync-message }| ) )
               TO reported-exemption.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky         = ls_exemption-%tky
                      exemptstatus = zif_atc_exemption=>status-approved
                      approver     = sy-uname
                      approvedat   = lv_now ) TO lt_update.

      write_log( is_row     = ls_exemption
                 iv_action  = zif_atc_exemption=>logaction-approve
                 iv_from    = ls_exemption-exemptstatus
                 iv_to      = zif_atc_exemption=>status-approved ).

    ENDLOOP.

    MODIFY ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        UPDATE FIELDS ( exemptstatus approver approvedat )
        WITH lt_update
      ENTITY exemptionitem
        UPDATE FIELDS ( extexemptid stdstatus )
        WITH lt_item_update.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( lt_update )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_r IN lt_result
                      ( %tky = ls_r-%tky %param = CORRESPONDING #( ls_r ) ) ).

  ENDMETHOD.


  METHOD reject.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption)
      ENTITY exemption BY \_Item
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    DATA lt_update      TYPE TABLE FOR UPDATE zr_atcexemption.
    DATA lt_item_update TYPE TABLE FOR UPDATE zr_atcexemption\\exemptionitem.

    GET TIME STAMP FIELD DATA(lv_now).

    LOOP AT keys INTO DATA(ls_key).

      DATA(ls_exemption) = VALUE #( lt_exemption[ %tky = ls_key-%tky ] OPTIONAL ).

      " 승인 건도 반려할 수 있다. 이미 적용 중인 면제를 거둬들이는 경로다.
      IF ls_exemption-exemptstatus <> zif_atc_exemption=>status-pending
     AND ls_exemption-exemptstatus <> zif_atc_exemption=>status-approved.
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

      DATA(ls_sync) = sync_standard(
                        is_exemption = CORRESPONDING #( ls_exemption MAPPING FROM ENTITY )
                        it_item      = VALUE #( FOR ls_i IN lt_item WHERE ( exemptuuid = ls_exemption-exemptuuid )
                                                ( CORRESPONDING #( ls_i MAPPING FROM ENTITY ) ) )
                        iv_operation = zcl_atc_exempt_parallel=>operation-reject
                        iv_reason    = CONV #( ls_key-%param-rejectreason ) ).

      LOOP AT ls_sync-items INTO DATA(ls_res).
        APPEND VALUE #( %is_draft   = ls_exemption-%is_draft
                        itemuuid    = ls_res-itemuuid
                        extexemptid = ls_res-extexemptid
                        stdstatus   = ls_res-stdstatus ) TO lt_item_update.
      ENDLOOP.

      IF ls_sync-success = abap_false.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = |Rejection stopped, reject again to continue: { ls_sync-message }| ) )
               TO reported-exemption.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky         = ls_key-%tky
                      exemptstatus = zif_atc_exemption=>status-rejected
                      approver     = sy-uname
                      approvedat   = lv_now ) TO lt_update.

      write_log( is_row     = ls_exemption
                 iv_action  = zif_atc_exemption=>logaction-reject
                 iv_from    = ls_exemption-exemptstatus
                 iv_to      = zif_atc_exemption=>status-rejected
                 iv_comment = CONV #( ls_key-%param-rejectreason ) ).

    ENDLOOP.

    MODIFY ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        UPDATE FIELDS ( exemptstatus approver approvedat )
        WITH lt_update
      ENTITY exemptionitem
        UPDATE FIELDS ( extexemptid stdstatus )
        WITH lt_item_update.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( lt_update )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_r IN lt_result
                      ( %tky = ls_r-%tky %param = CORRESPONDING #( ls_r ) ) ).

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
      APPEND VALUE #( %tky         = ls_key-%tky
                      validto      = ls_key-%param-newvalidto
                      exemptstatus = zif_atc_exemption=>status-pending
                      approver     = space
                      approvedat   = space ) TO lt_update.

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

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( lt_update )
      RESULT DATA(lt_result).

    result = VALUE #( FOR ls_r IN lt_result
                      ( %tky = ls_r-%tky %param = CORRESPONDING #( ls_r ) ) ).

  ENDMETHOD.


  METHOD simulateimpact.

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exemption)
      ENTITY exemption BY \_Item
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item).

    DATA(lo_reader) = NEW zcl_atc_finding_reader( ).

    LOOP AT lt_exemption INTO DATA(ls_exemption).

      " 패키지 대상 승인의 안전장치. 이게 없으면 승인자는 자기가 무엇을 승인하는지
      " 모른 채 패키지 전체의 규칙을 해제하게 된다.
      DATA(lv_count) = 0.
      DATA(lv_pckg)  = 0.
      LOOP AT lt_item INTO DATA(ls_item) WHERE exemptuuid = ls_exemption-exemptuuid.
        IF ls_item-scopetype = zif_atc_exemption=>scope-pckg.
          lv_pckg = lv_pckg + 1.
        ENDIF.
        lv_count = lv_count + lines( lo_reader->simulate_impact(
                                       iv_checkvariant = ls_exemption-checkvariant
                                       iv_scopetype    = ls_item-scopetype
                                       iv_devclass     = ls_item-devclass
                                       iv_objecttype   = ls_item-objecttype
                                       iv_objectname   = ls_item-objectname
                                       iv_checkclass   = ls_exemption-checkclass
                                       iv_checkcode    = COND #( WHEN ls_item-rulescope =
                                                                      zif_atc_exemption=>rulescope-check
                                                                 THEN space
                                                                 ELSE ls_item-checkcode ) ) ).
      ENDLOOP.

      DATA(lv_text) = |Approving this request exempts { lv_count } current finding(s).|.
      IF lv_pckg > 0.
        lv_text = |{ lv_text } { lv_pckg } package target(s) also exempt objects created later.|.
      ENDIF.

      APPEND VALUE #( %tky = ls_exemption-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-information
                               text     = lv_text ) ) TO reported-exemption.

    ENDLOOP.

    result = VALUE #( FOR ls_r IN lt_exemption
                      ( %tky = ls_r-%tky %param = CORRESPONDING #( ls_r ) ) ).

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

    " 이력 필드는 전부 readonly 지만 IN LOCAL MODE 는 필드 제어를 우회한다.
    MODIFY ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption
        CREATE BY \_Log
        FIELDS ( seqnr actioncode fromstatus tostatus commenttext actionby actionat )
        WITH lt_log
      FAILED DATA(lt_log_failed).

    " 여기가 실패하면 감사 이력 한 줄이 사라진다. 조용히 버리지 않는다.
    ASSERT lt_log_failed IS INITIAL.

  ENDMETHOD.


  METHOD sync_standard.

    DATA lt_task TYPE cl_abap_parallel=>t_in_inst.

    " 요청서 1건 = 태스크 1개. 태스크가 대상 줄을 차례로 처리하고 실패하면 되돌린다.
    APPEND NEW zcl_atc_exempt_parallel( is_exemption = is_exemption
                                        it_item      = it_item
                                        iv_operation = iv_operation
                                        iv_reason    = iv_reason ) TO lt_task.

    NEW cl_abap_parallel( )->run_inst( EXPORTING p_in_tab  = lt_task
                                       IMPORTING p_out_tab = DATA(lt_done) ).

    LOOP AT lt_done INTO DATA(ls_done).
      rs_result = CAST zcl_atc_exempt_parallel( ls_done-inst )->get_result( ).
    ENDLOOP.

    " 태스크가 돌아오지 못했으면(워크프로세스 부족, 덤프) 결과가 비어 있다.
    " 성공으로 읽히지 않게 막는다.
    IF lt_done IS INITIAL.
      rs_result = VALUE #( success = abap_false
                           message = |Standard update did not run (no parallel task result)| ).
    ENDIF.

  ENDMETHOD.


  METHOD new_error.

    ro_msg = new_message( id       = c_msgclass
                          number   = iv_number
                          severity = if_abap_behv_message=>severity-error
                          v1       = iv_v1
                          v2       = iv_v2 ).

  ENDMETHOD.

ENDCLASS.


"! 대상 줄 핸들러. 범위 파생과 저장 검증.
CLASS lhc_exemptionitem DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    CONSTANTS c_msgclass TYPE symsgid VALUE 'ZATC_EXEMPT'.

    METHODS derivetarget FOR DETERMINE ON MODIFY
      IMPORTING keys FOR exemptionitem~derivetarget.

    METHODS validatetarget FOR VALIDATE ON SAVE
      IMPORTING keys FOR exemptionitem~validatetarget.

ENDCLASS.


CLASS lhc_exemptionitem IMPLEMENTATION.

  METHOD derivetarget.

    " 사용자는 패키지와(필요하면) 오브젝트만 넣는다. 나머지는 여기서 정한다.
    "   범위      : Object Name 이 비면 PCKG, 있으면 OBJ
    "   규칙 범위 : PCKG -> CHK(체크 전체), OBJ -> MSG(메시지 하나). 패키지를 MSG 로
    "               두면 규칙 수만큼 신청이 쪼개지고 일부 위반만 면제된다.
    "   패키지    : OBJ 면 TADIR 에서. 손으로 넣게 두면 오브젝트와 어긋난 예외가 생긴다.
    "   체크 클래스 : 요청서의 값 (값 도움 필터용 사본)
    "   번호      : 같은 요청서 안에서 다음 번호
    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemptionitem
        FIELDS ( exemptuuid itemno scopetype rulescope devclass objecttype objectname checkclass )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item)
      ENTITY exemptionitem BY \_Exemption
        FIELDS ( checkclass )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_parent).

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption BY \_Item
        FIELDS ( exemptuuid itemno )
        WITH CORRESPONDING #( lt_parent )
      RESULT DATA(lt_sibling).

    DATA lt_update TYPE TABLE FOR UPDATE zr_atcexemption\\exemptionitem.

    LOOP AT lt_item INTO DATA(ls_item).

      DATA(lv_scope) = COND #( WHEN ls_item-objectname IS NOT INITIAL
                               THEN zif_atc_exemption=>scope-obj
                               ELSE zif_atc_exemption=>scope-pckg ).
      DATA(lv_rulescope) = COND #( WHEN lv_scope = zif_atc_exemption=>scope-pckg
                                   THEN zif_atc_exemption=>rulescope-check
                                   ELSE zif_atc_exemption=>rulescope-message ).

      DATA(lv_devclass) = ls_item-devclass.
      IF lv_scope = zif_atc_exemption=>scope-obj AND ls_item-objecttype IS NOT INITIAL.
        SELECT SINGLE devclass FROM tadir
          WHERE pgmid    = 'R3TR'
            AND object   = @ls_item-objecttype
            AND obj_name = @ls_item-objectname
          INTO @DATA(lv_tadir_devclass).
        IF sy-subrc = 0.
          lv_devclass = lv_tadir_devclass.
        ENDIF.
      ENDIF.

      DATA(ls_parent)     = VALUE #( lt_parent[ exemptuuid = ls_item-exemptuuid ] OPTIONAL ).
      DATA(lv_checkclass) = ls_parent-checkclass.

      " 새 줄이면 같은 요청서의 가장 큰 번호 다음. 같은 번에 여러 줄이 생기면
      " 앞서 매긴 번호도 형제에 넣어 겹치지 않게 한다.
      DATA(lv_itemno) = ls_item-itemno.
      IF lv_itemno IS INITIAL.
        LOOP AT lt_sibling INTO DATA(ls_sibling) WHERE exemptuuid = ls_item-exemptuuid.
          lv_itemno = nmax( val1 = lv_itemno val2 = ls_sibling-itemno ).
        ENDLOOP.
        lv_itemno = lv_itemno + 1.
        MODIFY lt_sibling FROM VALUE #( itemno = lv_itemno )
          TRANSPORTING itemno WHERE itemuuid = ls_item-itemuuid.
      ENDIF.

      " 바뀐 줄만 고친다. 같은 값을 다시 쓰면 이 determination 이 또 불린다.
      IF lv_scope      = ls_item-scopetype
     AND lv_rulescope  = ls_item-rulescope
     AND lv_devclass   = ls_item-devclass
     AND lv_checkclass = ls_item-checkclass
     AND lv_itemno     = ls_item-itemno.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky       = ls_item-%tky
                      scopetype  = lv_scope
                      rulescope  = lv_rulescope
                      devclass   = lv_devclass
                      checkclass = lv_checkclass
                      itemno     = lv_itemno ) TO lt_update.

    ENDLOOP.

    MODIFY ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemptionitem
        UPDATE FIELDS ( scopetype rulescope devclass checkclass itemno )
        WITH lt_update.

  ENDMETHOD.


  METHOD validatetarget.

    " 대상 한 줄의 검증. 앞 단계가 실패하면 뒤는 보지 않는다.
    "   1) 이 변형에서 그 범위를 쓸 수 있는가        -> 요건 "패키지/오브젝트 단위로만"
    "   2) 범위에 맞는 필드가 채워졌는가
    "   3) 대상이 실재하고 고객 네임스페이스인가
    "   4) 예외로 덮을 수 없는 심각도의 위반이 있는가
    "   5) 같은 요청서 안에 같은 대상이 또 있는가
    "   6) 다른 요청서의 대기·승인 대상과 겹치는가
    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemptionitem
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_item)
      ENTITY exemptionitem BY \_Exemption
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_parent)
      LINK DATA(lt_link).

    READ ENTITIES OF zr_atcexemption IN LOCAL MODE
      ENTITY exemption BY \_Item
        ALL FIELDS WITH CORRESPONDING #( lt_parent )
      RESULT DATA(lt_sibling).

    LOOP AT lt_item INTO DATA(ls_item).

      DATA(ls_parent) = VALUE #( lt_parent[ exemptuuid = ls_item-exemptuuid ] OPTIONAL ).
      DATA(ls_link)   = VALUE #( lt_link[ source-itemuuid = ls_item-itemuuid ] OPTIONAL ).
      DATA(ls_config) = zcl_atc_config=>get( )->get_config( ls_parent-checkvariant ).
      DATA(lv_target) = |{ ls_item-devclass }| &&
                        COND string( WHEN ls_item-objectname IS NOT INITIAL
                                     THEN | { ls_item-objecttype } { ls_item-objectname }| ).

      DATA lv_error TYPE symsgno.
      DATA lv_v1    TYPE string.
      DATA lv_v2    TYPE string.
      CLEAR: lv_error, lv_v1, lv_v2.

      " --- 1) 범위 허용 여부 --- 변형이 비어 있으면 요청서 검증이 막으므로 여기서는 넘긴다.
      IF ls_parent-checkvariant IS NOT INITIAL
     AND zcl_atc_config=>get( )->is_scope_allowed(
           iv_checkvariant = ls_parent-checkvariant
           iv_scopetype    = ls_item-scopetype ) = abap_false.
        lv_error = '001'. lv_v1 = ls_item-scopetype. lv_v2 = ls_parent-checkvariant.

      " --- 2) 필수 필드 ---
      ELSEIF ls_item-devclass IS INITIAL.
        lv_error = '002'.
      ELSEIF ls_item-scopetype = zif_atc_exemption=>scope-obj
         AND ls_item-objecttype IS INITIAL.
        lv_error = '004'.
      ELSEIF ls_item-scopetype = zif_atc_exemption=>scope-obj
         AND ls_item-checkcode IS INITIAL.
        " 오브젝트 대상은 그 오브젝트가 어긴 규칙 하나(MSG)만 덮는다.
        lv_error = '022'.

      " --- 3) 대상 실재 여부. 표준 패키지/오브젝트에 예외를 거는 것은 목적이 아니다.
      ELSEIF ls_item-devclass(1) <> 'Z'
         AND ls_item-devclass(1) <> 'Y'
         AND ls_item-devclass(1) <> '/'.
        lv_error = '006'. lv_v1 = ls_item-devclass.
      ENDIF.

      IF lv_error IS INITIAL.
        SELECT SINGLE @abap_true FROM tdevc
          WHERE devclass = @ls_item-devclass
          INTO @DATA(lv_pkg_exists).
        IF lv_pkg_exists <> abap_true.
          lv_error = '007'. lv_v1 = ls_item-devclass.
        ENDIF.
        CLEAR lv_pkg_exists.
      ENDIF.

      IF lv_error IS INITIAL AND ls_item-scopetype = zif_atc_exemption=>scope-obj.
        SELECT SINGLE @abap_true FROM tadir
          WHERE pgmid    = 'R3TR'
            AND object   = @ls_item-objecttype
            AND obj_name = @ls_item-objectname
          INTO @DATA(lv_obj_exists).
        IF lv_obj_exists <> abap_true.
          lv_error = '008'. lv_v1 = ls_item-objectname.
        ENDIF.
        CLEAR lv_obj_exists.
      ENDIF.

      " --- 4) 심각도 상한. 1 이 가장 심각하므로 상한보다 작은 값의 위반이 있으면 거부한다.
      "     증빙을 저장하지 않으므로 지금 남아 있는 위반에서 본다.
      IF lv_error IS INITIAL AND ls_config-maxpriority > 0.
        DATA lr_objtype TYPE RANGE OF trobjtype.
        DATA lr_objname TYPE RANGE OF sobj_name.
        DATA lr_code    TYPE RANGE OF char10.
        CLEAR: lr_objtype, lr_objname, lr_code.
        IF ls_item-scopetype = zif_atc_exemption=>scope-obj.
          lr_objtype = VALUE #( ( sign = 'I' option = 'EQ' low = ls_item-objecttype ) ).
          lr_objname = VALUE #( ( sign = 'I' option = 'EQ' low = ls_item-objectname ) ).
          lr_code    = VALUE #( ( sign = 'I' option = 'EQ' low = ls_item-checkcode ) ).
        ENDIF.
        SELECT MIN( priority ) FROM zi_atcfinding
          WHERE checkclass  = @ls_parent-checkclass
            AND devclass    = @ls_item-devclass
            AND objecttype IN @lr_objtype
            AND objectname IN @lr_objname
            AND checkcode  IN @lr_code
          INTO @DATA(lv_top_priority).
        IF lv_top_priority > 0 AND lv_top_priority < ls_config-maxpriority.
          lv_error = '018'. lv_v1 = lv_top_priority. lv_v2 = ls_config-maxpriority.
        ENDIF.
        CLEAR lv_top_priority.
      ENDIF.

      " --- 5) 같은 요청서 안 중복. 오브젝트는 코드가 다르면 다른 규칙이라 겹치지 않는다.
      IF lv_error IS INITIAL.
        LOOP AT lt_sibling INTO DATA(ls_sibling)
             WHERE exemptuuid = ls_item-exemptuuid
               AND itemuuid  <> ls_item-itemuuid
               AND scopetype  = ls_item-scopetype
               AND devclass   = ls_item-devclass
               AND objecttype = ls_item-objecttype
               AND objectname = ls_item-objectname.
          IF ls_item-scopetype = zif_atc_exemption=>scope-pckg
          OR ls_sibling-checkcode = ls_item-checkcode.
            lv_error = '024'. lv_v1 = lv_target.
            EXIT.
          ENDIF.
        ENDLOOP.
      ENDIF.

      " --- 6) 다른 요청서와의 중복. 어느 예외가 실제로 덮는지 추적할 수 없게 된다.
      IF lv_error IS INITIAL
     AND lcl_rules=>has_overlap( is_header = CORRESPONDING #( ls_parent MAPPING FROM ENTITY )
                                 is_item   = CORRESPONDING #( ls_item MAPPING FROM ENTITY ) ) = abap_true.
        lv_error = '013'. lv_v1 = lv_target. lv_v2 = ls_parent-checkclass.
      ENDIF.

      IF lv_error IS INITIAL.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = ls_item-%tky ) TO failed-exemptionitem.
      APPEND VALUE #( %tky        = ls_item-%tky
                      %state_area = 'VALIDATE_TARGET'
                      %path       = VALUE #( exemption-%tky = ls_link-target-%tky )
                      %msg        = new_message( id       = c_msgclass
                                                 number   = lv_error
                                                 severity = if_abap_behv_message=>severity-error
                                                 v1       = lv_v1
                                                 v2       = lv_v2 ) )
             TO reported-exemptionitem.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.


"! 저장 시퀀스. 생성 이력만 남긴다.
"!
"! 표준 예외 저장소 반영은 여기서 하지 않는다. RAP 저장 시퀀스는 COMMIT 도
"! RFC 도 금지하는데, 표준 API 는 내부에서 COMMIT 을 하고 cl_abap_parallel 은
"! aRFC 를 쓴다. 그래서 각 액션이 sync_standard( ) 로 직접 부른다.
CLASS lsc_zr_atcexemption DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.

ENDCLASS.


CLASS lsc_zr_atcexemption IMPLEMENTATION.

  METHOD save_modified.

    " 생성 이력은 저장이 확정된 뒤에 남긴다. draft 생성 시점에 남기면 사용자가
    " Create 를 눌렀다가 취소했을 때 요청서는 없는데 이력만 남는다.
    " 여기는 save 단계라 DB 직접 쓰기가 정상 경로다.
    GET TIME STAMP FIELD DATA(lv_now).

    LOOP AT create-exemption INTO DATA(ls_new).
      INSERT ztatcexemptlog FROM @( VALUE #(
        loguuid    = cl_system_uuid=>create_uuid_x16_static( )
        exemptuuid = ls_new-exemptuuid
        seqnr      = 1
        actioncode = zif_atc_exemption=>logaction-create
        tostat     = zif_atc_exemption=>status-draft
        actionby   = sy-uname
        actionat   = lv_now ) ).
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
