"! 매핑 BO 로컬 핸들러
"!
"! 입력 규칙
"!   구분 매핑(M): 소스 시스템·As-Is 유형·As-Is 오브젝트 필수 / 신규(N): As-Is 잠금(값 비움)
"!   To-Be 유형 T-code: UI 종류 필수, 그 외: UI 필드 전부 잠금(값 비움)
"!     Fiori  : Semantic Object-Action 필수, Fiori 앱 ID·URI 선택
"!     React  : React 앱 이름·URI 필수
"!     WebGUI : URI 선택
"!   As-Is 유형은 ZI_CMSM_AsisTypeVH, To-Be 유형은 ZI_CMSM_TobeTypeVH 에 있는 값만
"!   같은 구분·소스 시스템·As-Is·To-Be 조합은 한 번만 등록
CLASS lhc_mapping DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PUBLIC SECTION.
    " 엑셀 업로드로 만든 건수 — uploadexcel 이 넣고, saver(save_modified)가 저장 뒤 성공 메시지에 쓴다
    CLASS-DATA gv_upload_count TYPE i.

  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF gc_kind,
        mapping TYPE c LENGTH 1 VALUE 'M',
        new     TYPE c LENGTH 1 VALUE 'N',
      END OF gc_kind,

      BEGIN OF gc_ui,
        fiori  TYPE c LENGTH 1 VALUE 'F',
        webgui TYPE c LENGTH 1 VALUE 'W',
        react  TYPE c LENGTH 1 VALUE 'R',
      END OF gc_ui,

      gc_type_tcode TYPE c LENGTH 10 VALUE 'TCODE'.

    TYPES:
      BEGIN OF ty_missing,
        field TYPE string,
        text  TYPE string,
      END OF ty_missing,
      tt_missing TYPE STANDARD TABLE OF ty_missing WITH EMPTY KEY.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Mapping RESULT result.

    " 엑셀 업로드 (static action). 로직은 이 메서드 하나에
    METHODS uploadexcel FOR MODIFY
      IMPORTING keys FOR ACTION Mapping~uploadExcel.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Mapping RESULT result.

    METHODS setinitialvalues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Mapping~setInitialValues.

    METHODS clearunusedfields FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Mapping~clearUnusedFields.

    METHODS setmapid FOR DETERMINE ON SAVE
      IMPORTING keys FOR Mapping~setMapId.

    METHODS validatemandatory FOR VALIDATE ON SAVE
      IMPORTING keys FOR Mapping~validateMandatory.

    METHODS validateobjecttype FOR VALIDATE ON SAVE
      IMPORTING keys FOR Mapping~validateObjectType.

    METHODS validateduplicate FOR VALIDATE ON SAVE
      IMPORTING keys FOR Mapping~validateDuplicate.

ENDCLASS.


