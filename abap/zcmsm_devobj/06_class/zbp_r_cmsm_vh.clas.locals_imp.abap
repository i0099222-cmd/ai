"! Value Help BO 로컬 핸들러
"!
"! - VH 이름을 넣으면 구현 방식 자동 판별 (CDS → C, Search Help → S, 못 찾으면 빈 값)
"! - 시스템에 없는 VH는 등록 불가 (저장 시 에러)
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

    " 엑셀 업로드 (static action). 로직은 이 메서드 하나에
    METHODS uploadexcel FOR MODIFY
      IMPORTING keys FOR ACTION ValueHelp~uploadExcel.

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

  METHOD uploadexcel.

    " 엑셀 업로드 — 템플릿 '업로드' 시트 (1행 컬럼명, 2행 필드명, 3행부터 데이터)
    "   DRM 풀기 → itab 변환 → 중복 확인 → 중복이 하나라도 있으면 한 건도 안 올림 → 생성
    "   필수·코드값 등 나머지는 저장할 때 BO 검증이 막는다

    " 엑셀 한 줄 = 템플릿 칸 순서 그대로
    TYPES: BEGIN OF ty_sheet_data,
             vhname      TYPE string,
             sysid       TYPE string,
             sapmodule   TYPE string,
             description TYPE string,
             ownerid     TYPE string,
             objcreator  TYPE string,
             reqid       TYPE string,
           END OF ty_sheet_data.

    DATA lt_sheet  TYPE STANDARD TABLE OF ty_sheet_data WITH EMPTY KEY.
    DATA lt_create TYPE TABLE FOR CREATE zr_cmsm_vh.
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
      " 2) 중복 키 = 시스템 ID/VH 이름 (저장된 것 + 위쪽 행)
      SELECT SysId, VhName FROM zi_cmsm_vh INTO TABLE @DATA(lt_saved).
      DATA(lt_dup) = VALUE string_table( FOR s IN lt_saved ( |{ s-SysId }/{ s-VhName }| ) ).

      " 3) 3행부터 한 줄씩 (빈 줄은 건너뜀). 코드·이름은 대문자로
      LOOP AT lt_sheet INTO DATA(ls_row) FROM 3.
        DATA(lv_row) = sy-tabix.
        IF ls_row IS INITIAL.
          CONTINUE.
        ENDIF.

        APPEND VALUE #( %cid        = |ROW{ lv_row }|
                        %is_draft   = if_abap_behv=>mk-off
                        VhName      = to_upper( condense( ls_row-vhname ) )
                        SysId       = to_upper( condense( ls_row-sysid ) )
                        SapModule   = to_upper( condense( ls_row-sapmodule ) )
                        Description = ls_row-description
                        OwnerId     = to_upper( condense( ls_row-ownerid ) )
                        ObjCreator  = ls_row-objcreator
                        ReqId       = to_upper( condense( ls_row-reqid ) ) ) TO lt_create REFERENCE INTO DATA(lr_new).
        " 중복이면 에러 (저장된 것·위쪽 행과 같은 키)
        DATA(lv_key) = |{ lr_new->SysId }/{ lr_new->VhName }|.
        IF line_exists( lt_dup[ table_line = lv_key ] ).
          APPEND |{ lv_row }행: 이미 등록됐거나 위쪽 행과 같은 VH입니다 ({ lv_key })| TO lt_error.
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
                                                      text     = lv_error ) ) TO reported-valuehelp.
      ENDLOOP.
      APPEND VALUE #( %cid = ls_key-%cid ) TO failed-valuehelp.
      RETURN.
    ENDIF.

    " 등록 (드래프트 없이 바로 활성 데이터). 채번·기본값·저장 검증은 BO 그대로
    MODIFY ENTITIES OF zr_cmsm_vh IN LOCAL MODE
      ENTITY ValueHelp
        CREATE FIELDS ( VhName SysId SapModule Description OwnerId ObjCreator ReqId ) WITH lt_create
      FAILED failed
      REPORTED reported.

    APPEND VALUE #( %cid = ls_key-%cid
                    %msg = new_message_with_text( severity = if_abap_behv_message=>severity-success
                                                  text     = |{ lines( lt_create ) }건을 올렸습니다.| ) ) TO reported-valuehelp.

  ENDMETHOD.


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
        FIELDS ( VhName SysId ) WITH CORRESPONDING #( keys )
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

      " 시스템에 없는 VH는 등록 불가.
      " 구현 방식 필드가 아니라 직접 확인 → 업로드 데이터도 같은 기준, 구현 방식 필드를 빼도 그대로 동작
      IF detect_impl( CONV #( ls_vh-VhName ) ) IS INITIAL.
        APPEND VALUE #( %tky = ls_vh-%tky ) TO failed-valuehelp.
        APPEND VALUE #( %tky            = ls_vh-%tky
                        %state_area     = 'VHNAME'
                        %element-VhName = if_abap_behv=>mk-on
                        %msg            = new_message_with_text(
                                            severity = if_abap_behv_message=>severity-error
                                            text     = |{ ls_vh-VhName }은(는) 시스템에 없습니다. VH를 개발(활성화)한 뒤 등록하세요.| ) )
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
