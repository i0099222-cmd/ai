"! Value Help BO 로컬 핸들러
"!
"! - VH 이름을 넣으면 구현 방식 자동 판별 (CDS → C, Search Help → S, 못 찾으면 빈 값 + 저장 시 경고)
"! - 테스트 파일을 올리면 올린 사람·일시 자동, 지우면 같이 비움. 10MB까지
"! - 같은 시스템 ID에 같은 VH 이름은 한 번만 등록
"! - 데이터 소스(자식)는 유형·이름 필수
CLASS lhc_valuehelp DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    TYPES ty_impl TYPE c LENGTH 1.

    CONSTANTS:
      BEGIN OF gc_impl,
        cds         TYPE ty_impl VALUE 'C',
        search_help TYPE ty_impl VALUE 'S',
      END OF gc_impl,

      " 테스트 파일 최대 크기 10MB
      gc_max_file_size TYPE i VALUE 10485760.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR ValueHelp RESULT result.

    METHODS setinitialvalues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ValueHelp~setInitialValues.

    METHODS detectvhimpl FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ValueHelp~detectVhImpl.

    METHODS settestinfo FOR DETERMINE ON MODIFY
      IMPORTING keys FOR ValueHelp~setTestInfo.

    METHODS setvhid FOR DETERMINE ON SAVE
      IMPORTING keys FOR ValueHelp~setVhId.

    METHODS validatemandatory FOR VALIDATE ON SAVE
      IMPORTING keys FOR ValueHelp~validateMandatory.

    METHODS validatevhname FOR VALIDATE ON SAVE
      IMPORTING keys FOR ValueHelp~validateVhName.

    METHODS validatetestfile FOR VALIDATE ON SAVE
      IMPORTING keys FOR ValueHelp~validateTestFile.

    "! VH 이름으로 구현 방식 찾기. 못 찾으면 빈 값
    METHODS detect_impl
      IMPORTING iv_name        TYPE string
      RETURNING VALUE(rv_impl) TYPE ty_impl.

ENDCLASS.


