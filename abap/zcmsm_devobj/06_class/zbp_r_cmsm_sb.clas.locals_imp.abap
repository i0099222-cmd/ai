"! 엑셀 업로드 건수 — uploadexcel 이 넣고, saver(save_modified)가 저장 뒤 '업로드 완료'를 띄울지 본다
"! 핸들러·saver 둘 다 쓰니 Local Types 맨 위에 둔다 (위에 있어야 둘 다 찾는다)
CLASS lcl_upload DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-DATA count TYPE i.
ENDCLASS.

CLASS lcl_upload IMPLEMENTATION.
ENDCLASS.


"! OData 서비스 BO 로컬 핸들러
"!
"! - 시스템에 없는 서비스 바인딩은 등록 불가, 같은 시스템 ID에 같은 바인딩은 한 번만
"! - 테스트 파일을 올리면 올린 사람·일시 자동, 지우면 같이 비움. 10MB까지
CLASS lhc_odataservice DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    CONSTANTS:
      " 테스트 파일 최대 크기 10MB
      gc_max_file_size TYPE i VALUE 10485760.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR ODataService RESULT result.

    " 담당자(OwnerId)만 편집·삭제
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR ODataService RESULT result.

    " 엑셀 업로드 (static action). 로직은 이 메서드 하나에
    METHODS uploadexcel FOR MODIFY
      IMPORTING keys FOR ACTION ODataService~uploadExcel.

    METHODS setinitialvalues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ODataService~setInitialValues.

    METHODS settestinfo FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ODataService~setTestInfo.

    METHODS setsbid FOR DETERMINE ON SAVE
      IMPORTING keys FOR ODataService~setSbId.

    METHODS validatemandatory FOR VALIDATE ON SAVE
      IMPORTING keys FOR ODataService~validateMandatory.

    METHODS validatesrvbname FOR VALIDATE ON SAVE
      IMPORTING keys FOR ODataService~validateSrvbName.

    METHODS validatetestfile FOR VALIDATE ON SAVE
      IMPORTING keys FOR ODataService~validateTestFile.

    "! 서비스 바인딩이 시스템에 있는지 (고객 오브젝트 디렉터리)
    METHODS srvb_exists
      IMPORTING iv_name          TYPE string
      RETURNING VALUE(rv_exists) TYPE abap_bool.

ENDCLASS.


