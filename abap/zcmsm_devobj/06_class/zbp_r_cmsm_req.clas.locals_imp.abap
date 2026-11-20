"! 요청 BO 로컬 핸들러
"!
"! 상태 흐름
"!   요청(R) --접수(담당자)--> 진행 중(I) --완료(담당자, 처리 내용 필수)--> 완료(C)
"!   요청(R)·진행 중(I) --반려(담당자, 사유 필수)--> 반려(J)
"!   요청(R) --요청 취소(요청자, 사유 필수)--> 취소(X)
"!   완료·반려·취소 후에는 수정·삭제 불가
"!
"! 수정 권한 (요청자 = CreatedBy, 담당자 = Assignee)
"!   요청자: 요청(R)일 때 제목·요청 내용·모듈·담당자, 삭제
"!   담당자: 진행 중(I)일 때 처리 내용·관련 등록번호
CLASS lhc_request DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PUBLIC SECTION.
    " 엑셀 업로드로 만든 건수 — uploadexcel 이 넣고, saver(save_modified)가 저장 뒤 성공 메시지에 쓴다
    CLASS-DATA gv_upload_count TYPE i.

  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF gc_status,
        requested   TYPE c LENGTH 1 VALUE 'R',
        in_progress TYPE c LENGTH 1 VALUE 'I',
        completed   TYPE c LENGTH 1 VALUE 'C',
        rejected    TYPE c LENGTH 1 VALUE 'J',
        cancelled   TYPE c LENGTH 1 VALUE 'X',
      END OF gc_status,

      BEGIN OF gc_hist_kind,
        created TYPE c LENGTH 1 VALUE 'C',
        updated TYPE c LENGTH 1 VALUE 'U',
        status  TYPE c LENGTH 1 VALUE 'S',
      END OF gc_hist_kind,

      " 이력 이전·새 값 최대 길이 (SSTRING 1333)
      gc_hist_max_len TYPE i VALUE 1333.

    TYPES:
      BEGIN OF ty_hist_row,
        kind  TYPE c LENGTH 1,
        field TYPE string,
        old   TYPE string,
        new   TYPE string,
        note  TYPE string,
      END OF ty_hist_row,
      tt_hist_row TYPE STANDARD TABLE OF ty_hist_row WITH EMPTY KEY,

      BEGIN OF ty_status_text,
        value TYPE c LENGTH 1,
        text  TYPE c LENGTH 60,
      END OF ty_status_text.

    DATA mt_status_text TYPE SORTED TABLE OF ty_status_text WITH UNIQUE KEY value.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Request RESULT result.

    " 엑셀 업로드 (static action). 로직은 이 메서드 하나에
    METHODS uploadexcel FOR MODIFY
      IMPORTING keys FOR ACTION Request~uploadExcel.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Request RESULT result.

    METHODS acceptrequest FOR MODIFY
      IMPORTING keys FOR ACTION Request~acceptRequest RESULT result.

    METHODS completerequest FOR MODIFY
      IMPORTING keys FOR ACTION Request~completeRequest RESULT result.

    METHODS rejectrequest FOR MODIFY
      IMPORTING keys FOR ACTION Request~rejectRequest RESULT result.

    METHODS cancelrequest FOR MODIFY
      IMPORTING keys FOR ACTION Request~cancelRequest RESULT result.

    METHODS setinitialvalues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Request~setInitialValues.

    METHODS setreqid FOR DETERMINE ON SAVE
      IMPORTING keys FOR Request~setReqId.

    METHODS recordhistory FOR DETERMINE ON SAVE
      IMPORTING keys FOR Request~recordHistory.

    METHODS validatemandatory FOR VALIDATE ON SAVE
      IMPORTING keys FOR Request~validateMandatory.

    "! 값이 바뀌었으면 수정(U) 이력 한 줄 추가
    METHODS add_change
      IMPORTING iv_field TYPE string
                iv_old   TYPE string
                iv_new   TYPE string
      CHANGING  ct_rows  TYPE tt_hist_row.

    "! 이력 칸 길이에 맞게 자르기
    METHODS cut
      IMPORTING iv_text        TYPE string
      RETURNING VALUE(rv_text) TYPE string.

    "! 상태 코드 → 텍스트 (mt_status_text 기준, 없으면 코드)
    METHODS status_text
      IMPORTING iv_status      TYPE string
      RETURNING VALUE(rv_text) TYPE string.

ENDCLASS.


