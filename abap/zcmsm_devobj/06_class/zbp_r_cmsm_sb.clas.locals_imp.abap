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