CLASS lhc_odataservice IMPLEMENTATION.

  METHOD uploadexcel.

    " 엑셀 업로드 — 템플릿 '업로드' 시트 (1행 컬럼명, 2행 필드명, 3행부터 데이터)
    "   DRM 풀기 → itab 변환 → 중복 확인 → 중복이 하나라도 있으면 한 건도 안 올림 → 생성
    "   필수·코드값 등 나머지는 저장할 때 BO 검증이 막는다

    " 엑셀 한 줄 = 템플릿 칸 순서 그대로
    TYPES: BEGIN OF ty_sheet_data,
             srvbname    TYPE string,
             sysid       TYPE string,
             sapmodule   TYPE string,
             description TYPE string,
             ownerid     TYPE string,
             objcreator  TYPE string,
             reqid       TYPE string,
           END OF ty_sheet_data.

    DATA lt_sheet  TYPE STANDARD TABLE OF ty_sheet_data WITH EMPTY KEY.
    DATA lt_create TYPE TABLE FOR CREATE zr_cmsm_sb.
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
      " 2) 중복 키 = 시스템 ID/Service Binding (저장된 것 + 위쪽 행)
      SELECT SysId, SrvbName FROM zi_cmsm_sb INTO TABLE @DATA(lt_saved).
      DATA(lt_dup) = VALUE string_table( FOR s IN lt_saved ( |{ s-SysId }/{ s-SrvbName }| ) ).

      " 3) 3행부터 한 줄씩 (빈 줄은 건너뜀). 코드·이름은 대문자로
      LOOP AT lt_sheet INTO DATA(ls_row) FROM 3.
        DATA(lv_row) = sy-tabix.
        IF ls_row IS INITIAL.
          CONTINUE.
        ENDIF.

        APPEND VALUE #( %cid        = |ROW{ lv_row }|
                        %is_draft   = if_abap_behv=>mk-off
                        SrvbName    = to_upper( condense( ls_row-srvbname ) )
                        SysId       = to_upper( condense( ls_row-sysid ) )
                        SapModule   = to_upper( condense( ls_row-sapmodule ) )
                        Description = ls_row-description
                        OwnerId     = to_upper( condense( ls_row-ownerid ) )
                        ObjCreator  = ls_row-objcreator
                        ReqId       = to_upper( condense( ls_row-reqid ) ) ) TO lt_create REFERENCE INTO DATA(lr_new).
        " 중복이면 에러 (저장된 것·위쪽 행과 같은 키)
        DATA(lv_key) = |{ lr_new->SysId }/{ lr_new->SrvbName }|.
        IF line_exists( lt_dup[ table_line = lv_key ] ).
          APPEND |{ lv_row }행: 이미 등록됐거나 위쪽 행과 같은 Service Binding입니다 ({ lv_key })| TO lt_error.
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
                                                      text     = lv_error ) ) TO reported-odataservice.
      ENDLOOP.
      APPEND VALUE #( %cid = ls_key-%cid ) TO failed-odataservice.
      RETURN.
    ENDIF.

    " 등록 (드래프트 없이 바로 활성 데이터). 채번·기본값·저장 검증은 BO 그대로
    "   성공 메시지는 여기서 안 띄운다: 이 시점엔 저장 검증 전이라, 검증에 걸리면 성공·실패가 같이 나온다
    MODIFY ENTITIES OF zr_cmsm_sb IN LOCAL MODE
      ENTITY ODataService
        CREATE FIELDS ( SrvbName SysId SapModule Description OwnerId ObjCreator ReqId ) WITH lt_create
      FAILED failed
      REPORTED reported.

    " 성공 메시지는 saver 가 저장이 끝난 뒤에 띄운다 (여기선 건수만 남김)
    IF failed IS INITIAL.
      lcl_upload=>count = lines( lt_create ).
    ENDIF.

  ENDMETHOD.


  METHOD get_global_authorizations.
    " strict 모드라 권한 제어 선언이 필수라서 둔 자리.
    " result를 비워두면 전부 허용된다. 권한 오브젝트/DCL 정할 때 채운다.
  ENDMETHOD.


  METHOD get_instance_features.

    " 담당자만 편집(Edit)·삭제 가능. 담당자가 비어 있으면 누구나 (예전 데이터가 잠기지 않게)
    " 편집 중인 초안은 막지 않는다 — 초안은 이미 편집을 시작한 본인 것이고, 담당자를 바꿔도 마저 저장할 수 있게
    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    READ ENTITIES OF zr_cmsm_sb IN LOCAL MODE
      ENTITY ODataService
        FIELDS ( OwnerId ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_sb)
      FAILED failed.

    LOOP AT lt_sb INTO DATA(ls_sb).
      DATA(lv_fc) = COND #( WHEN ls_sb-%is_draft = if_abap_behv=>mk-on
                              OR ls_sb-OwnerId IS INITIAL
                              OR ls_sb-OwnerId = lv_user
                            THEN if_abap_behv=>fc-o-enabled
                            ELSE if_abap_behv=>fc-o-disabled ).
      APPEND VALUE #( %tky         = ls_sb-%tky
                      %update      = lv_fc
                      %delete      = lv_fc
                      %action-Edit = lv_fc ) TO result.     " 화면 '편집' 버튼
    ENDLOOP.

  ENDMETHOD.


  METHOD setinitialvalues.

    READ ENTITIES OF zr_cmsm_sb IN LOCAL MODE
      ENTITY ODataService
        FIELDS ( OwnerId ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_sb).

    DELETE lt_sb WHERE OwnerId IS NOT INITIAL.
    IF lt_sb IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    MODIFY ENTITIES OF zr_cmsm_sb IN LOCAL MODE
      ENTITY ODataService
        UPDATE FIELDS ( OwnerId )
        WITH VALUE #( FOR ls_sb IN lt_sb
                      ( %tky    = ls_sb-%tky
                        OwnerId = lv_user ) ).

  ENDMETHOD.


  METHOD settestinfo.

    DATA lv_now TYPE timestampl.

    READ ENTITIES OF zr_cmsm_sb IN LOCAL MODE
      ENTITY ODataService
        FIELDS ( TestFile ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_sb).

    IF lt_sb IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_now.

    " 파일이 있으면 지금 사용자·시각, 지웠으면 비움
    MODIFY ENTITIES OF zr_cmsm_sb IN LOCAL MODE
      ENTITY ODataService
        UPDATE FIELDS ( TestBy TestAt )
        WITH VALUE #( FOR ls_sb IN lt_sb
                      ( %tky   = ls_sb-%tky
                        TestBy = COND #( WHEN ls_sb-TestFile IS NOT INITIAL THEN lv_user )
                        TestAt = COND #( WHEN ls_sb-TestFile IS NOT INITIAL THEN lv_now ) ) ).

  ENDMETHOD.


  METHOD setsbid.

    DATA lt_update TYPE TABLE FOR UPDATE zr_cmsm_sb.

    READ ENTITIES OF zr_cmsm_sb IN LOCAL MODE
      ENTITY ODataService
        FIELDS ( SbId ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_sb).

    DELETE lt_sb WHERE SbId IS NOT INITIAL.

    LOOP AT lt_sb INTO DATA(ls_sb).

      DATA(lv_id) = zcl_cmsm_display_id=>next( zcl_cmsm_display_id=>gc_range-odata_service ).

      IF lv_id IS INITIAL.
        " 저장은 막지 않는다. 번호 범위를 고친 뒤 다시 저장하면 채번된다
        APPEND VALUE #( %tky = ls_sb-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-warning
                                 text     = '등록번호를 채번하지 못했습니다. 번호 범위 ZCMSM_DOID 구간 04를 확인하세요.' ) )
               TO reported-odataservice.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = ls_sb-%tky
                      SbId = lv_id ) TO lt_update.

    ENDLOOP.

    IF lt_update IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_cmsm_sb IN LOCAL MODE
      ENTITY ODataService
        UPDATE FIELDS ( SbId ) WITH lt_update.

  ENDMETHOD.


  METHOD validatemandatory.

    READ ENTITIES OF zr_cmsm_sb IN LOCAL MODE
      ENTITY ODataService
        FIELDS ( SrvbName SapModule ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_sb).

    LOOP AT lt_sb INTO DATA(ls_sb).

      " 이전 검사 메시지 지우기
      APPEND VALUE #( %tky        = ls_sb-%tky
                      %state_area = 'MANDATORY' ) TO reported-odataservice.

      DATA(lv_failed) = abap_false.

      IF ls_sb-SrvbName IS INITIAL.
        lv_failed = abap_true.
        APPEND VALUE #( %tky              = ls_sb-%tky
                        %state_area       = 'MANDATORY'
                        %element-SrvbName = if_abap_behv=>mk-on
                        %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = 'Service Binding을 입력하세요.' ) )
               TO reported-odataservice.
      ENDIF.

      IF ls_sb-SapModule IS INITIAL.
        lv_failed = abap_true.
        APPEND VALUE #( %tky               = ls_sb-%tky
                        %state_area        = 'MANDATORY'
                        %element-SapModule = if_abap_behv=>mk-on
                        %msg               = new_message_with_text(
                                               severity = if_abap_behv_message=>severity-error
                                               text     = '모듈을 선택하세요.' ) )
               TO reported-odataservice.
      ENDIF.

      IF lv_failed = abap_true.
        APPEND VALUE #( %tky = ls_sb-%tky ) TO failed-odataservice.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD validatesrvbname.

    READ ENTITIES OF zr_cmsm_sb IN LOCAL MODE
      ENTITY ODataService
        FIELDS ( SrvbName SysId ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_sb).

    LOOP AT lt_sb INTO DATA(ls_sb).

      APPEND VALUE #( %tky        = ls_sb-%tky
                      %state_area = 'SRVBNAME' ) TO reported-odataservice.

      IF ls_sb-SrvbName IS INITIAL.
        CONTINUE.
      ENDIF.

      " 저장된 다른 서비스 중 같은 시스템·같은 바인딩
      SELECT SINGLE sbid FROM ztcmsm00220
        WHERE sbuuid   <> @ls_sb-SbUuid
          AND srvbname =  @ls_sb-SrvbName
          AND sysid    =  @ls_sb-SysId
        INTO @DATA(lv_dup_id).

      IF sy-subrc = 0.
        APPEND VALUE #( %tky = ls_sb-%tky ) TO failed-odataservice.
        APPEND VALUE #( %tky              = ls_sb-%tky
                        %state_area       = 'SRVBNAME'
                        %element-SrvbName = if_abap_behv=>mk-on
                        %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = COND string( WHEN lv_dup_id IS INITIAL
                                                                      THEN `같은 서비스 바인딩이 이미 등록돼 있습니다.`
                                                                      ELSE |같은 서비스 바인딩이 이미 등록돼 있습니다 ({ lv_dup_id }).| ) ) )
               TO reported-odataservice.
        CONTINUE.
      ENDIF.

      " 시스템에 없는 서비스 바인딩은 등록 불가
      IF srvb_exists( CONV #( ls_sb-SrvbName ) ) = abap_false.
        APPEND VALUE #( %tky = ls_sb-%tky ) TO failed-odataservice.
        APPEND VALUE #( %tky              = ls_sb-%tky
                        %state_area       = 'SRVBNAME'
                        %element-SrvbName = if_abap_behv=>mk-on
                        %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = |{ ls_sb-SrvbName }은(는) 시스템에 없습니다. 서비스 바인딩을 만든 뒤 등록하세요.| ) )
               TO reported-odataservice.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD validatetestfile.

    READ ENTITIES OF zr_cmsm_sb IN LOCAL MODE
      ENTITY ODataService
        FIELDS ( TestFile ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_sb).

    LOOP AT lt_sb INTO DATA(ls_sb).

      APPEND VALUE #( %tky        = ls_sb-%tky
                      %state_area = 'TESTFILE' ) TO reported-odataservice.

      IF xstrlen( ls_sb-TestFile ) > gc_max_file_size.
        APPEND VALUE #( %tky = ls_sb-%tky ) TO failed-odataservice.
        APPEND VALUE #( %tky              = ls_sb-%tky
                        %state_area       = 'TESTFILE'
                        %element-TestFile = if_abap_behv=>mk-on
                        %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = '테스트 파일은 10MB까지 올릴 수 있습니다.' ) )
               TO reported-odataservice.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD srvb_exists.

    DATA(lv_name) = to_upper( condense( iv_name ) ).

    IF lv_name IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE @abap_true FROM i_custabapobjdirectoryentry
      WHERE abapobject     = @lv_name
        AND abapobjecttype = 'SRVB'
      INTO @rv_exists.

  ENDMETHOD.

ENDCLASS.


"! 저장 뒤 처리 — 엑셀 업로드 성공 메시지만 (BDEF: managed with additional save)
CLASS lsc_zr_cmsm_sb DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.

ENDCLASS.


CLASS lsc_zr_cmsm_sb IMPLEMENTATION.

  METHOD save_modified.

    " 엑셀 업로드가 저장까지 끝났을 때만 성공 메시지 (저장 검증에 걸리면 save_modified 까지 안 온다)
    "   lcl_upload=>count 는 uploadexcel 액션에서만 채워지니, 화면에서 만들고 저장할 땐 0 이라 안 뜬다
    IF lcl_upload=>count > 0.
      " 특정 건에 붙지 않는 메시지라 %other 로 (화면에는 성공 토스트)
      APPEND new_message_with_text( severity = if_abap_behv_message=>severity-success
                                    text     = '업로드 완료' ) TO reported-%other.
      CLEAR lcl_upload=>count.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
