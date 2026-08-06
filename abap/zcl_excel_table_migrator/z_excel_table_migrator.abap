*&---------------------------------------------------------------------*
*& Report Z_EXCEL_TABLE_MIGRATOR
*&---------------------------------------------------------------------*
*& SE38/ADT에서 아래대로 생성 (Standard ABAP 언어버전 패키지):
*&   Selection Screen Parameter: P_REQID TYPE SYSUUID_X16
*&
*&   이 리포트는 RAP 액션에서 직접 호출되지 않고, Z_EXCEL_MIGR_SCHEDULE_JOB
*&   함수모듈이 백그라운드 잡으로 SUBMIT한다. 그래서 이 리포트 자체는
*&   ABAP Cloud 릴리즈 대상이 아니며, 동적 테이블명 INSERT/RTTI/
*&   CL_FDT_XL_SPREADSHEET 등 Standard ABAP 전용 기능을 자유롭게 쓸 수 있다.
*&
*&   대상 테이블 화이트리스트/권한 재검증은 ABAP Cloud 클래스인
*&   ZCL_EXCEL_TABLE_MIGRATOR=>CHECK_TABLE_ALLOWED를 그대로 재사용한다
*&   (Standard ABAP 프로그램이 ABAP Cloud 릴리즈 클래스를 호출하는 것은
*&    허용되는 방향이다 - 반대 방향만 릴리즈가 필요).
*&
*&   TODO: CL_FDT_XL_SPREADSHEET의 GET_ITAB_FROM_SHEET 시그니처는 시스템
*&   릴리즈에 따라 조금씩 다를 수 있으므로, 실제 시스템에서 클래스 빌더로
*&   재확인 후 아래 파싱 로직을 맞춰 넣을 것. 여기서는 "1행 = 헤더(필드명),
*&   2행부터 = 데이터"라는 전제로 골격만 제공한다.
*&---------------------------------------------------------------------*
REPORT z_excel_table_migrator.

PARAMETERS p_reqid TYPE sysuuid_x16.

CONSTANTS gc_package_size TYPE i VALUE 5000.

DATA: gs_req      TYPE zexcel_migr_req,
      gv_total    TYPE i,
      gv_ok       TYPE i,
      gv_error    TYPE i,
      gv_message  TYPE string.

START-OF-SELECTION.

  PERFORM load_request.
  PERFORM validate_table.
  PERFORM mark_status USING 'P'.  " Processing
  PERFORM parse_and_migrate.
  PERFORM mark_final_status.


*&---------------------------------------------------------------------*
FORM load_request.

  SELECT SINGLE * FROM zexcel_migr_req
    WHERE request_id = @p_reqid
    INTO @gs_req.

  IF sy-subrc <> 0.
    MESSAGE '요청을 찾을 수 없습니다' TYPE 'E'.
  ENDIF.

ENDFORM.


*&---------------------------------------------------------------------*
FORM validate_table.

  " 접수 시점(accept_request)에 이미 1차 검증했지만, 잡 실행 시점에는
  " 화이트리스트/권한이 바뀌었을 수도 있으므로 실제 INSERT 직전에 재검증한다.
  DATA(lv_allowed) = NEW zcl_excel_table_migrator( )->zif_excel_table_migrator~check_table_allowed(
    iv_tabname = gs_req-tabname ).

  IF lv_allowed = abap_false.
    gv_message = |대상 테이블 { gs_req-tabname }에 대한 권한이 없거나 화이트리스트에 없습니다|.
    PERFORM mark_status USING 'E'.
    MESSAGE gv_message TYPE 'E'.
  ENDIF.

ENDFORM.


