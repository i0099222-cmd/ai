"! 기술부채 BO 로컬 핸들러
"!
"! 입력 규칙
"!   Debt Level C(비released 사용): 래핑 여부 필수 / D(표준 수정·금지): 래핑 여부 잠금(값 비움)
"!   개선상태 E(예외등록): 부채판단 사유 필수
"!   개발 오브젝트는 시스템에 있어야 함 (유형별로 확인, FM·RFC·PROXY는 확인 안 함)
"!   같은 개발 오브젝트 + 같은 비released 대상은 한 번만
"!
"! 복사(copyDebt): 같은 개발 오브젝트의 다른 비released 대상을 등록할 때 쓴다.
"!   비released 대상 이름은 비우고(새로 입력), 개선상태는 개선대상(T)으로 새로 시작, ID는 저장할 때 새로 채번
CLASS lhc_techdebt DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF gc_level,
        unreleased TYPE c LENGTH 1 VALUE 'C',
        forbidden  TYPE c LENGTH 1 VALUE 'D',
      END OF gc_level,

      BEGIN OF gc_improve,
        target    TYPE c LENGTH 1 VALUE 'T',
        exception TYPE c LENGTH 1 VALUE 'E',
      END OF gc_improve.

    TYPES:
      BEGIN OF ty_missing,
        field TYPE string,
        text  TYPE string,
      END OF ty_missing,
      tt_missing TYPE STANDARD TABLE OF ty_missing WITH EMPTY KEY,

      ty_tadir_type  TYPE c LENGTH 4,
      tt_tadir_range TYPE RANGE OF ty_tadir_type.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR TechDebt RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR TechDebt RESULT result.

    METHODS copydebt FOR MODIFY
      IMPORTING keys FOR ACTION TechDebt~copyDebt.

    METHODS setinitialvalues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR TechDebt~setInitialValues.

    METHODS clearwraptype FOR DETERMINE ON MODIFY
      IMPORTING keys FOR TechDebt~clearWrapType.

    METHODS setdebtid FOR DETERMINE ON SAVE
      IMPORTING keys FOR TechDebt~setDebtId.

    METHODS validatemandatory FOR VALIDATE ON SAVE
      IMPORTING keys FOR TechDebt~validateMandatory.

    METHODS validatedevobj FOR VALIDATE ON SAVE
      IMPORTING keys FOR TechDebt~validateDevObj.

    METHODS validateduplicate FOR VALIDATE ON SAVE
      IMPORTING keys FOR TechDebt~validateDuplicate.

    "! 개발 오브젝트가 시스템에 있는지 (고객 오브젝트 디렉터리).
    "! 오브젝트 디렉터리 이름으로 확인할 수 없는 유형(FM·RFC·PROXY)은 있다고 본다
    METHODS obj_exists
      IMPORTING iv_type          TYPE string
                iv_name          TYPE string
      RETURNING VALUE(rv_exists) TYPE abap_bool.

ENDCLASS.