CLASS lhc_valuehelp IMPLEMENTATION.

  METHOD get_global_authorizations.
    " strict 모드라 권한 제어 선언이 필수라서 둔 자리.
    " result를 비워두면 전부 허용된다. 권한 오브젝트/DCL 정할 때 채운다.
  ENDMETHOD.


  METHOD setinitialvalues.

    READ ENTITIES OF zr_cmsm_vh IN LOCAL MODE
      ENTITY ValueHelp
        FIELDS ( OwnerId ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_vh).

    DELETE lt_vh WHERE OwnerId IS NOT INITIAL.
    IF lt_vh IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    MODIFY ENTITIES OF zr_cmsm_vh IN LOCAL MODE
      ENTITY ValueHelp
        UPDATE FIELDS ( OwnerId )
        WITH VALUE #( FOR ls_vh IN lt_vh
                      ( %tky    = ls_vh-%tky
                        OwnerId = lv_user ) ).

  ENDMETHOD.


  METHOD detectvhimpl.

    DATA lt_update TYPE TABLE FOR UPDATE zr_cmsm_vh.

    READ ENTITIES OF zr_cmsm_vh IN LOCAL MODE
      ENTITY ValueHelp
        FIELDS ( VhName VhImpl ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_vh).

    LOOP AT lt_vh INTO DATA(ls_vh).

      DATA(lv_impl) = detect_impl( CONV #( ls_vh-VhName ) ).

      IF lv_impl <> ls_vh-VhImpl.
        APPEND VALUE #( %tky   = ls_vh-%tky
                        VhImpl = lv_impl ) TO lt_update.
      ENDIF.

    ENDLOOP.

    IF lt_update IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_cmsm_vh IN LOCAL MODE
      ENTITY ValueHelp
        UPDATE FIELDS ( VhImpl ) WITH lt_update.

  ENDMETHOD.


  METHOD settestinfo.

    DATA lv_now TYPE timestampl.

    READ ENTITIES OF zr_cmsm_vh IN LOCAL MODE
      ENTITY ValueHelp
        FIELDS ( TestFile ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_vh).

    IF lt_vh IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).
    GET TIME STAMP FIELD lv_now.

    " 파일이 있으면 지금 사용자·시각, 지웠으면 비움
    MODIFY ENTITIES OF zr_cmsm_vh IN LOCAL MODE
      ENTITY ValueHelp
        UPDATE FIELDS ( TestBy TestAt )
        WITH VALUE #( FOR ls_vh IN lt_vh
                      ( %tky   = ls_vh-%tky
                        TestBy = COND #( WHEN ls_vh-TestFile IS NOT INITIAL THEN lv_user )
                        TestAt = COND #( WHEN ls_vh-TestFile IS NOT INITIAL THEN lv_now ) ) ).

  ENDMETHOD.


  METHOD setvhid.

    DATA lt_update TYPE TABLE FOR UPDATE zr_cmsm_vh.

    READ ENTITIES OF zr_cmsm_vh IN LOCAL MODE
      ENTITY ValueHelp
        FIELDS ( VhId ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_vh).

    DELETE lt_vh WHERE VhId IS NOT INITIAL.

    LOOP AT lt_vh INTO DATA(ls_vh).

      DATA(lv_id) = zcl_cmsm_display_id=>next( zcl_cmsm_display_id=>gc_range-value_help ).

      IF lv_id IS INITIAL.
        " 저장은 막지 않는다. 번호 범위를 고친 뒤 다시 저장하면 채번된다
        APPEND VALUE #( %tky = ls_vh-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-warning
                                 text     = '등록번호를 채번하지 못했습니다. 번호 범위 ZCMSM_DOID 구간 03을 확인하세요.' ) )
               TO reported-valuehelp.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = ls_vh-%tky
                      VhId = lv_id ) TO lt_update.

    ENDLOOP.

    IF lt_update IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_cmsm_vh IN LOCAL MODE
      ENTITY ValueHelp
        UPDATE FIELDS ( VhId ) WITH lt_update.

  ENDMETHOD.


  METHOD validatemandatory.

    READ ENTITIES OF zr_cmsm_vh IN LOCAL MODE
      ENTITY ValueHelp
        FIELDS ( VhName SapModule ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_vh).

    LOOP AT lt_vh INTO DATA(ls_vh).

      " 이전 검사 메시지 지우기
      APPEND VALUE #( %tky        = ls_vh-%tky
                      %state_area = 'MANDATORY' ) TO reported-valuehelp.

      DATA(lv_failed) = abap_false.

      IF ls_vh-VhName IS INITIAL.
        lv_failed = abap_true.
        APPEND VALUE #( %tky            = ls_vh-%tky
                        %state_area     = 'MANDATORY'
                        %element-VhName = if_abap_behv=>mk-on
                        %msg            = new_message_with_text(
                                            severity = if_abap_behv_message=>severity-error
                                            text     = 'VH 이름을 입력하세요.' ) )
               TO reported-valuehelp.
      ENDIF.

      IF ls_vh-SapModule IS INITIAL.
        lv_failed = abap_true.
        APPEND VALUE #( %tky               = ls_vh-%tky
                        %state_area        = 'MANDATORY'
                        %element-SapModule = if_abap_behv=>mk-on
                        %msg               = new_message_with_text(
                                               severity = if_abap_behv_message=>severity-error
                                               text     = '모듈을 선택하세요.' ) )
               TO reported-valuehelp.
      ENDIF.

      IF lv_failed = abap_true.
        APPEND VALUE #( %tky = ls_vh-%tky ) TO failed-valuehelp.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD validatevhname.

    READ ENTITIES OF zr_cmsm_vh IN LOCAL MODE
      ENTITY ValueHelp
        FIELDS ( VhName SysId VhImpl ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_vh).

    LOOP AT lt_vh INTO DATA(ls_vh).

      APPEND VALUE #( %tky        = ls_vh-%tky
                      %state_area = 'VHNAME' ) TO reported-valuehelp.

      IF ls_vh-VhName IS INITIAL.
        CONTINUE.
      ENDIF.

      " 저장된 다른 VH 중 같은 시스템·같은 이름
      SELECT SINGLE vhid FROM ztcmsm00200
        WHERE vhuuid <> @ls_vh-VhUuid
          AND vhname =  @ls_vh-VhName
          AND sysid  =  @ls_vh-SysId
        INTO @DATA(lv_dup_id).

      IF sy-subrc = 0.
        APPEND VALUE #( %tky = ls_vh-%tky ) TO failed-valuehelp.
        APPEND VALUE #( %tky            = ls_vh-%tky
                        %state_area     = 'VHNAME'
                        %element-VhName = if_abap_behv=>mk-on
                        %msg            = new_message_with_text(
                                            severity = if_abap_behv_message=>severity-error
                                            text     = COND string( WHEN lv_dup_id IS INITIAL
                                                                    THEN `같은 VH가 이미 등록돼 있습니다.`
                                                                    ELSE |같은 VH가 이미 등록돼 있습니다 ({ lv_dup_id }).| ) ) )
               TO reported-valuehelp.
        CONTINUE.
      ENDIF.

      " 시스템에서 못 찾았으면 경고만 (저장은 됨)
      IF ls_vh-VhImpl IS INITIAL.
        APPEND VALUE #( %tky            = ls_vh-%tky
                        %state_area     = 'VHNAME'
                        %element-VhName = if_abap_behv=>mk-on
                        %msg            = new_message_with_text(
                                            severity = if_abap_behv_message=>severity-warning
                                            text     = '시스템에서 이 이름의 CDS·Search Help를 찾지 못했습니다. 이름을 확인하세요.' ) )
               TO reported-valuehelp.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD validatetestfile.

    READ ENTITIES OF zr_cmsm_vh IN LOCAL MODE
      ENTITY ValueHelp
        FIELDS ( TestFile ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_vh).

    LOOP AT lt_vh INTO DATA(ls_vh).

      APPEND VALUE #( %tky        = ls_vh-%tky
                      %state_area = 'TESTFILE' ) TO reported-valuehelp.

      IF xstrlen( ls_vh-TestFile ) > gc_max_file_size.
        APPEND VALUE #( %tky = ls_vh-%tky ) TO failed-valuehelp.
        APPEND VALUE #( %tky              = ls_vh-%tky
                        %state_area       = 'TESTFILE'
                        %element-TestFile = if_abap_behv=>mk-on
                        %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = '테스트 파일은 10MB까지 올릴 수 있습니다.' ) )
               TO reported-valuehelp.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD detect_impl.

    DATA(lv_name) = to_upper( condense( iv_name ) ).

    IF lv_name IS INITIAL.
      RETURN.
    ENDIF.

    " CDS (데이터 정의). DDLS 이름은 30자까지
    IF strlen( lv_name ) <= 30
       AND xco_cp_abap_repository=>object->ddls->for( CONV #( lv_name ) )->exists( ) = abap_true.
      rv_impl = gc_impl-cds.
      RETURN.
    ENDIF.

    " Search Help (고객 오브젝트 디렉터리)
    SELECT SINGLE @abap_true FROM i_custabapobjdirectoryentry
      WHERE abapobject     = @lv_name
        AND abapobjecttype = 'SHLP'
      INTO @DATA(lv_found).

    IF sy-subrc = 0 AND lv_found = abap_true.
      rv_impl = gc_impl-search_help.
    ENDIF.

  ENDMETHOD.

ENDCLASS.


CLASS lhc_valuehelpsource DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS validatesource FOR VALIDATE ON SAVE
      IMPORTING keys FOR ValueHelpSource~validateSource.

ENDCLASS.


CLASS lhc_valuehelpsource IMPLEMENTATION.

  METHOD validatesource.

    READ ENTITIES OF zr_cmsm_vh IN LOCAL MODE
      ENTITY ValueHelpSource
        FIELDS ( VhUuid SrcKind SrcName ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_src).

    LOOP AT lt_src INTO DATA(ls_src).

      APPEND VALUE #( %tky        = ls_src-%tky
                      %state_area = 'MANDATORY' ) TO reported-valuehelpsource.

      DATA(lv_failed) = abap_false.

      " %path: 메시지를 부모(VH) 화면의 데이터 소스 행에 붙이기 위함
      IF ls_src-SrcKind IS INITIAL.
        lv_failed = abap_true.
        APPEND VALUE #( %tky             = ls_src-%tky
                        %state_area      = 'MANDATORY'
                        %element-SrcKind = if_abap_behv=>mk-on
                        %path            = VALUE #( valuehelp-%is_draft = ls_src-%is_draft
                                                    valuehelp-VhUuid    = ls_src-VhUuid )
                        %msg             = new_message_with_text(
                                             severity = if_abap_behv_message=>severity-error
                                             text     = '데이터 소스 유형을 선택하세요.' ) )
               TO reported-valuehelpsource.
      ENDIF.

      IF ls_src-SrcName IS INITIAL.
        lv_failed = abap_true.
        APPEND VALUE #( %tky             = ls_src-%tky
                        %state_area      = 'MANDATORY'
                        %element-SrcName = if_abap_behv=>mk-on
                        %path            = VALUE #( valuehelp-%is_draft = ls_src-%is_draft
                                                    valuehelp-VhUuid    = ls_src-VhUuid )
                        %msg             = new_message_with_text(
                                             severity = if_abap_behv_message=>severity-error
                                             text     = '데이터 소스 이름을 입력하세요.' ) )
               TO reported-valuehelpsource.
      ENDIF.

      IF lv_failed = abap_true.
        APPEND VALUE #( %tky = ls_src-%tky ) TO failed-valuehelpsource.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