*&---------------------------------------------------------------------*
FORM parse_and_migrate.

  " 1) 엑셀 바이너리 파싱 (헤더 1행 + 데이터).
  TRY.
      DATA(lo_excel) = NEW cl_fdt_xl_spreadsheet(
        document_name = gs_req-filename
        xdocument     = gs_req-file_content ).

      lo_excel->if_fdt_doc_spreadsheet~get_worksheet_names(
        IMPORTING worksheet_names = DATA(lt_sheets) ).

      lo_excel->if_fdt_doc_spreadsheet~get_itab_from_sheet(
        EXPORTING worksheet_id = lt_sheets[ 1 ]
        IMPORTING itab         = DATA(lr_raw) ).

    CATCH cx_fdt_spreadsheet INTO DATA(lx_excel).
      gv_message = |엑셀 파싱 실패: { lx_excel->get_text( ) }|.
      PERFORM mark_status USING 'E'.
      RETURN.
  ENDTRY.

  ASSIGN lr_raw->* TO FIELD-SYMBOL(<lt_raw>).

  IF <lt_raw> IS NOT ASSIGNED OR lines( <lt_raw> ) < 2.
    gv_message = '데이터 행이 없습니다 (헤더만 존재하거나 빈 파일)'.
    PERFORM mark_status USING 'E'.
    RETURN.
  ENDIF.

  " 헤더 행 = 대상 테이블 필드명 (대소문자 무관하게 매칭).
  READ TABLE <lt_raw> ASSIGNING FIELD-SYMBOL(<ls_header>) INDEX 1.
  DATA lt_fieldnames TYPE string_table.
  PERFORM row_to_strings USING <ls_header> CHANGING lt_fieldnames.

  gv_total = lines( <lt_raw> ) - 1.

  " 2) 대상 테이블 구조를 RTTI로 조회해서 동적 워크에어리어/내부테이블 생성.
  DATA(lo_struct) = CAST cl_abap_structdescr(
    cl_abap_structdescr=>describe_by_name( gs_req-tabname ) ).
  DATA(lo_tabletype) = cl_abap_tabledescr=>create( lo_struct ).

  DATA lr_package TYPE REF TO data.
  CREATE DATA lr_package TYPE HANDLE lo_tabletype.
  ASSIGN lr_package->* TO FIELD-SYMBOL(<lt_package>).

  DATA lr_wa TYPE REF TO data.
  DATA lt_values TYPE string_table.

  " 3) 데이터 행을 package 단위로 묶어서 동적 INSERT + 건별 커밋.
  "    - 대량 업로드 하나를 여러 개의 작은 LUW로 쪼개서 롱런/락 확대를 피한다.
  "    - 한 package가 실패해도 이미 커밋된 이전 package는 남으므로,
  "      재실행 시 ACCEPTING DUPLICATE KEYS로 중복은 건너뛰고 이어서 처리 가능.
  DATA(lv_row_no) = 0.

  LOOP AT <lt_raw> ASSIGNING FIELD-SYMBOL(<ls_row>) FROM 2.

    lv_row_no = lv_row_no + 1.
    PERFORM row_to_strings USING <ls_row> CHANGING lt_values.

    CREATE DATA lr_wa TYPE HANDLE lo_struct.
    ASSIGN lr_wa->* TO FIELD-SYMBOL(<ls_wa>).

    DATA(lv_row_ok) = abap_true.

    LOOP AT lt_fieldnames INTO DATA(lv_fieldname).
      ASSIGN COMPONENT lv_fieldname OF STRUCTURE <ls_wa> TO FIELD-SYMBOL(<lv_field>).
      IF sy-subrc <> 0.
        CONTINUE.   " 대상 테이블에 없는 컬럼은 무시 (엑셀에 여분 컬럼이 있는 경우)
      ENDIF.

      TRY.
          <lv_field> = lt_values[ sy-tabix ].
        CATCH cx_sy_conversion_no_number cx_sy_conversion_error.
          lv_row_ok = abap_false.
      ENDTRY.
    ENDLOOP.

    IF lv_row_ok = abap_false.
      gv_error = gv_error + 1.
      CONTINUE.
    ENDIF.

    INSERT <ls_wa> INTO TABLE <lt_package>.

    IF lines( <lt_package> ) >= gc_package_size OR lv_row_no = gv_total.
      PERFORM insert_package USING <lt_package>.
      CLEAR <lt_package>.
    ENDIF.

  ENDLOOP.