CLASS lhc_techdebt IMPLEMENTATION.

  METHOD get_global_authorizations.
    " strict 모드라 권한 제어 선언이 필수라서 둔 자리.
    " result를 비워두면 전부 허용된다. 권한 오브젝트/DCL 정할 때 채운다.
  ENDMETHOD.


  METHOD get_instance_features.

    READ ENTITIES OF zr_cmsm_debt IN LOCAL MODE
      ENTITY TechDebt
        FIELDS ( DebtLevel ImproveStatus ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_debt)
      FAILED failed.

    result = VALUE #( FOR ls_debt IN lt_debt
                      ( %tky              = ls_debt-%tky
                        %field-WrapType   = COND #( WHEN ls_debt-DebtLevel = gc_level-unreleased
                                                    THEN if_abap_behv=>fc-f-mandatory
                                                    ELSE if_abap_behv=>fc-f-read_only )
                        %field-DebtReason = COND #( WHEN ls_debt-ImproveStatus = gc_improve-exception
                                                    THEN if_abap_behv=>fc-f-mandatory
                                                    ELSE if_abap_behv=>fc-f-unrestricted ) ) ).

  ENDMETHOD.


  METHOD copydebt.

    DATA lt_create TYPE TABLE FOR CREATE zr_cmsm_debt.

    READ ENTITIES OF zr_cmsm_debt IN LOCAL MODE
      ENTITY TechDebt
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_debt)
      FAILED failed.

    LOOP AT lt_debt INTO DATA(ls_debt).

      DATA(ls_key) = keys[ KEY entity %key = ls_debt-%key ].

      APPEND VALUE #( %cid      = ls_key-%cid
                      %is_draft = ls_key-%param-%is_draft
                      %data     = CORRESPONDING #( ls_debt EXCEPT DebtUuid DebtId StdName ImproveStatus
                                                              CreatedBy CreatedAt LastChangedBy LastChangedAt
                                                              LocalLastChangedAt ) )
             TO lt_create ASSIGNING FIELD-SYMBOL(<ls_create>).

      " 새로 찾은 사용처라 개선대상부터
      <ls_create>-ImproveStatus = gc_improve-target.

    ENDLOOP.

    IF lt_create IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_cmsm_debt IN LOCAL MODE
      ENTITY TechDebt
        CREATE FIELDS ( SapModule DevId ObjType DevObj WrapType StdType SysId
                        DebtDesc DebtLevel ImproveStatus DebtReason BizOwner )
        WITH lt_create
      MAPPED DATA(ls_mapped)
      FAILED DATA(ls_failed)
      REPORTED DATA(ls_reported).

    mapped-techdebt = ls_mapped-techdebt.
    APPEND LINES OF ls_failed-techdebt   TO failed-techdebt.
    APPEND LINES OF ls_reported-techdebt TO reported-techdebt.

  ENDMETHOD.


  METHOD setinitialvalues.

    READ ENTITIES OF zr_cmsm_debt IN LOCAL MODE
      ENTITY TechDebt
        FIELDS ( ImproveStatus ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_debt).

    DELETE lt_debt WHERE ImproveStatus IS NOT INITIAL.
    IF lt_debt IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_cmsm_debt IN LOCAL MODE
      ENTITY TechDebt
        UPDATE FIELDS ( ImproveStatus )
        WITH VALUE #( FOR ls_debt IN lt_debt
                      ( %tky          = ls_debt-%tky
                        ImproveStatus = gc_improve-target ) ).

  ENDMETHOD.


  METHOD clearwraptype.

    READ ENTITIES OF zr_cmsm_debt IN LOCAL MODE
      ENTITY TechDebt
        FIELDS ( DebtLevel WrapType ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_debt).

    " 표준 수정·금지(D)나 미선택이면 래핑 여부는 의미가 없다
    DELETE lt_debt WHERE DebtLevel = gc_level-unreleased OR WrapType IS INITIAL.
    IF lt_debt IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_cmsm_debt IN LOCAL MODE
      ENTITY TechDebt
        UPDATE FIELDS ( WrapType )
        WITH VALUE #( FOR ls_debt IN lt_debt
                      ( %tky     = ls_debt-%tky
                        WrapType = '' ) ).

  ENDMETHOD.


  METHOD setdebtid.

    DATA lt_update TYPE TABLE FOR UPDATE zr_cmsm_debt.

    READ ENTITIES OF zr_cmsm_debt IN LOCAL MODE
      ENTITY TechDebt
        FIELDS ( DebtId ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_debt).

    DELETE lt_debt WHERE DebtId IS NOT INITIAL.

    LOOP AT lt_debt INTO DATA(ls_debt).

      DATA(lv_id) = zcl_cmsm_display_id=>next( zcl_cmsm_display_id=>gc_range-tech_debt ).

      IF lv_id IS INITIAL.
        " 저장은 막지 않는다. 번호 범위를 고친 뒤 다시 저장하면 채번된다
        APPEND VALUE #( %tky = ls_debt-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-warning
                                 text     = 'ID를 채번하지 못했습니다. 번호 범위 ZCMSM_DOID 구간 05를 확인하세요.' ) )
               TO reported-techdebt.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky   = ls_debt-%tky
                      DebtId = lv_id ) TO lt_update.

    ENDLOOP.

    IF lt_update IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_cmsm_debt IN LOCAL MODE
      ENTITY TechDebt
        UPDATE FIELDS ( DebtId ) WITH lt_update.

  ENDMETHOD.


  METHOD validatemandatory.

    READ ENTITIES OF zr_cmsm_debt IN LOCAL MODE
      ENTITY TechDebt
        FIELDS ( SapModule ObjType DevObj StdType StdName DebtLevel
                 WrapType ImproveStatus DebtReason ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_debt).

    LOOP AT lt_debt INTO DATA(ls_debt).

      " 이전 검사 메시지 지우기
      APPEND VALUE #( %tky        = ls_debt-%tky
                      %state_area = 'MANDATORY' ) TO reported-techdebt.

      DATA(lt_missing) = VALUE tt_missing( ).

      IF ls_debt-SapModule IS INITIAL.
        APPEND VALUE #( field = `SAPMODULE` text = `모듈을 선택하세요.` ) TO lt_missing.
      ENDIF.
      IF ls_debt-ObjType IS INITIAL.
        APPEND VALUE #( field = `OBJTYPE`   text = `오브젝트 유형을 선택하세요.` ) TO lt_missing.
      ENDIF.
      IF ls_debt-DevObj IS INITIAL.
        APPEND VALUE #( field = `DEVOBJ`    text = `개발 오브젝트를 입력하세요.` ) TO lt_missing.
      ENDIF.
      IF ls_debt-StdType IS INITIAL.
        APPEND VALUE #( field = `STDTYPE`   text = `비released 대상 유형을 선택하세요.` ) TO lt_missing.
      ENDIF.
      IF ls_debt-StdName IS INITIAL.
        APPEND VALUE #( field = `STDNAME`   text = `비released 대상을 입력하세요.` ) TO lt_missing.
      ENDIF.
      IF ls_debt-DebtLevel IS INITIAL.
        APPEND VALUE #( field = `DEBTLEVEL` text = `Debt Level을 선택하세요.` ) TO lt_missing.
      ENDIF.
      IF ls_debt-DebtLevel = gc_level-unreleased AND ls_debt-WrapType IS INITIAL.
        APPEND VALUE #( field = `WRAPTYPE`  text = `Debt Level C면 래핑 여부를 선택하세요.` ) TO lt_missing.
      ENDIF.
      IF ls_debt-ImproveStatus = gc_improve-exception AND ls_debt-DebtReason IS INITIAL.
        APPEND VALUE #( field = `DEBTREASON` text = `예외등록이면 부채판단 사유를 입력하세요.` ) TO lt_missing.
      ENDIF.

      IF lt_missing IS INITIAL.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = ls_debt-%tky ) TO failed-techdebt.

      LOOP AT lt_missing INTO DATA(ls_missing).
        APPEND VALUE #( %tky        = ls_debt-%tky
                        %state_area = 'MANDATORY'
                        %msg        = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text     = ls_missing-text ) )
               TO reported-techdebt ASSIGNING FIELD-SYMBOL(<ls_reported>).
        " 해당 입력칸을 빨갛게
        ASSIGN COMPONENT ls_missing-field OF STRUCTURE <ls_reported>-%element TO FIELD-SYMBOL(<lv_element>).
        IF sy-subrc = 0.
          <lv_element> = if_abap_behv=>mk-on.
        ENDIF.
      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.


  METHOD validatedevobj.

    READ ENTITIES OF zr_cmsm_debt IN LOCAL MODE
      ENTITY TechDebt
        FIELDS ( ObjType DevObj ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_debt).

    LOOP AT lt_debt INTO DATA(ls_debt).

      APPEND VALUE #( %tky        = ls_debt-%tky
                      %state_area = 'DEVOBJ' ) TO reported-techdebt.

      IF ls_debt-DevObj IS INITIAL OR ls_debt-ObjType IS INITIAL.
        CONTINUE.
      ENDIF.

      IF obj_exists( iv_type = CONV #( ls_debt-ObjType ) iv_name = CONV #( ls_debt-DevObj ) ) = abap_false.
        APPEND VALUE #( %tky = ls_debt-%tky ) TO failed-techdebt.
        APPEND VALUE #( %tky            = ls_debt-%tky
                        %state_area     = 'DEVOBJ'
                        %element-DevObj = if_abap_behv=>mk-on
                        %msg            = new_message_with_text(
                                            severity = if_abap_behv_message=>severity-error
                                            text     = |{ ls_debt-DevObj }({ ls_debt-ObjType })은(는) 시스템에 없습니다. 이름과 유형을 확인하세요.| ) )
               TO reported-techdebt.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD validateduplicate.

    READ ENTITIES OF zr_cmsm_debt IN LOCAL MODE
      ENTITY TechDebt
        FIELDS ( DevObj StdType StdName ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_debt).

    LOOP AT lt_debt INTO DATA(ls_debt).

      APPEND VALUE #( %tky        = ls_debt-%tky
                      %state_area = 'DUPLICATE' ) TO reported-techdebt.

      IF ls_debt-DevObj IS INITIAL OR ls_debt-StdName IS INITIAL.
        CONTINUE.
      ENDIF.

      " 저장된 다른 부채 중 같은 개발 오브젝트가 같은 비released 대상을 쓰는 건
      SELECT SINGLE debtid FROM ztcmsm00230
        WHERE debtuuid <> @ls_debt-DebtUuid
          AND devobj   =  @ls_debt-DevObj
          AND stdtype  =  @ls_debt-StdType
          AND stdname  =  @ls_debt-StdName
        INTO @DATA(lv_dup_id).

      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = ls_debt-%tky ) TO failed-techdebt.
      APPEND VALUE #( %tky             = ls_debt-%tky
                      %state_area      = 'DUPLICATE'
                      %element-StdName = if_abap_behv=>mk-on
                      %msg             = new_message_with_text(
                                           severity = if_abap_behv_message=>severity-error
                                           text     = COND string( WHEN lv_dup_id IS INITIAL
                                                                   THEN `같은 기술부채가 이미 등록돼 있습니다.`
                                                                   ELSE |같은 기술부채가 이미 등록돼 있습니다 ({ lv_dup_id }).| ) ) )
             TO reported-techdebt.

    ENDLOOP.

  ENDMETHOD.


  METHOD obj_exists.

    DATA lt_range TYPE tt_tadir_range.

    rv_exists = abap_true.

    DATA(lv_name) = to_upper( condense( iv_name ) ).
    IF lv_name IS INITIAL.
      RETURN.
    ENDIF.

    " 오브젝트 유형 → 오브젝트 디렉터리(TADIR) 유형
    CASE iv_type.
      WHEN `CLASS`.
        lt_range = VALUE #( ( sign = 'I' option = 'EQ' low = 'CLAS' ) ).
      WHEN `TABLE`.
        lt_range = VALUE #( ( sign = 'I' option = 'EQ' low = 'TABL' ) ).
      WHEN `CDS`.
        lt_range = VALUE #( ( sign = 'I' option = 'EQ' low = 'DDLS' ) ).
      WHEN `BO`.
        lt_range = VALUE #( ( sign = 'I' option = 'EQ' low = 'BDEF' ) ).
      WHEN `ACTION`.
        " BO.ACTION 형태 → BO(행위 정의)만 확인
        lt_range = VALUE #( ( sign = 'I' option = 'EQ' low = 'BDEF' ) ).
        lv_name  = segment( val = lv_name index = 1 sep = `.` ).
      WHEN `VH`.
        lt_range = VALUE #( ( sign = 'I' option = 'EQ' low = 'DDLS' )
                            ( sign = 'I' option = 'EQ' low = 'SHLP' ) ).
      WHEN `SRVB`.
        lt_range = VALUE #( ( sign = 'I' option = 'EQ' low = 'SRVB' ) ).
      WHEN `TCODE`.
        lt_range = VALUE #( ( sign = 'I' option = 'EQ' low = 'TRAN' ) ).
      WHEN OTHERS.
        " FM·RFC·PROXY: 오브젝트 디렉터리 이름으로는 확인할 수 없어 통과
        RETURN.
    ENDCASE.

    rv_exists = abap_false.

    SELECT SINGLE @abap_true FROM i_custabapobjdirectoryentry
      WHERE abapobject     =  @lv_name
        AND abapobjecttype IN @lt_range
      INTO @rv_exists.

  ENDMETHOD.

ENDCLASS.
