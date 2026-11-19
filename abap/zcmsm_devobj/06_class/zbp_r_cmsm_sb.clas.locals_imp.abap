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
    "   DRM 풀기 → itab 변환 → 행마다 확인 → 에러가 하나라도 있으면 한 건도 안 올림 → 활성 데이터로 생성
    "   채번·기본값·저장 검증은 BO 그대로 탄다 (여기 확인은 행 번호를 붙여 먼저 걸러 주는 것)
    TYPES: BEGIN OF ty_check,
             ok   TYPE abap_bool,
             text TYPE string,
           END OF ty_check,
           tt_check TYPE STANDARD TABLE OF ty_check WITH EMPTY KEY.

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
    DATA lt_name   TYPE string_table.
    DATA lt_module TYPE string_table.
    DATA lt_sys    TYPE string_table.
    DATA lt_user   TYPE string_table.
    DATA lt_req    TYPE string_table.

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
    IF lt_error IS INITIAL AND to_upper( condense( COND string( WHEN lines( lt_sheet ) >= 2 THEN lt_sheet[ 2 ]-srvbname ) ) ) <> 'SRVBNAME'.
      APPEND `OData 서비스 업로드 템플릿이 아닙니다. 템플릿의 '업로드' 시트를 그대로 쓰세요.` TO lt_error.
    ENDIF.

    " 3) 행마다 확인 (3행부터, 빈 줄은 건너뜀). 시스템에 있는 Service Binding·코드·사용자·요청번호·저장된 건은 한 번에 읽어 둔다
    IF lt_error IS INITIAL.
      SELECT SrvbName FROM zi_cmsm_syssrvbvh  INTO TABLE @lt_name.     " Z로 시작하는 서비스 바인딩 (Service Binding 값 도움말과 같은 목록)
      SELECT Value    FROM zi_cmsm_modulevh   INTO TABLE @lt_module.
      SELECT SysId    FROM zi_cmsm_sysid      INTO TABLE @lt_sys.
      SELECT UserId   FROM zi_cmsm_uservh     INTO TABLE @lt_user.
      SELECT ReqId    FROM zi_cmsm_reqvh      INTO TABLE @lt_req.
      " 중복 키 = 시스템 ID/Service Binding (저장된 것 + 위쪽 행)
      SELECT SysId, SrvbName FROM zi_cmsm_sb INTO TABLE @DATA(lt_saved).
      DATA(lt_dup) = VALUE string_table( FOR s IN lt_saved ( |{ s-SysId }/{ s-SrvbName }| ) ).

      LOOP AT lt_sheet INTO DATA(ls_row) FROM 3.
        DATA(lv_row) = sy-tabix.
        IF ls_row IS INITIAL.
          CONTINUE.
        ENDIF.
        ls_row-srvbname  = to_upper( condense( ls_row-srvbname ) ).
        ls_row-sysid     = to_upper( condense( ls_row-sysid ) ).
        ls_row-sapmodule = to_upper( condense( ls_row-sapmodule ) ).
        ls_row-ownerid   = to_upper( condense( ls_row-ownerid ) ).
        ls_row-reqid     = to_upper( condense( ls_row-reqid ) ).
        DATA(lv_key) = |{ ls_row-sysid }/{ ls_row-srvbname }|.

        DATA(lt_check) = VALUE tt_check(
          ( ok = xsdbool( line_exists( lt_name[ table_line = ls_row-srvbname ] ) )                          text = |Service Binding 확인: '{ ls_row-srvbname }' (비었거나 시스템에 없음)| )
          ( ok = xsdbool( ls_row-sysid IS INITIAL OR line_exists( lt_sys[ table_line = ls_row-sysid ] ) )   text = |시스템 ID 확인: '{ ls_row-sysid }'| )
          ( ok = xsdbool( line_exists( lt_module[ table_line = ls_row-sapmodule ] ) )                       text = |모듈 확인: '{ ls_row-sapmodule }'| )
          ( ok = xsdbool( ls_row-ownerid IS INITIAL OR line_exists( lt_user[ table_line = ls_row-ownerid ] ) ) text = |담당자 확인: '{ ls_row-ownerid }' (사용자 ID)| )
          ( ok = xsdbool( ls_row-reqid IS INITIAL OR line_exists( lt_req[ table_line = ls_row-reqid ] ) )   text = |요청번호 확인: '{ ls_row-reqid }'| )
          ( ok = xsdbool( NOT line_exists( lt_dup[ table_line = lv_key ] ) )                                text = |같은 시스템 ID·Service Binding이 이미 등록돼 있거나 위쪽 행에 있습니다| ) ).
        LOOP AT lt_check INTO DATA(ls_check) WHERE ok = abap_false.
          APPEND |{ lv_row }행: { ls_check-text }| TO lt_error.
        ENDLOOP.
        APPEND lv_key TO lt_dup.

        APPEND VALUE #( %cid        = |ROW{ lv_row }|
                        %is_draft   = if_abap_behv=>mk-off
                        SrvbName    = ls_row-srvbname
                        SysId       = ls_row-sysid
                        SapModule   = ls_row-sapmodule
                        Description = ls_row-description
                        OwnerId     = ls_row-ownerid
                        ObjCreator  = ls_row-objcreator
                        ReqId       = ls_row-reqid ) TO lt_create.
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
                                                      text     = lv_error ) ) TO reported-odataservice.
      ENDLOOP.
      APPEND VALUE #( %cid = ls_key-%cid ) TO failed-odataservice.
      RETURN.
    ENDIF.

    " 5) 등록 (드래프트 없이 바로 활성 데이터)
    MODIFY ENTITIES OF zr_cmsm_sb IN LOCAL MODE
      ENTITY ODataService
        CREATE FIELDS ( SrvbName SysId SapModule Description OwnerId ObjCreator ReqId ) WITH lt_create
      FAILED failed
      REPORTED reported.

    APPEND VALUE #( %cid = ls_key-%cid
                    %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                  text     = |{ lines( lt_create ) }건을 올렸습니다.| ) ) TO reported-odataservice.

  ENDMETHOD.


  METHOD get_global_authorizations.
    " strict 모드라 권한 제어 선언이 필수라서 둔 자리.
    " result를 비워두면 전부 허용된다. 권한 오브젝트/DCL 정할 때 채운다.
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