ENDFORM.


*&---------------------------------------------------------------------*
FORM insert_package USING it_package TYPE ANY TABLE.

  DATA(lv_before) = lines( it_package ).

  " 대상 테이블명은 accept_request/validate_table에서 화이트리스트 +
  " AUTHORITY-CHECK로 이미 검증된 값만 여기까지 도달한다.
  INSERT (gs_req-tabname) FROM TABLE it_package ACCEPTING DUPLICATE KEYS.

  IF sy-subrc = 0.
    gv_ok = gv_ok + lv_before.
  ELSEIF sy-subrc = 4.
    " 일부 중복키는 건너뛰고 나머지만 반영됨 - 정확한 성공/중복 건수 구분이
    " 필요하면 package를 더 잘게 쪼개거나 키 존재 여부를 사전 체크할 것.
    gv_ok = gv_ok + lv_before.
  ELSE.
    gv_error = gv_error + lv_before.
    ROLLBACK WORK.
    PERFORM update_progress.
    RETURN.
  ENDIF.

  COMMIT WORK AND WAIT.
  PERFORM update_progress.

ENDFORM.


*&---------------------------------------------------------------------*
FORM update_progress.

  UPDATE zexcel_migr_req
    SET processed_rows = @gv_ok
        error_rows     = @gv_error
    WHERE request_id = @gs_req-request_id.
  COMMIT WORK.

ENDFORM.


*&---------------------------------------------------------------------*
FORM mark_status USING iv_status TYPE char1.

  UPDATE zexcel_migr_req
    SET status  = @iv_status
        message = @gv_message
    WHERE request_id = @gs_req-request_id.
  COMMIT WORK.

ENDFORM.


*&---------------------------------------------------------------------*
FORM mark_final_status.

  DATA(lv_status) = COND char1( WHEN gv_error = 0 THEN 'S' ELSE 'E' ).
  gv_message = |총 { gv_total } 건 중 성공 { gv_ok } / 실패 { gv_error }|.
  PERFORM mark_status USING lv_status.

ENDFORM.


*&---------------------------------------------------------------------*
FORM row_to_strings USING is_row TYPE any
  CHANGING ct_values TYPE string_table.

  " 가정: GET_ITAB_FROM_SHEET가 돌려주는 각 행은 STRING_TABLE(셀 값을
  " 컬럼 순서대로 담은 테이블)이다. 실제 시스템에서 확인한 리턴 타입이
  " 이와 다르면(예: 구조체에 컬럼 수만큼 동적 필드가 있는 형태), 이 FORM만
  " 그 타입에 맞게 교체하면 된다 - 호출부(PARSE_AND_MIGRATE)는 그대로 둬도 됨.
  CLEAR ct_values.

  DATA(lo_descr) = cl_abap_typedescr=>describe_by_data( is_row ).

  IF lo_descr->kind = cl_abap_typedescr=>kind_table.
    FIELD-SYMBOLS <lt_cells> TYPE string_table.
    ASSIGN is_row TO <lt_cells> CASTING.
    ct_values = <lt_cells>.
  ELSE.
    " 구조체 형태로 오는 경우: 컴포넌트를 순서대로 순회하며 문자열로 변환.
    DATA(lo_struct) = CAST cl_abap_structdescr( lo_descr ).
    LOOP AT lo_struct->components INTO DATA(ls_component).
      ASSIGN COMPONENT ls_component-name OF STRUCTURE is_row TO FIELD-SYMBOL(<lv_cell>).
      IF sy-subrc = 0.
        APPEND |{ <lv_cell> }| TO ct_values.
      ENDIF.
    ENDLOOP.
  ENDIF.

ENDFORM.