CLASS lhc_request IMPLEMENTATION.

  METHOD uploadexcel.

    " 엑셀 업로드 — 템플릿 '업로드' 시트 (1행 컬럼명, 2행 필드명, 3행부터 데이터)
    "   DRM 풀기 → itab 변환 → 생성
    "   필수·코드값 등 나머지는 저장할 때 BO 검증이 막는다

    " 엑셀 한 줄 = 템플릿 칸 순서 그대로
    TYPES: BEGIN OF ty_sheet_data,
             title     TYPE string,
             reqtext   TYPE string,
             sapmodule TYPE string,
             assignee  TYPE string,
           END OF ty_sheet_data.

    DATA lt_sheet  TYPE STANDARD TABLE OF ty_sheet_data WITH EMPTY KEY.
    DATA lt_create TYPE TABLE FOR CREATE zr_cmsm_req.
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
      " 2) 3행부터 한 줄씩 (빈 줄은 건너뜀). 코드·이름은 대문자로
      LOOP AT lt_sheet INTO DATA(ls_row) FROM 3.
        DATA(lv_row) = sy-tabix.
        IF ls_row IS INITIAL.
          CONTINUE.
        ENDIF.

        APPEND VALUE #( %cid      = |ROW{ lv_row }|
                        %is_draft = if_abap_behv=>mk-off
                        Title     = ls_row-title
                        ReqText   = ls_row-reqtext
                        SapModule = to_upper( condense( ls_row-sapmodule ) )
                        Assignee  = to_upper( condense( ls_row-assignee ) ) ) TO lt_create.
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
                                                      text     = lv_error ) ) TO reported-request.
      ENDLOOP.
      APPEND VALUE #( %cid = ls_key-%cid ) TO failed-request.
      RETURN.
    ENDIF.

    " 등록 (드래프트 없이 바로 활성 데이터). 채번·기본값·저장 검증은 BO 그대로
    "   성공 메시지는 여기서 안 띄운다: 이 시점엔 저장 검증 전이라, 검증에 걸리면 성공·실패가 같이 나온다
    MODIFY ENTITIES OF zr_cmsm_req IN LOCAL MODE
      ENTITY Request
        CREATE FIELDS ( Title ReqText SapModule Assignee ) WITH lt_create
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

    READ ENTITIES OF zr_cmsm_req IN LOCAL MODE
      ENTITY Request
        FIELDS ( ReqStatus CreatedBy Assignee ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_req)
      FAILED failed.

    DATA(lv_user) = cl_abap_context_info=>get_user_technical_name( ).

    LOOP AT lt_req INTO DATA(ls_req).

      " 새로 만드는 중이면 요청자·상태가 아직 비어 있을 수 있어 요청자·요청(R)으로 본다
      DATA(lv_status)    = COND #( WHEN ls_req-ReqStatus IS INITIAL
                                   THEN gc_status-requested
                                   ELSE ls_req-ReqStatus ).
      DATA(lv_requester) = xsdbool( ls_req-CreatedBy IS INITIAL OR ls_req-CreatedBy = lv_user ).
      DATA(lv_assignee)  = xsdbool( ls_req-Assignee IS NOT INITIAL AND ls_req-Assignee = lv_user ).
      " 상태 변경 액션은 저장된(활성) 건에서만. 편집 중(드래프트)에는 막는다
      DATA(lv_active)    = xsdbool( ls_req-%is_draft = if_abap_behv=>mk-off ).

      DATA(lv_requester_edit) = xsdbool( lv_requester = abap_true AND lv_status = gc_status-requested ).
      DATA(lv_assignee_edit)  = xsdbool( lv_assignee = abap_true AND lv_status = gc_status-in_progress ).

      DATA(lv_edit) = COND #( WHEN lv_requester_edit = abap_true OR lv_assignee_edit = abap_true
                              THEN if_abap_behv=>fc-o-enabled
                              ELSE if_abap_behv=>fc-o-disabled ).

      DATA(lv_requester_mand) = COND #( WHEN lv_requester_edit = abap_true
                                        THEN if_abap_behv=>fc-f-mandatory
                                        ELSE if_abap_behv=>fc-f-read_only ).
      DATA(lv_requester_free) = COND #( WHEN lv_requester_edit = abap_true
                                        THEN if_abap_behv=>fc-f-unrestricted
                                        ELSE if_abap_behv=>fc-f-read_only ).
      DATA(lv_assignee_free)  = COND #( WHEN lv_assignee_edit = abap_true
                                        THEN if_abap_behv=>fc-f-unrestricted
                                        ELSE if_abap_behv=>fc-f-read_only ).

      APPEND VALUE #(
        %tky                    = ls_req-%tky
        %update                 = lv_edit   " 화면의 Edit 버튼도 이 값을 따른다
        %delete                 = COND #( WHEN lv_requester_edit = abap_true
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled )
        %field-Title            = lv_requester_mand
        %field-SapModule        = lv_requester_mand
        %field-Assignee         = lv_requester_mand
        %field-ReqText          = lv_requester_free
        %field-ProcResult       = lv_assignee_free
        %field-RelNo            = lv_assignee_free
        %action-acceptRequest   = COND #( WHEN lv_active = abap_true AND lv_assignee = abap_true
                                           AND lv_status = gc_status-requested
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled )
        %action-completeRequest = COND #( WHEN lv_active = abap_true AND lv_assignee = abap_true
                                           AND lv_status = gc_status-in_progress
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled )
        %action-rejectRequest   = COND #( WHEN lv_active = abap_true AND lv_assignee = abap_true
                                           AND ( lv_status = gc_status-requested OR lv_status = gc_status-in_progress )
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled )
        %action-cancelRequest   = COND #( WHEN lv_active = abap_true AND lv_requester = abap_true
                                           AND lv_status = gc_status-requested
                                          THEN if_abap_behv=>fc-o-enabled
                                          ELSE if_abap_behv=>fc-o-disabled )
      ) TO result.

    ENDLOOP.

  ENDMETHOD.


  METHOD acceptrequest.

    MODIFY ENTITIES OF zr_cmsm_req IN LOCAL MODE
      ENTITY Request
        UPDATE FIELDS ( ReqStatus )
        WITH VALUE #( FOR ls_key IN keys
                      ( %tky      = ls_key-%tky
                        ReqStatus = gc_status-in_progress ) ).

    READ ENTITIES OF zr_cmsm_req IN LOCAL MODE
      ENTITY Request
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_req).

    result = VALUE #( FOR ls_req IN lt_req ( %tky = ls_req-%tky %param = ls_req ) ).

  ENDMETHOD.


  METHOD completerequest.

    DATA lt_update TYPE TABLE FOR UPDATE zr_cmsm_req.

    READ ENTITIES OF zr_cmsm_req IN LOCAL MODE
      ENTITY Request
        FIELDS ( ProcResult ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_req).

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT lt_req INTO DATA(ls_req).

      IF ls_req-ProcResult IS INITIAL.
        APPEND VALUE #( %tky = ls_req-%tky ) TO failed-request.
        APPEND VALUE #( %tky              = ls_req-%tky
                        %element-ProcResult = if_abap_behv=>mk-on
                        %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = '처리 내용을 먼저 입력하고 저장하세요.' ) )
               TO reported-request.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky      = ls_req-%tky
                      ReqStatus = gc_status-completed
                      DoneDate  = lv_today ) TO lt_update.

    ENDLOOP.

    IF lt_update IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_cmsm_req IN LOCAL MODE
      ENTITY Request
        UPDATE FIELDS ( ReqStatus DoneDate ) WITH lt_update.

    READ ENTITIES OF zr_cmsm_req IN LOCAL MODE
      ENTITY Request
        ALL FIELDS WITH VALUE #( FOR ls_upd IN lt_update ( %tky = ls_upd-%tky ) )
      RESULT DATA(lt_done).

    result = VALUE #( FOR ls_done IN lt_done ( %tky = ls_done-%tky %param = ls_done ) ).

  ENDMETHOD.


  METHOD rejectrequest.

    DATA lt_update TYPE TABLE FOR UPDATE zr_cmsm_req.

    LOOP AT keys INTO DATA(ls_key).

      IF ls_key-%param-CloseReason IS INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-request.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = '반려 사유를 입력하세요.' ) )
               TO reported-request.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky        = ls_key-%tky
                      ReqStatus   = gc_status-rejected
                      CloseReason = ls_key-%param-CloseReason ) TO lt_update.

    ENDLOOP.

    IF lt_update IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_cmsm_req IN LOCAL MODE
      ENTITY Request
        UPDATE FIELDS ( ReqStatus CloseReason ) WITH lt_update.

    READ ENTITIES OF zr_cmsm_req IN LOCAL MODE
      ENTITY Request
        ALL FIELDS WITH VALUE #( FOR ls_upd IN lt_update ( %tky = ls_upd-%tky ) )
      RESULT DATA(lt_req).

    result = VALUE #( FOR ls_req IN lt_req ( %tky = ls_req-%tky %param = ls_req ) ).

  ENDMETHOD.


  METHOD cancelrequest.

    DATA lt_update TYPE TABLE FOR UPDATE zr_cmsm_req.

    LOOP AT keys INTO DATA(ls_key).

      IF ls_key-%param-CloseReason IS INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-request.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = '취소 사유를 입력하세요.' ) )
               TO reported-request.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky        = ls_key-%tky
                      ReqStatus   = gc_status-cancelled
                      CloseReason = ls_key-%param-CloseReason ) TO lt_update.

    ENDLOOP.

    IF lt_update IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_cmsm_req IN LOCAL MODE
      ENTITY Request
        UPDATE FIELDS ( ReqStatus CloseReason ) WITH lt_update.

    READ ENTITIES OF zr_cmsm_req IN LOCAL MODE
      ENTITY Request
        ALL FIELDS WITH VALUE #( FOR ls_upd IN lt_update ( %tky = ls_upd-%tky ) )
      RESULT DATA(lt_req).

    result = VALUE #( FOR ls_req IN lt_req ( %tky = ls_req-%tky %param = ls_req ) ).

  ENDMETHOD.


  METHOD setinitialvalues.

    READ ENTITIES OF zr_cmsm_req IN LOCAL MODE
      ENTITY Request
        FIELDS ( ReqStatus ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_req).

    DELETE lt_req WHERE ReqStatus IS NOT INITIAL.
    IF lt_req IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_cmsm_req IN LOCAL MODE
      ENTITY Request
        UPDATE FIELDS ( ReqStatus )
        WITH VALUE #( FOR ls_req IN lt_req
                      ( %tky      = ls_req-%tky
                        ReqStatus = gc_status-requested ) ).

  ENDMETHOD.


  METHOD setreqid.

    DATA lt_update TYPE TABLE FOR UPDATE zr_cmsm_req.

    READ ENTITIES OF zr_cmsm_req IN LOCAL MODE
      ENTITY Request
        FIELDS ( ReqId ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_req).

    DELETE lt_req WHERE ReqId IS NOT INITIAL.

    LOOP AT lt_req INTO DATA(ls_req).

      DATA(lv_id) = zcl_cmsm_display_id=>next( zcl_cmsm_display_id=>gc_range-request ).

      IF lv_id IS INITIAL.
        " 저장은 막지 않는다. 번호 없이 저장되고, 번호 범위를 고친 뒤 다시 저장하면 채번된다
        APPEND VALUE #( %tky = ls_req-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-warning
                                 text     = '요청번호를 채번하지 못했습니다. 번호 범위 ZCMSM_DOID 구간 01을 확인하세요.' ) )
               TO reported-request.
        CONTINUE.
      ENDIF.

      APPEND VALUE #( %tky  = ls_req-%tky
                      ReqId = lv_id ) TO lt_update.

    ENDLOOP.

    IF lt_update IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_cmsm_req IN LOCAL MODE
      ENTITY Request
        UPDATE FIELDS ( ReqId ) WITH lt_update.

  ENDMETHOD.


  METHOD recordhistory.

    DATA lt_hist TYPE TABLE FOR CREATE zr_cmsm_req\_Hist.
    DATA ls_hist LIKE LINE OF lt_hist.
    DATA lv_cid  TYPE i.

    READ ENTITIES OF zr_cmsm_req IN LOCAL MODE
      ENTITY Request
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_req).

    IF lt_req IS INITIAL.
      RETURN.
    ENDIF.

    " 저장 직전이라 DB에는 아직 이전 값이 남아 있다 (새 요청이면 없음)
    SELECT * FROM ztcmsm00170
      FOR ALL ENTRIES IN @lt_req
      WHERE requuid = @lt_req-ReqUuid
      INTO TABLE @DATA(lt_old).

    SELECT Value, Text FROM zi_cmsm_reqstatusvh
      INTO TABLE @mt_status_text.

    LOOP AT lt_req INTO DATA(ls_req).

      DATA(lt_rows) = VALUE tt_hist_row( ).

      READ TABLE lt_old INTO DATA(ls_old) WITH KEY requuid = ls_req-ReqUuid.

      IF sy-subrc <> 0.
        " 생성
        lt_rows = VALUE #( ( kind  = gc_hist_kind-created
                             field = `제목`
                             new   = cut( CONV #( ls_req-Title ) ) ) ).
      ELSE.
        " 상태 변경 (반려·취소면 사유를 같이 남긴다)
        IF ls_old-reqstatus <> ls_req-ReqStatus.
          APPEND VALUE #( kind  = gc_hist_kind-status
                          field = `상태`
                          old   = status_text( CONV #( ls_old-reqstatus ) )
                          new   = status_text( CONV #( ls_req-ReqStatus ) )
                          note  = COND #( WHEN ls_req-ReqStatus = gc_status-rejected
                                            OR ls_req-ReqStatus = gc_status-cancelled
                                          THEN cut( CONV #( ls_req-CloseReason ) ) ) )
                 TO lt_rows.
        ENDIF.

        " 수정
        add_change( EXPORTING iv_field = `제목`          iv_old = CONV #( ls_old-title )      iv_new = CONV #( ls_req-Title )      CHANGING ct_rows = lt_rows ).
        add_change( EXPORTING iv_field = `요청 내용`     iv_old = CONV #( ls_old-reqtext )    iv_new = CONV #( ls_req-ReqText )    CHANGING ct_rows = lt_rows ).
        add_change( EXPORTING iv_field = `모듈`          iv_old = CONV #( ls_old-sapmodule )  iv_new = CONV #( ls_req-SapModule )  CHANGING ct_rows = lt_rows ).
        add_change( EXPORTING iv_field = `담당자`        iv_old = CONV #( ls_old-assignee )   iv_new = CONV #( ls_req-Assignee )   CHANGING ct_rows = lt_rows ).
        add_change( EXPORTING iv_field = `처리 내용`     iv_old = CONV #( ls_old-procresult ) iv_new = CONV #( ls_req-ProcResult ) CHANGING ct_rows = lt_rows ).
        add_change( EXPORTING iv_field = `관련 등록번호` iv_old = CONV #( ls_old-relno )      iv_new = CONV #( ls_req-RelNo )      CHANGING ct_rows = lt_rows ).
      ENDIF.

      IF lt_rows IS INITIAL.
        CONTINUE.
      ENDIF.

      CLEAR ls_hist.
      ls_hist-%tky = ls_req-%tky.

      LOOP AT lt_rows INTO DATA(ls_row).
        lv_cid += 1.
        APPEND VALUE #( %cid      = |HIST{ lv_cid }|
                        %is_draft = ls_req-%is_draft
                        HistKind  = ls_row-kind
                        FieldName = ls_row-field
                        OldValue  = ls_row-old
                        NewValue  = ls_row-new
                        HistNote  = ls_row-note ) TO ls_hist-%target.
      ENDLOOP.

      APPEND ls_hist TO lt_hist.

    ENDLOOP.

    IF lt_hist IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF zr_cmsm_req IN LOCAL MODE
      ENTITY Request
        CREATE BY \_Hist
        FIELDS ( HistKind FieldName OldValue NewValue HistNote )
        WITH lt_hist.

  ENDMETHOD.


  METHOD validatemandatory.

    READ ENTITIES OF zr_cmsm_req IN LOCAL MODE
      ENTITY Request
        FIELDS ( Title SapModule Assignee ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_req).

    LOOP AT lt_req INTO DATA(ls_req).

      " 이전 검사 메시지 지우기
      APPEND VALUE #( %tky        = ls_req-%tky
                      %state_area = 'MANDATORY' ) TO reported-request.

      DATA(lv_failed) = abap_false.

      IF ls_req-Title IS INITIAL.
        lv_failed = abap_true.
        APPEND VALUE #( %tky           = ls_req-%tky
                        %state_area    = 'MANDATORY'
                        %element-Title = if_abap_behv=>mk-on
                        %msg           = new_message_with_text(
                                           severity = if_abap_behv_message=>severity-error
                                           text     = '제목을 입력하세요.' ) )
               TO reported-request.
      ENDIF.

      IF ls_req-SapModule IS INITIAL.
        lv_failed = abap_true.
        APPEND VALUE #( %tky               = ls_req-%tky
                        %state_area        = 'MANDATORY'
                        %element-SapModule = if_abap_behv=>mk-on
                        %msg               = new_message_with_text(
                                               severity = if_abap_behv_message=>severity-error
                                               text     = '모듈을 선택하세요.' ) )
               TO reported-request.
      ENDIF.

      IF ls_req-Assignee IS INITIAL.
        lv_failed = abap_true.
        APPEND VALUE #( %tky              = ls_req-%tky
                        %state_area       = 'MANDATORY'
                        %element-Assignee = if_abap_behv=>mk-on
                        %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = '담당자를 지정하세요.' ) )
               TO reported-request.
      ENDIF.

      IF lv_failed = abap_true.
        APPEND VALUE #( %tky = ls_req-%tky ) TO failed-request.
      ENDIF.

    ENDLOOP.

  ENDMETHOD.


  METHOD add_change.

    IF iv_old <> iv_new.
      APPEND VALUE #( kind  = gc_hist_kind-updated
                      field = iv_field
                      old   = cut( iv_old )
                      new   = cut( iv_new ) ) TO ct_rows.
    ENDIF.

  ENDMETHOD.


  METHOD cut.

    rv_text = COND #( WHEN strlen( iv_text ) > gc_hist_max_len
                      THEN substring( val = iv_text len = gc_hist_max_len )
                      ELSE iv_text ).

  ENDMETHOD.


  METHOD status_text.

    rv_text = COND #( WHEN line_exists( mt_status_text[ value = iv_status ] )
                      THEN mt_status_text[ value = iv_status ]-text
                      ELSE iv_status ).

  ENDMETHOD.

ENDCLASS.


"! 요청 BO saver: 저장이 확정된 뒤(save_modified) 새 요청을 담당자에게 메일로 알린다.
"!
"! - 요청번호는 setReqId(저장 시 determination)가 이미 채워 둔 상태
"! - 메일 본문은 SMW0 템플릿 ZCMSM_REQ_CREATED_MAIL (ZCL_HTML_TEMPLATE 로 값 채움, 값은 HTML 이스케이프됨)
"! - 담당자 메일 주소가 없거나 발송이 실패해도 요청 저장은 그대로 된다
CLASS lsc_zr_cmsm_req DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

  PRIVATE SECTION.

    CONSTANTS:
      " SMW0 > 바이너리 데이터에 올린 메일 템플릿 이름
      gc_mail_template TYPE c LENGTH 40 VALUE 'ZCMSM_REQ_CREATED_MAIL',
      " 보내는 사람: 메일 설정(SCOT)에서 발신이 허용된 주소로 바꾼다
      gc_mail_sender   TYPE string VALUE `noreply@example.com`,
      " 앱 주소(런치패드 URL + 인텐트). 뒤에 &/Request(…) 를 붙여 그 요청 상세를 바로 연다
      gc_app_url       TYPE string VALUE `https://<런치패드 호스트>/ui#<SemanticObject>-<action>`.

    METHODS send_created_mail
      IMPORTING iv_req_uuid   TYPE sysuuid_x16
                iv_req_id     TYPE string
                iv_title      TYPE string
                iv_module     TYPE string
                iv_req_text   TYPE string
                iv_requester  TYPE string
                iv_assignee   TYPE string
                iv_created_at TYPE timestampl.

    "! 사용자 ID → 메일 주소 (ZCM_VH_USER_EMAIL)
    METHODS get_email
      IMPORTING iv_user         TYPE string
      RETURNING VALUE(rv_email) TYPE string.

    "! 사용자 ID → 이름 (없으면 ID)
    METHODS get_user_name
      IMPORTING iv_user        TYPE string
      RETURNING VALUE(rv_name) TYPE string.

    "! 요청 상세 바로가기 링크
    METHODS request_link
      IMPORTING iv_req_uuid    TYPE sysuuid_x16
      RETURNING VALUE(rv_link) TYPE string.

ENDCLASS.


CLASS lsc_zr_cmsm_req IMPLEMENTATION.

  METHOD save_modified.

    " 엑셀 업로드가 저장까지 끝났을 때만 성공 메시지 (저장 검증에 걸리면 save_modified 까지 안 온다)
    "   gv_upload_count 는 uploadexcel 액션에서만 채워지니, 화면에서 만들고 저장할 땐 0 이라 안 뜬다
    IF lhc_request=>gv_upload_count > 0.
      " 특정 건에 붙지 않는 메시지라 %other 로 (화면에는 성공 토스트)
      APPEND new_message_with_text( severity = if_abap_behv_message=>severity-success
                                    text     = |업로드 완료 ({ lhc_request=>gv_upload_count }건)| ) TO reported-%other.
      CLEAR lhc_request=>gv_upload_count.
    ENDIF.

    " 이번 저장에서 새로 생긴 요청만 (드래프트로 만든 요청은 처음 저장(활성화)할 때 여기에 들어온다)
    LOOP AT create-request INTO DATA(ls_req).

      IF ls_req-Assignee IS INITIAL.
        CONTINUE.
      ENDIF.

      send_created_mail( iv_req_uuid   = ls_req-ReqUuid
                         iv_req_id     = CONV #( ls_req-ReqId )
                         iv_title      = CONV #( ls_req-Title )
                         iv_module     = CONV #( ls_req-SapModule )
                         iv_req_text   = ls_req-ReqText
                         iv_requester  = CONV #( ls_req-CreatedBy )
                         iv_assignee   = CONV #( ls_req-Assignee )
                         iv_created_at = ls_req-CreatedAt ).

    ENDLOOP.

  ENDMETHOD.


  METHOD send_created_mail.

    DATA(lv_email) = get_email( iv_assignee ).
    IF lv_email IS INITIAL.
      " 메일 주소가 없으면 보내지 않는다
      RETURN.
    ENDIF.

    SELECT SINGLE Text FROM zi_cmsm_modulevh
      WHERE Value = @iv_module
      INTO @DATA(lv_module_text).

    TRY.
        DATA(lv_html) = zcl_html_template=>create_from_smw0( gc_mail_template
          )->set( iv_name = 'REQID'         iv_value = iv_req_id
          )->set( iv_name = 'TITLE'         iv_value = iv_title
          )->set( iv_name = 'SAPMODULE'     iv_value = COND string( WHEN lv_module_text IS INITIAL
                                                                    THEN iv_module
                                                                    ELSE |{ lv_module_text }| )
          )->set( iv_name = 'REQUESTERNAME' iv_value = get_user_name( iv_requester )
          )->set( iv_name = 'ASSIGNEENAME'  iv_value = get_user_name( iv_assignee )
          )->set( iv_name = 'CREATEDAT'     iv_value = iv_created_at
          )->set( iv_name = 'REQTEXT'       iv_value = iv_req_text
          )->set( iv_name = 'LINK'          iv_value = request_link( iv_req_uuid )
          )->render( ).

        DATA(lo_mail) = cl_bcs_mail_message=>create_instance( ).
        lo_mail->set_sender( gc_mail_sender ).
        lo_mail->add_recipient( lv_email ).
        lo_mail->set_subject( CONV #( |[개발요청] { iv_req_id } { iv_title }| ) ).
        lo_mail->set_main( cl_bcs_mail_textpart=>create_instance( iv_content      = lv_html
                                                                  iv_content_type = 'text/html' ) ).
        lo_mail->send( ).

      CATCH zcx_html_template cx_bcs_mail.
        " 템플릿 미등록, 메일 설정 문제 등. 메일이 안 나가도 요청 저장은 그대로 둔다
    ENDTRY.

  ENDMETHOD.


  METHOD get_email.

    " 필드명이 다르면 이 SELECT 만 고친다 (사용자 ID 필드 · 메일 주소 필드)
    SELECT SINGLE emailaddress FROM zcm_vh_user_email
      WHERE userid = @iv_user
      INTO @rv_email.

  ENDMETHOD.


  METHOD get_user_name.

    SELECT SINGLE PersonFullName FROM zi_cmsm_uservh
      WHERE UserId = @iv_user
      INTO @rv_name.

    IF rv_name IS INITIAL.
      rv_name = iv_user.
    ENDIF.

  ENDMETHOD.


  METHOD request_link.

    " UUID(RAW16) → 8-4-4-4-12 소문자 (OData 키 형식)
    DATA(lv_hex) = to_lower( CONV string( iv_req_uuid ) ).

    rv_link = |{ gc_app_url }&/Request(ReqUuid={ substring( val = lv_hex off = 0  len = 8 ) }-| &&
              |{ substring( val = lv_hex off = 8  len = 4 ) }-| &&
              |{ substring( val = lv_hex off = 12 len = 4 ) }-| &&
              |{ substring( val = lv_hex off = 16 len = 4 ) }-| &&
              |{ substring( val = lv_hex off = 20 len = 12 ) },IsActiveEntity=true)|.

  ENDMETHOD.

ENDCLASS.
