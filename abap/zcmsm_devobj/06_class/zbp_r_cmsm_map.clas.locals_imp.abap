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
