"! 기술부채 BO 로컬 핸들러
"!
"! 입력 규칙
"!   Debt Level C(비released 사용): 래핑 여부 필수 / D(표준 수정·금지): 래핑 여부 잠금(값 비움)
"!   개선상태 E(예외등록): 부채판단 사유 필수
"!   개발 오브젝트는 시스템에 있어야 함 (유형별로 확인, FM·RFC·PROXY는 확인 안 함)
"!   개발 오브젝트당 한 건. 쓰는 비released 오브젝트는 '비released 사용 내역'(DebtDesc)에 적는다 (필수)
CLASS lhc_techdebt DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PUBLIC SECTION.
    " 엑셀 업로드로 만든 건수 — uploadexcel 이 넣고, saver(save_modified)가 저장 뒤 성공 메시지에 쓴다
    CLASS-DATA gv_upload_count TYPE i.

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
    "   DRM 풀기 → itab 변환 → 중복 확인 → 중복이 하나라도 있으면 한 건도 안 올림 → 생성
    "   필수·코드값 등 나머지는 저장할 때 BO 검증이 막는다

    " 엑셀 한 줄 = 템플릿 칸 순서 그대로 (debtcat 부채 구분은 BO 에 필드가 생기면 CREATE 에도 넣는다)
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

    DATA lt_sheet  TYPE STANDARD TABLE OF ty_sheet_data WITH EMPTY KEY.
    DATA lt_create TYPE TABLE FOR CREATE zr_cmsm_debt.
    DATA lt_error  TYPE string_table.

    DATA(ls_key) = keys[ 1 ].

    " 1) DRM 풀고 엑셀 → itab (zcl_cm_common 시그니처가 다르면 이 두 문장만 고친다)
    TRY.
        DATA(lv_xlsx) = zcl_cm_common=>drm_decode( ls_key-%param-attachment ).
        zcl_cm_common=>convert_xlsx_to_itab_v2( EXPORTING iv_xstring = lv_xlsx
                                                IMPORTING et_data    = lt_sheet ).
      CATCH cx_root INTO DATA(lx_file).
        APPEND |엑셀 파일을 읽지 못했습니다: { lx_file->get_text( ) }| TO lt_error.
    ENDTRY.

    IF lt_error IS INITIAL.
      " 2) 중복 키 = 오브젝트 유형/개발 오브젝트 (저장된 것 + 위쪽 행)
      SELECT ObjType, DevObj FROM zi_cmsm_debt INTO TABLE @DATA(lt_saved).
      DATA(lt_dup) = VALUE string_table( FOR s IN lt_saved ( |{ s-ObjType }/{ s-DevObj }| ) ).

      " 3) 3행부터 한 줄씩 (빈 줄은 건너뜀). 코드·이름은 대문자로
      LOOP AT lt_sheet INTO DATA(ls_row) FROM 3.
        DATA(lv_row) = sy-tabix.
        IF ls_row IS INITIAL.
          CONTINUE.
        ENDIF.

        APPEND VALUE #( %cid          = |ROW{ lv_row }|
                        %is_draft     = if_abap_behv=>mk-off
                        SapModule     = to_upper( condense( ls_row-sapmodule ) )
                        DevId         = ls_row-devid
                        ObjType       = to_upper( condense( ls_row-objtype ) )
                        DevObj        = to_upper( condense( ls_row-devobj ) )
                        WrapType      = to_upper( condense( ls_row-wraptype ) )
                        SysId         = to_upper( condense( ls_row-sysid ) )
                        DebtDesc      = ls_row-debtdesc
                        DebtLevel     = to_upper( condense( ls_row-debtlevel ) )
                        ImproveStatus = to_upper( condense( ls_row-improvestatus ) )
                        DebtReason    = ls_row-debtreason
                        BizOwner      = to_upper( condense( ls_row-bizowner ) ) ) TO lt_create REFERENCE INTO DATA(lr_new).
        " 중복이면 에러 (저장된 것·위쪽 행과 같은 키)
        DATA(lv_key) = |{ lr_new->ObjType }/{ lr_new->DevObj }|.
        IF line_exists( lt_dup[ table_line = lv_key ] ).
          APPEND |{ lv_row }행: 같은 유형·개발 오브젝트의 부채가 이미 있거나 위쪽 행에 있습니다 ({ lv_key })| TO lt_error.
        ENDIF.
        APPEND lv_key TO lt_dup.
      ENDLOOP.

      IF lt_create IS INITIAL.
        APPEND `올릴 데이터가 없습니다 (3행부터 적습니다).` TO lt_error.
      ENDIF.
    ENDIF.

    " 에러가 있으면 한 건도 안 올린다
    IF lt_error IS NOT INITIAL.
      LOOP AT lt_error INTO DATA(lv_error).
        APPEND VALUE #( %cid = ls_key-%cid
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = lv_error ) ) TO reported-techdebt.
      ENDLOOP.
      APPEND VALUE #( %cid = ls_key-%cid ) TO failed-techdebt.
      RETURN.
    ENDIF.

    " 등록 (드래프트 없이 바로 활성 데이터). 채번·기본값·저장 검증은 BO 그대로
    "   성공 메시지는 여기서 안 띄운다: 이 시점엔 저장 검증 전이라, 검증에 걸리면 성공·실패가 같이 나온다
    MODIFY ENTITIES OF zr_cmsm_debt IN LOCAL MODE
      ENTITY TechDebt
        CREATE FIELDS ( SapModule DevId ObjType DevObj WrapType SysId DebtDesc DebtLevel ImproveStatus DebtReason BizOwner ) WITH lt_create
      FAILED failed
      REPORTED reported.

    " 성공 메시지는 saver 가 저장이 끝난 뒤에 띄운다 (여기선 건수만 남김)
    IF failed IS INITIAL.
      gv_upload_count = lines( lt_create ).
    ENDIF.

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


"! 저장 뒤 처리 — 엑셀 업로드 성공 메시지만 (BDEF: managed with additional save)
CLASS lsc_zr_cmsm_debt DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.

ENDCLASS.


CLASS lsc_zr_cmsm_debt IMPLEMENTATION.

  METHOD save_modified.

    " 엑셀 업로드가 저장까지 끝났을 때만 성공 메시지 (저장 검증에 걸리면 save_modified 까지 안 온다)
    "   gv_upload_count 는 uploadexcel 액션에서만 채워지니, 화면에서 만들고 저장할 땐 0 이라 안 뜬다
    IF lhc_techdebt=>gv_upload_count > 0.
      " 특정 건에 붙지 않는 메시지라 %other 로 (화면에는 성공 토스트)
      APPEND new_message_with_text( severity = if_abap_behv_message=>severity-success
                                    text     = |업로드 완료 ({ lhc_techdebt=>gv_upload_count }건)| ) TO reported-%other.
      CLEAR lhc_techdebt=>gv_upload_count.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
