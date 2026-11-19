"! 기술부채 BO 로컬 핸들러
"!
"! 입력 규칙
"!   Debt Level C(비released 사용): 래핑 여부 필수 / D(표준 수정·금지): 래핑 여부 잠금(값 비움)
"!   개선상태 E(예외등록): 부채판단 사유 필수
"!   개발 오브젝트는 시스템에 있어야 함 (유형별로 확인, FM·RFC·PROXY는 확인 안 함)
"!   개발 오브젝트당 한 건. 쓰는 비released 오브젝트는 '비released 사용 내역'(DebtDesc)에 적는다 (필수)
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

    " 엑셀 업로드 (static action). 로직은 이 메서드 하나에
    METHODS uploadexcel FOR MODIFY
      IMPORTING keys FOR ACTION TechDebt~uploadExcel.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR TechDebt RESULT result.

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

  METHOD uploadexcel.

    " 엑셀 업로드 — 템플릿 '업로드' 시트 (1행 컬럼명, 2행 필드명, 3행부터 데이터)
    "   DRM 풀기 → itab 변환 → 행마다 확인 → 에러가 하나라도 있으면 한 건도 안 올림 → 활성 데이터로 생성
    "   채번·기본값·저장 검증은 BO 그대로 탄다 (여기 확인은 행 번호를 붙여 먼저 걸러 주는 것)
    TYPES: BEGIN OF ty_check,
             ok   TYPE abap_bool,
             text TYPE string,
           END OF ty_check,
           tt_check TYPE STANDARD TABLE OF ty_check WITH EMPTY KEY.

    " 엑셀 한 줄 = 템플릿 칸 순서 그대로 (부채 구분 debtcat 은 BO 에 필드를 추가하면 CREATE 에도 넣는다)
    TYPES: BEGIN OF ty_sheet_data,
             sapmodule     TYPE string,
             devid         TYPE string,
             objtype       TYPE string,
             devobj        TYPE string,
             wraptype      TYPE string,
             sysid         TYPE string,
             debtcat       TYPE string,
             debtdesc      TYPE string,
             debtlevel     TYPE string,
             improvestatus TYPE string,
             debtreason    TYPE string,
             bizowner      TYPE string,
           END OF ty_sheet_data.

    DATA lt_sheet   TYPE STANDARD TABLE OF ty_sheet_data WITH EMPTY KEY.
    DATA lt_create  TYPE TABLE FOR CREATE zr_cmsm_debt.
    DATA lt_error   TYPE string_table.
    DATA lt_module  TYPE string_table.
    DATA lt_type    TYPE string_table.
    DATA lt_wrap    TYPE string_table.
    DATA lt_level   TYPE string_table.
    DATA lt_improve TYPE string_table.
    DATA lt_sys     TYPE string_table.
    DATA lt_user    TYPE string_table.

    DATA(ls_key) = keys[ 1 ].

    " 1) DRM 풀고 엑셀 → itab (zcl_cm_common 시그니처가 다르면 이 두 문장만 고친다)
    TRY.
        DATA(lv_xlsx) = zcl_cm_common=>drm_decode( ls_key-%param-attachment ).
        zcl_cm_common=>convert_xlsx_to_itab_v2( EXPORTING iv_xstring = lv_xlsx
                                                IMPORTING et_data    = lt_sheet ).
      CATCH cx_root INTO DATA(lx_file).
        APPEND |엑셀 파일을 읽지 못했습니다: { lx_file->get_text( ) }| TO lt_error.
    ENDTRY.

    " 2) 템플릿 확인: 2행 첫 칸이 필드명
    IF lt_error IS INITIAL AND to_upper( condense( COND string( WHEN lines( lt_sheet ) >= 2 THEN lt_sheet[ 2 ]-sapmodule ) ) ) <> 'SAPMODULE'.
      APPEND `기술부채 업로드 템플릿이 아닙니다. 템플릿의 '업로드' 시트를 그대로 쓰세요.` TO lt_error.
    ENDIF.

    " 3) 행마다 확인 (3행부터, 빈 줄은 건너뜀). 코드·시스템·사용자·저장된 부채는 한 번에 읽어 둔다
    IF lt_error IS INITIAL.
      SELECT Value  FROM zi_cmsm_modulevh    INTO TABLE @lt_module.
      SELECT Value  FROM zi_cmsm_objtypevh   INTO TABLE @lt_type.
      SELECT Value  FROM zi_cmsm_wraptypevh  INTO TABLE @lt_wrap.
      SELECT Value  FROM zi_cmsm_debtlevelvh INTO TABLE @lt_level.
      SELECT Value  FROM zi_cmsm_improvevh   INTO TABLE @lt_improve.
      SELECT SysId  FROM zi_cmsm_sysid       INTO TABLE @lt_sys.
      SELECT UserId FROM zi_cmsm_uservh      INTO TABLE @lt_user.
      " 중복 키 = 오브젝트 유형/개발 오브젝트 (저장된 것 + 위쪽 행)
      SELECT ObjType, DevObj FROM zi_cmsm_debt INTO TABLE @DATA(lt_saved).
      DATA(lt_dup) = VALUE string_table( FOR s IN lt_saved ( |{ s-ObjType }/{ s-DevObj }| ) ).

      LOOP AT lt_sheet INTO DATA(ls_row) FROM 3.
        DATA(lv_row) = sy-tabix.
        IF ls_row IS INITIAL.
          CONTINUE.
        ENDIF.
        ls_row-sapmodule     = to_upper( condense( ls_row-sapmodule ) ).
        ls_row-objtype       = to_upper( condense( ls_row-objtype ) ).
        ls_row-devobj        = to_upper( condense( ls_row-devobj ) ).
        ls_row-wraptype      = to_upper( condense( ls_row-wraptype ) ).
        ls_row-sysid         = to_upper( condense( ls_row-sysid ) ).
        ls_row-debtlevel     = to_upper( condense( ls_row-debtlevel ) ).
        ls_row-improvestatus = to_upper( condense( ls_row-improvestatus ) ).
        ls_row-bizowner      = to_upper( condense( ls_row-bizowner ) ).
        DATA(lv_key) = |{ ls_row-objtype }/{ ls_row-devobj }|.

        DATA(lt_check) = VALUE tt_check(
          ( ok = xsdbool( line_exists( lt_module[ table_line = ls_row-sapmodule ] ) )                     text = |모듈 확인: '{ ls_row-sapmodule }'| )
          ( ok = xsdbool( line_exists( lt_type[ table_line = ls_row-objtype ] ) )                         text = |오브젝트 유형 확인: '{ ls_row-objtype }'| )
          ( ok = xsdbool( ls_row-devobj IS NOT INITIAL )                                                 text = `개발 오브젝트를 넣으세요` )
          ( ok = xsdbool( ls_row-debtlevel <> 'C' OR line_exists( lt_wrap[ table_line = ls_row-wraptype ] ) ) text = |래핑 여부 확인: '{ ls_row-wraptype }' (Debt Level C면 W·D)| )
          ( ok = xsdbool( ls_row-sysid IS INITIAL OR line_exists( lt_sys[ table_line = ls_row-sysid ] ) ) text = |시스템 ID 확인: '{ ls_row-sysid }'| )
          ( ok = xsdbool( ls_row-debtdesc IS NOT INITIAL )                                               text = `비released 사용 내역을 넣으세요` )
          ( ok = xsdbool( line_exists( lt_level[ table_line = ls_row-debtlevel ] ) )                      text = |Debt Level 확인: '{ ls_row-debtlevel }' (C·D)| )
          ( ok = xsdbool( ls_row-improvestatus IS INITIAL OR line_exists( lt_improve[ table_line = ls_row-improvestatus ] ) )
                                                                                                         text = |개선상태 확인: '{ ls_row-improvestatus }' (T·P·C·E)| )
          ( ok = xsdbool( ls_row-improvestatus <> 'E' OR ls_row-debtreason IS NOT INITIAL )              text = `예외등록(E)이면 판단 사유·개선 계획을 넣으세요` )
          ( ok = xsdbool( ls_row-bizowner IS INITIAL OR line_exists( lt_user[ table_line = ls_row-bizowner ] ) ) text = |업무담당자 확인: '{ ls_row-bizowner }' (사용자 ID)| )
          ( ok = xsdbool( NOT line_exists( lt_dup[ table_line = lv_key ] ) )                              text = `같은 유형·개발 오브젝트의 부채가 이미 있거나 위쪽 행에 있습니다` ) ).
        LOOP AT lt_check INTO DATA(ls_check) WHERE ok = abap_false.
          APPEND |{ lv_row }행: { ls_check-text }| TO lt_error.
        ENDLOOP.
        APPEND lv_key TO lt_dup.

        APPEND VALUE #( %cid          = |ROW{ lv_row }|
                        %is_draft     = if_abap_behv=>mk-off
                        SapModule     = ls_row-sapmodule
                        DevId         = ls_row-devid
                        ObjType       = ls_row-objtype
                        DevObj        = ls_row-devobj
                        WrapType      = ls_row-wraptype
                        SysId         = ls_row-sysid
                        DebtDesc      = ls_row-debtdesc
                        DebtLevel     = ls_row-debtlevel
                        ImproveStatus = ls_row-improvestatus
                        DebtReason    = ls_row-debtreason
                        BizOwner      = ls_row-bizowner ) TO lt_create.
      ENDLOOP.

      IF lt_error IS INITIAL AND lt_create IS INITIAL.
        APPEND `올릴 데이터가 없습니다 (3행부터 적습니다).` TO lt_error.
      ENDIF.
    ENDIF.

    " 4) 에러가 있으면 한 건도 안 올리고 행별 에러를 보여 준다 (100개까지)
    IF lt_error IS NOT INITIAL.
      IF lines( lt_error ) > 100.
        DELETE lt_error FROM 101.
        APPEND `에러가 많아 100개까지만 보여 줍니다.` TO lt_error.
      ENDIF.
      LOOP AT lt_error INTO DATA(lv_error).
        APPEND VALUE #( %cid = ls_key-%cid
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = lv_error ) ) TO reported-techdebt.
      ENDLOOP.
      APPEND VALUE #( %cid = ls_key-%cid ) TO failed-techdebt.
      RETURN.
    ENDIF.

    " 5) 등록 (드래프트 없이 바로 활성 데이터)
    MODIFY ENTITIES OF zr_cmsm_debt IN LOCAL MODE
      ENTITY TechDebt
        CREATE FIELDS ( SapModule DevId ObjType DevObj WrapType SysId DebtDesc DebtLevel ImproveStatus DebtReason BizOwner ) WITH lt_create
      FAILED failed
      REPORTED reported.

    APPEND VALUE #( %cid = ls_key-%cid
                    %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                  text     = |{ lines( lt_create ) }건을 올렸습니다.| ) ) TO reported-techdebt.

  ENDMETHOD.


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
        FIELDS ( SapModule ObjType DevObj DebtDesc DebtLevel
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
      IF ls_debt-DebtDesc IS INITIAL.
        APPEND VALUE #( field = `DEBTDESC`  text = `사용한 비released 오브젝트를 입력하세요.` ) TO lt_missing.
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
        FIELDS ( ObjType DevObj ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_debt).

    LOOP AT lt_debt INTO DATA(ls_debt).

      APPEND VALUE #( %tky        = ls_debt-%tky
                      %state_area = 'DUPLICATE' ) TO reported-techdebt.

      IF ls_debt-DevObj IS INITIAL.
        CONTINUE.
      ENDIF.

      " 개발 오브젝트당 한 건: 같은 유형·같은 개발 오브젝트의 저장된 부채
      SELECT SINGLE debtid FROM ztcmsm00230
        WHERE debtuuid <> @ls_debt-DebtUuid
          AND objtype  =  @ls_debt-ObjType
          AND devobj   =  @ls_debt-DevObj
        INTO @DATA(lv_dup_id).

      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = ls_debt-%tky ) TO failed-techdebt.
      APPEND VALUE #( %tky            = ls_debt-%tky
                      %state_area     = 'DUPLICATE'
                      %element-DevObj = if_abap_behv=>mk-on
                      %msg            = new_message_with_text(
                                          severity = if_abap_behv_message=>severity-error
                                          text     = COND string( WHEN lv_dup_id IS INITIAL
                                                                  THEN `이 개발 오브젝트의 기술부채가 이미 있습니다. 기존 건의 비released 사용 내역에 추가하세요.`
                                                                  ELSE |이 개발 오브젝트의 기술부채가 이미 있습니다 ({ lv_dup_id }). 기존 건의 비released 사용 내역에 추가하세요.| ) ) )
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