CLASS lhc_mapping IMPLEMENTATION.

  METHOD uploadexcel.

    " 엑셀 업로드 — 템플릿 '업로드' 시트 (1행 컬럼명, 2행 필드명, 3행부터 데이터)
    "   DRM 풀기 → itab 변환 → 중복 확인 → 중복이 하나라도 있으면 한 건도 안 올림 → 생성
    "   필수·코드값 등 나머지는 저장할 때 BO 검증이 막는다

    " 엑셀 한 줄 = 템플릿 칸 순서 그대로
    TYPES: BEGIN OF ty_sheet_data,
             mapkind      TYPE string,
             srcsysid     TYPE string,
             asistype     TYPE string,
             asisname     TYPE string,
             tgtsysid     TYPE string,
             tobetype     TYPE string,
             tobename     TYPE string,
             uikind       TYPE string,
             fioriappid   TYPE string,
             semobjaction TYPE string,
             reactapp     TYPE string,
             uiuri        TYPE string,
             sapmodule    TYPE string,
             description  TYPE string,
             ownerid      TYPE string,
             objcreator   TYPE string,
             reqid        TYPE string,
           END OF ty_sheet_data.

    DATA lt_sheet  TYPE STANDARD TABLE OF ty_sheet_data WITH EMPTY KEY.
    DATA lt_create TYPE TABLE FOR CREATE zr_cmsm_map.
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
      " 2) 중복 키 = 구분/소스 시스템/As-Is 유형/As-Is/To-Be 유형/To-Be (저장된 것 + 위쪽 행)
      SELECT MapKind, SrcSysId, AsisType, AsisName, TobeType, TobeName FROM zi_cmsm_map INTO TABLE @DATA(lt_saved).
      DATA(lt_dup) = VALUE string_table( FOR s IN lt_saved ( |{ s-MapKind }/{ s-SrcSysId }/{ s-AsisType }/{ s-AsisName }/{ s-TobeType }/{ s-TobeName }| ) ).

      " 3) 3행부터 한 줄씩 (빈 줄은 건너뜀). 코드·이름은 대문자로
      LOOP AT lt_sheet INTO DATA(ls_row) FROM 3.
        DATA(lv_row) = sy-tabix.
        IF ls_row IS INITIAL.
          CONTINUE.
        ENDIF.

        APPEND VALUE #( %cid         = |ROW{ lv_row }|
                        %is_draft    = if_abap_behv=>mk-off
                        MapKind      = to_upper( condense( ls_row-mapkind ) )
                        SrcSysId     = to_upper( condense( ls_row-srcsysid ) )
                        AsisType     = to_upper( condense( ls_row-asistype ) )
                        AsisName     = to_upper( condense( ls_row-asisname ) )
                        TgtSysId     = to_upper( condense( ls_row-tgtsysid ) )
                        TobeType     = to_upper( condense( ls_row-tobetype ) )
                        TobeName     = to_upper( condense( ls_row-tobename ) )
                        UiKind       = to_upper( condense( ls_row-uikind ) )
                        FioriAppId   = ls_row-fioriappid
                        SemObjAction = ls_row-semobjaction
                        ReactApp     = ls_row-reactapp
                        UiUri        = ls_row-uiuri
                        SapModule    = to_upper( condense( ls_row-sapmodule ) )
                        Description  = ls_row-description
                        OwnerId      = to_upper( condense( ls_row-ownerid ) )
                        ObjCreator   = ls_row-objcreator
                        ReqId        = to_upper( condense( ls_row-reqid ) ) ) TO lt_create REFERENCE INTO DATA(lr_new).
        " 중복이면 에러 (저장된 것·위쪽 행과 같은 키)
        DATA(lv_key) = |{ lr_new->MapKind }/{ lr_new->SrcSysId }/{ lr_new->AsisType }/{ lr_new->AsisName }/{ lr_new->TobeType }/{ lr_new->TobeName }|.
        IF line_exists( lt_dup[ table_line = lv_key ] ).
          APPEND |{ lv_row }행: 이미 등록됐거나 위쪽 행과 같은 매핑입니다 ({ lv_key })| TO lt_error.
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
                                                      text     = lv_error ) ) TO reported-mapping.
      ENDLOOP.
      APPEND VALUE #( %cid = ls_key-%cid ) TO failed-mapping.
      RETURN.
    ENDIF.

    " 등록 (드래프트 없이 바로 활성 데이터). 채번·기본값·저장 검증은 BO 그대로
    "   성공 메시지는 여기서 안 띄운다: 이 시점엔 저장 검증 전이라, 검증에 걸리면 성공·실패가 같이 나온다
    MODIFY ENTITIES OF zr_cmsm_map IN LOCAL MODE
      ENTITY Mapping
        CREATE FIELDS ( MapKind SrcSysId AsisType AsisName TgtSysId TobeType TobeName UiKind FioriAppId SemObjAction ReactApp UiUri
                       SapModule Description OwnerId ObjCreator ReqId ) WITH lt_create
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

    READ ENTITIES OF zr_cmsm_map IN LOCAL MODE
      ENTITY Mapping
        FIELDS ( MapKind TobeType UiKind ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_map)
      FAILED failed.

    LOOP AT lt_map INTO DATA(ls_map).

      " 구분이 비어 있으면 매핑으로 본다
      DATA(lv_asis)  = xsdbool( ls_map-MapKind <> gc_kind-new ).
      DATA(lv_tcode) = xsdbool( ls_map-TobeType = gc_type_tcode ).
      DATA(lv_fiori) = xsdbool( lv_tcode = abap_true AND ls_map-UiKind = gc_ui-fiori ).
      DATA(lv_react) = xsdbool( lv_tcode = abap_true AND ls_map-UiKind = gc_ui-react ).
      DATA(lv_uri)   = xsdbool( lv_tcode = abap_true AND ls_map-UiKind IS NOT INITIAL ).

      DATA(lv_asis_fc) = COND #( WHEN lv_asis = abap_true
                                 THEN if_abap_behv=>fc-f-mandatory
                                 ELSE if_abap_behv=>fc-f-read_only ).

      APPEND VALUE #(
        %tky                = ls_map-%tky
        %field-SrcSysId     = lv_asis_fc
        %field-AsisType     = lv_asis_fc
        %field-AsisName     = lv_asis_fc
        %field-UiKind       = COND #( WHEN lv_tcode = abap_true
                                      THEN if_abap_behv=>fc-f-mandatory
                                      ELSE if_abap_behv=>fc-f-read_only )
        %field-SemObjAction = COND #( WHEN lv_fiori = abap_true
                                      THEN if_abap_behv=>fc-f-mandatory
                                      ELSE if_abap_behv=>fc-f-read_only )
        %field-FioriAppId   = COND #( WHEN lv_fiori = abap_true
                                      THEN if_abap_behv=>fc-f-unrestricted
                                      ELSE if_abap_behv=>fc-f-read_only )
        %field-ReactApp     = COND #( WHEN lv_react = abap_true
                                      THEN if_abap_behv=>fc-f-mandatory
                                      ELSE if_abap_behv=>fc-f-read_only )
        %field-UiUri        = COND #( WHEN lv_react = abap_true
                                      THEN if_abap_behv=>fc-f-mandatory
                                      WHEN lv_uri = abap_true
                                      THEN if_abap_behv=>fc-f-unrestricted
                                      ELSE if_abap_behv=>fc-f-read_only )
      ) TO result.

    ENDLOOP.

  ENDMETHOD.


  METHOD setinitialvalues.

    READ ENTITIES OF zr_cmsm_map IN LOCAL MODE
      ENTITY Mapping
        FIELDS ( MapKind OwnerId ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_map).

    DELETE lt_map WHERE MapKind IS NOT INITIAL AND OwnerId IS NOT INITIAL.
    IF lt_map IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    MODIFY ENTITIES OF zr_cmsm_map IN LOCAL MODE
      ENTITY Mapping
        UPDATE FIELDS ( MapKind OwnerId )
        WITH VALUE #( FOR ls_map IN lt_map
                      ( %tky    = ls_map-%tky
                        MapKind = COND #( WHEN ls_map-MapKind IS INITIAL
                                          THEN gc_kind-mapping
                                          ELSE ls_map-MapKind )
                        OwnerId = COND #( WHEN ls_map-OwnerId IS INITIAL
                                          THEN lv_user
                                          ELSE ls_map-OwnerId ) ) ).

  ENDMETHOD.


  METHOD clearunusedfields.

    DATA lt_update TYPE TABLE FOR UPDATE zr_cmsm_map.

    READ ENTITIES OF zr_cmsm_map IN LOCAL MODE
      ENTITY Mapping
        FIELDS ( MapKind TobeType UiKind SrcSysId AsisType AsisName
                 UiUri FioriAppId SemObjAction ReactApp ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_map).

    LOOP AT lt_map INTO DATA(ls_map).

      DATA(ls_new) = ls_map.

      IF ls_map-MapKind = gc_kind-new.
        CLEAR: ls_new-SrcSysId, ls_new-AsisType, ls_new-AsisName.
      ENDIF.

      IF ls_map-TobeType <> gc_type_tcode.
        CLEAR: ls_new-UiKind, ls_new-UiUri, ls_new-FioriAppId, ls_new-SemObjAction, ls_new-ReactApp.
      ELSE.
        CASE ls_map-UiKind.
          WHEN gc_ui-fiori.
            CLEAR ls_new-ReactApp.
          WHEN gc_ui-react.
            CLEAR: ls_new-FioriAppId, ls_new-SemObjAction.
          WHEN gc_ui-webgui.
            CLEAR: ls_new-FioriAppId, ls_new-SemObjAction, ls_new-ReactApp.
          WHEN OTHERS.
            " UI 종류를 아직 안 고름
            CLEAR: ls_new-UiUri, ls_new-FioriAppId, ls_new-SemObjAction, ls_new-ReactApp.
        ENDCASE.
      ENDIF.

      IF ls_new <> ls_map.
        APPEND CORRESPONDING #( ls_new ) TO lt_update.
      ENDIF.

    ENDLOOP.

    IF lt_update IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_cmsm_map IN LOCAL MODE
      ENTITY Mapping
        UPDATE FIELDS ( SrcSysId AsisType AsisName UiKind UiUri FioriAppId SemObjAction ReactApp )
        WITH lt_update.

  ENDMETHOD.


  METHOD setmapid.

    DATA lt_update TYPE TABLE FOR UPDATE zr_cmsm_map.

    READ ENTITIES OF zr_cmsm_map IN LOCAL MODE
      ENTITY Mapping
        FIELDS ( MapId ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_map).

    DELETE lt_map WHERE MapId IS NOT INITIAL.

    LOOP AT lt_map INTO DATA(ls_map).

      DATA(lv_id) = zcl_cmsm_display_id=>next( zcl_cmsm_display_id=>gc_range-mapping ).

      IF lv_id IS INITIAL.
        " 저장은 막지 않는다. 번호 범위를 고친 뒤 다시 저장하면 채번된다
        APPEND VALUE #( %tky = ls_map-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-warning
                                 text     = '등록번호를 채번하지 못했습니다. 번호 범위 ZCMSM_DOID 구간 02를 확인하세요.' ) )
               TO reported-mapping.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky  = ls_map-%tky
                      MapId = lv_id ) TO lt_update.

    ENDLOOP.

    IF lt_update IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_cmsm_map IN LOCAL MODE
      ENTITY Mapping
        UPDATE FIELDS ( MapId ) WITH lt_update.

  ENDMETHOD.


  METHOD validatemandatory.

    READ ENTITIES OF zr_cmsm_map IN LOCAL MODE
      ENTITY Mapping
        FIELDS ( MapKind TobeType TobeName SapModule SrcSysId AsisType AsisName
                 UiKind UiUri SemObjAction ReactApp ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_map).

    LOOP AT lt_map INTO DATA(ls_map).

      " 이전 검사 메시지 지우기
      APPEND VALUE #( %tky        = ls_map-%tky
                      %state_area = 'MANDATORY' ) TO reported-mapping.

      DATA(lt_missing) = VALUE tt_missing( ).

      IF ls_map-MapKind IS INITIAL.
        APPEND VALUE #( field = `MAPKIND`   text = `구분을 선택하세요.` ) TO lt_missing.
      ENDIF.
      IF ls_map-TobeType IS INITIAL.
        APPEND VALUE #( field = `TOBETYPE`  text = `To-Be 유형을 선택하세요.` ) TO lt_missing.
      ENDIF.
      IF ls_map-TobeName IS INITIAL.
        APPEND VALUE #( field = `TOBENAME`  text = `To-Be 오브젝트를 입력하세요.` ) TO lt_missing.
      ENDIF.
      IF ls_map-SapModule IS INITIAL.
        APPEND VALUE #( field = `SAPMODULE` text = `모듈을 선택하세요.` ) TO lt_missing.
      ENDIF.

      IF ls_map-MapKind <> gc_kind-new.
        IF ls_map-SrcSysId IS INITIAL.
          APPEND VALUE #( field = `SRCSYSID` text = `매핑이면 소스 시스템을 선택하세요.` ) TO lt_missing.
        ENDIF.
        IF ls_map-AsisType IS INITIAL.
          APPEND VALUE #( field = `ASISTYPE` text = `매핑이면 As-Is 유형을 선택하세요.` ) TO lt_missing.
        ENDIF.
        IF ls_map-AsisName IS INITIAL.
          APPEND VALUE #( field = `ASISNAME` text = `매핑이면 As-Is 오브젝트를 입력하세요.` ) TO lt_missing.
        ENDIF.
      ENDIF.

      IF ls_map-TobeType = gc_type_tcode.
        IF ls_map-UiKind IS INITIAL.
          APPEND VALUE #( field = `UIKIND` text = `T-code면 UI 종류를 선택하세요.` ) TO lt_missing.
        ENDIF.
        IF ls_map-UiKind = gc_ui-fiori AND ls_map-SemObjAction IS INITIAL.
          APPEND VALUE #( field = `SEMOBJACTION` text = `Fiori면 Semantic Object-Action을 입력하세요.` ) TO lt_missing.
        ENDIF.
        IF ls_map-UiKind = gc_ui-react AND ls_map-ReactApp IS INITIAL.
          APPEND VALUE #( field = `REACTAPP` text = `React면 앱 이름을 입력하세요.` ) TO lt_missing.
        ENDIF.
        IF ls_map-UiKind = gc_ui-react AND ls_map-UiUri IS INITIAL.
          APPEND VALUE #( field = `UIURI` text = `React면 URI를 입력하세요.` ) TO lt_missing.
        ENDIF.
      ENDIF.

      IF lt_missing IS INITIAL.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky = ls_map-%tky ) TO failed-mapping.

      LOOP AT lt_missing INTO DATA(ls_missing).
        APPEND VALUE #( %tky        = ls_map-%tky
                        %state_area = 'MANDATORY'
                        %msg        = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text     = ls_missing-text ) )
               TO reported-mapping ASSIGNING FIELD-SYMBOL(<ls_reported>).
        " 해당 입력칸을 빨갛게
        ASSIGN COMPONENT ls_missing-field OF STRUCTURE <ls_reported>-%element TO FIELD-SYMBOL(<lv_element>).
        IF sy-subrc = 0.
          <lv_element> = if_abap_behv=>mk-on.
        ENDIF.
      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.


  METHOD validateobjecttype.

    READ ENTITIES OF zr_cmsm_map IN LOCAL MODE
      ENTITY Mapping
        FIELDS ( AsisType TobeType ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_map).

    " 허용 유형은 화면 드롭다운과 같은 뷰에서 읽는다
    SELECT Value FROM zi_cmsm_asistypevh INTO TABLE @DATA(lt_asis_ok).
    SELECT Value FROM zi_cmsm_tobetypevh INTO TABLE @DATA(lt_tobe_ok).

    LOOP AT lt_map INTO DATA(ls_map).

      APPEND VALUE #( %tky        = ls_map-%tky
                      %state_area = 'OBJTYPE' ) TO reported-mapping.

      DATA(lv_failed) = abap_false.

      IF ls_map-AsisType IS NOT INITIAL AND NOT line_exists( lt_asis_ok[ value = ls_map-AsisType ] ).
        lv_failed = abap_true.
        APPEND VALUE #( %tky              = ls_map-%tky
                        %state_area       = 'OBJTYPE'
                        %element-AsisType = if_abap_behv=>mk-on
                        %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = |As-Is 유형으로 { ls_map-AsisType }은(는) 쓸 수 없습니다.| ) )
               TO reported-mapping.
      ENDIF.

      IF ls_map-TobeType IS NOT INITIAL AND NOT line_exists( lt_tobe_ok[ value = ls_map-TobeType ] ).
        lv_failed = abap_true.
        APPEND VALUE #( %tky              = ls_map-%tky
                        %state_area       = 'OBJTYPE'
                        %element-TobeType = if_abap_behv=>mk-on
                        %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = |To-Be 유형으로 { ls_map-TobeType }은(는) 쓸 수 없습니다. | &&
                                                         |VH·Service Binding은 각 탭에서 등록하세요.| ) )
               TO reported-mapping.
      ENDIF.

      IF lv_failed = abap_true.
        APPEND VALUE #( %tky = ls_map-%tky ) TO failed-mapping.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD validateduplicate.

    READ ENTITIES OF zr_cmsm_map IN LOCAL MODE
      ENTITY Mapping
        FIELDS ( MapKind SrcSysId AsisType AsisName TobeType TobeName ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_map).

    LOOP AT lt_map INTO DATA(ls_map).

      APPEND VALUE #( %tky        = ls_map-%tky
                      %state_area = 'DUPLICATE' ) TO reported-mapping.

      IF ls_map-TobeName IS INITIAL.
        CONTINUE.
      ENDIF.

      " 저장된 다른 매핑 중 같은 조합 (신규는 As-Is가 비어 있어 To-Be만으로 비교된다)
      SELECT SINGLE mapid FROM ztcmsm00190
        WHERE mapuuid  <> @ls_map-MapUuid
          AND mapkind  =  @ls_map-MapKind
          AND srcsysid =  @ls_map-SrcSysId
          AND asistype =  @ls_map-AsisType
          AND asisname =  @ls_map-AsisName
          AND tobetype =  @ls_map-TobeType
          AND tobename =  @ls_map-TobeName
        INTO @DATA(lv_dup_id).

      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      DATA(lv_text) = COND string( WHEN lv_dup_id IS INITIAL
                                   THEN `같은 매핑이 이미 등록돼 있습니다.`
                                   ELSE |같은 매핑이 이미 등록돼 있습니다 ({ lv_dup_id }).| ).

      APPEND VALUE #( %tky = ls_map-%tky ) TO failed-mapping.
      APPEND VALUE #( %tky              = ls_map-%tky
                      %state_area       = 'DUPLICATE'
                      %element-TobeName = if_abap_behv=>mk-on
                      %msg              = new_message_with_text(
                                            severity = if_abap_behv_message=>severity-error
                                            text     = lv_text ) )
             TO reported-mapping.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.


"! 저장 뒤 처리 — 엑셀 업로드 성공 메시지만 (BDEF: managed with additional save)
CLASS lsc_zr_cmsm_map DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.

ENDCLASS.


CLASS lsc_zr_cmsm_map IMPLEMENTATION.

  METHOD save_modified.

    " 엑셀 업로드가 저장까지 끝났을 때만 성공 메시지 (저장 검증에 걸리면 save_modified 까지 안 온다)
    IF lhc_mapping=>gv_upload_count > 0.
      " 특정 건에 붙지 않는 메시지라 %other 로 (화면에는 성공 토스트)
      APPEND new_message_with_text( severity = if_abap_behv_message=>severity-success
                                    text     = |{ lhc_mapping=>gv_upload_count }건을 올렸습니다.| ) TO reported-%other.
      CLEAR lhc_mapping=>gv_upload_count.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
