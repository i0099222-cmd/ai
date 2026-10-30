CLASS zcl_cm_excel_drm DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    "! DRM 엑셀을 해제해서 et_data에 채워줌
    "! - et_data 행 구조의 필드 순서 = 엑셀 컬럼 순서 (A열 → 1번째 필드)
    "! - 필드는 string 타입 권장 (숫자/날짜는 변환 오류 가능)
    "! - 헤더 행은 et_data에 들어가지 않고 et_header로 반환
    "! - 일일 호출 한도: zif_cm_excel_drm=>c_daily_limit
    CLASS-METHODS read_drm_excel
      IMPORTING iv_file       TYPE xstring
                iv_filename   TYPE string
                iv_empno      TYPE string
                iv_key        TYPE string
                iv_sheet_no   TYPE i         DEFAULT 1
                iv_header_row TYPE i         DEFAULT 1
                iv_start_row  TYPE i         DEFAULT 2
                iv_skip_empty TYPE abap_bool DEFAULT abap_true
      EXPORTING et_data       TYPE STANDARD TABLE
                et_header     TYPE string_table
      RAISING   zcx_cm_drm.

    "! itab → 엑셀(xlsx) 바이너리
    "! - 1행: it_header (컬럼 순서대로), 2행부터: it_data (헤더가 없으면 1행부터)
    "! - 원본 파일이 아니라 값만 들어간 1시트짜리 새 파일 (서식/수식/병합 없음, DRM 없음)
    CLASS-METHODS convert_itab_to_excel
      IMPORTING it_data        TYPE STANDARD TABLE
                it_header      TYPE string_table OPTIONAL
      RETURNING VALUE(rv_file) TYPE xstring
      RAISING   zcx_cm_drm.

  PRIVATE SECTION.
    CLASS-METHODS check_daily_limit
      RAISING zcx_cm_drm.

    CLASS-METHODS upload_cdn_file
      IMPORTING iv_file              TYPE xstring
                iv_filename          TYPE string
                iv_empno             TYPE string
                iv_key               TYPE string
      RETURNING VALUE(rs_upload_res) TYPE zif_cm_excel_drm=>ty_s_excel_upload_res
      RAISING   zcx_cm_drm.

    CLASS-METHODS call_excel_parse_api
      IMPORTING is_upload_res  TYPE zif_cm_excel_drm=>ty_s_excel_upload_res
                iv_header_row  TYPE i
                iv_start_row   TYPE i
                iv_empno       TYPE string
      RETURNING VALUE(rs_resp) TYPE zif_cm_excel_drm=>ty_s_parse_res
      RAISING   zcx_cm_drm.

    CLASS-METHODS fill_target_table
      IMPORTING it_rows       TYPE zif_cm_excel_drm=>tt_rows
                iv_start_row  TYPE i
                iv_skip_empty TYPE abap_bool
      EXPORTING et_data       TYPE STANDARD TABLE
      RAISING   zcx_cm_drm.

    CLASS-METHODS delete_cdn_file
      IMPORTING iv_seq   TYPE string
                iv_empno TYPE string
                iv_key   TYPE string.
ENDCLASS.


CLASS zcl_cm_excel_drm IMPLEMENTATION.

  METHOD read_drm_excel.
    CLEAR: et_data, et_header.

    IF iv_file IS INITIAL.
      RAISE EXCEPTION NEW zcx_cm_drm( iv_text = `파일이 비어 있습니다` ).
    ENDIF.

    IF iv_start_row <= iv_header_row.
      RAISE EXCEPTION NEW zcx_cm_drm(
        iv_text = |시작 행({ iv_start_row })은 헤더 행({ iv_header_row })보다 커야 합니다| ).
    ENDIF.

    " 0. 일일 한도 체크 (업로드 전)
    check_daily_limit( ).

    " 1. CDN 업로드
    DATA(ls_upload_res) = upload_cdn_file( iv_file     = iv_file
                                           iv_filename = iv_filename
                                           iv_empno    = iv_empno
                                           iv_key      = iv_key ).
    TRY.
        " 2. 엑셀 파싱
        DATA(ls_parse_res) = call_excel_parse_api( is_upload_res = ls_upload_res
                                                   iv_header_row = iv_header_row
                                                   iv_start_row  = iv_start_row
                                                   iv_empno      = iv_empno ).

        IF NOT line_exists( ls_parse_res-datas[ iv_sheet_no ] ).
          RAISE EXCEPTION NEW zcx_cm_drm( iv_text = |{ iv_sheet_no }번째 시트가 없습니다| ).
        ENDIF.

        " 3. 대상 itab 채우기
        et_header = VALUE #( ls_parse_res-headers[ iv_sheet_no ]-header OPTIONAL ).

        fill_target_table( EXPORTING it_rows       = ls_parse_res-datas[ iv_sheet_no ]-sheet
                                     iv_start_row  = iv_start_row
                                     iv_skip_empty = iv_skip_empty
                           IMPORTING et_data       = et_data ).
      CLEANUP.
        " 에러로 빠져나갈 때: 일부만 채워진 결과를 비우고 CDN 파일 삭제
        CLEAR: et_data, et_header.
        delete_cdn_file( iv_seq = ls_upload_res-seq iv_empno = iv_empno iv_key = iv_key ).
    ENDTRY.

    " 4. 정상 종료 시 CDN 파일 삭제
    delete_cdn_file( iv_seq = ls_upload_res-seq iv_empno = iv_empno iv_key = iv_key ).
  ENDMETHOD.


  METHOD convert_itab_to_excel.
    TRY.
        DATA(lo_write) = xco_cp_xlsx=>document->empty( )->write_access( ).
        DATA(lo_sheet) = lo_write->get_workbook( )->worksheet->at_position( 1 ).

        " 1행: 헤더
        IF it_header IS NOT INITIAL.
          DATA(lo_cursor) = lo_sheet->cursor( io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
                                              io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( 1 ) ).
          LOOP AT it_header INTO DATA(lv_header).
            lo_cursor->get_cell( )->value->write_from( lv_header ).
            lo_cursor->move_right( ).
          ENDLOOP.
        ENDIF.

        " 데이터: 헤더가 있으면 2행부터, 없으면 1행부터
        IF it_data IS NOT INITIAL.
          DATA(lv_data_row) = COND i( WHEN it_header IS INITIAL THEN 1 ELSE 2 ).

          DATA(lo_pattern) = xco_cp_xlsx_selection=>pattern_builder->simple_from_to(
                               )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
                               )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( lv_data_row )
                               )->get_pattern( ).

          lo_sheet->select( lo_pattern
            )->row_stream(
            )->operation->write_from( REF #( it_data )
            )->execute( ).
        ENDIF.

        rv_file = lo_write->get_file_content( ).

      CATCH cx_xco_runtime_exception INTO DATA(lx_xco).
        RAISE EXCEPTION NEW zcx_cm_drm( iv_text  = |엑셀 생성 실패: { lx_xco->get_text( ) }|
                                        previous = lx_xco ).
    ENDTRY.
  ENDMETHOD.


  METHOD check_daily_limit.
    DATA: lv_now      TYPE timestamp,
          lv_today    TYPE d,
          lv_midnight TYPE t VALUE '000000',
          lv_from     TYPE timestamp.

    " 현재 UTC 시각 → 한국 기준 오늘 날짜
    GET TIME STAMP FIELD lv_now.
    CONVERT TIME STAMP lv_now TIME ZONE zif_cm_excel_drm=>c_limit_tz
            INTO DATE lv_today.
    IF sy-subrc <> 0.
      RAISE EXCEPTION NEW zcx_cm_drm( iv_text = |타임존 변환 실패 ({ zif_cm_excel_drm=>c_limit_tz })| ).
    ENDIF.

    " 한국 기준 오늘 00:00:00 → UTC (예: 10/29 00:00 KST → 20261028150000)
    CONVERT DATE lv_today TIME lv_midnight
            INTO TIME STAMP lv_from TIME ZONE zif_cm_excel_drm=>c_limit_tz.
    IF sy-subrc <> 0 OR lv_from IS INITIAL.
      RAISE EXCEPTION NEW zcx_cm_drm( iv_text = |기준 시각 계산 실패 ({ lv_today })| ).
    ENDIF.

    SELECT COUNT(*)
      FROM zcm_if_log                                       " 실제 로그 테이블명으로
      WHERE apiid          = @zif_cm_excel_drm=>c_apiid-parse
        AND starttimestamp >= @lv_from
      INTO @DATA(lv_count).

    IF lv_count >= zif_cm_excel_drm=>c_daily_limit.
      RAISE EXCEPTION NEW zcx_cm_drm(
        iv_text = |일일 DRM 변환 한도({ zif_cm_excel_drm=>c_daily_limit }건)를 초과했습니다. 내일 다시 시도해 주세요.| ).
    ENDIF.
  ENDMETHOD.


  METHOD upload_cdn_file.
    TRY.
        zcl_cm_if_communication=>run(
          EXPORTING iv_apiid     = zif_cm_excel_drm=>c_apiid-upload
                    it_multipart = VALUE #(
                      ( name = zif_cm_excel_drm=>c_upload_field-key   text = iv_key )
                      ( name = zif_cm_excel_drm=>c_upload_field-empno text = iv_empno )
                      ( name     = zif_cm_excel_drm=>c_upload_field-file
                        filename = iv_filename
                        binary   = iv_file ) )          " content_type은 확장자로 자동 판단
          IMPORTING es_data      = rs_upload_res ).
      CATCH cx_root INTO DATA(lx).                      " run이 던지는 실제 예외 클래스로
        RAISE EXCEPTION NEW zcx_cm_drm( iv_text  = |CDN 업로드 실패: { lx->get_text( ) }|
                                        previous = lx ).
    ENDTRY.

    IF rs_upload_res-code <> zif_cm_excel_drm=>c_upload_ok.
      RAISE EXCEPTION NEW zcx_cm_drm( iv_text = |CDN 업로드 오류 ({ rs_upload_res-code })| ).
    ENDIF.
  ENDMETHOD.


  METHOD call_excel_parse_api.
    TRY.
        zcl_cm_if_communication=>run(
          EXPORTING iv_apiid = zif_cm_excel_drm=>c_apiid-parse
                    is_body  = VALUE zif_cm_excel_drm=>ty_s_parse_body(
                                 file          = CORRESPONDING #( is_upload_res )
                                 header        = VALUE #( headertype = 1 headerrow = iv_header_row )
                                 startrow      = iv_start_row
                                 returntype    = zif_cm_excel_drm=>c_return_type_json
                                 requesteruser = iv_empno )
          IMPORTING es_data  = rs_resp ).
      CATCH cx_root INTO DATA(lx).                      " run이 던지는 실제 예외 클래스로
        RAISE EXCEPTION NEW zcx_cm_drm( iv_text  = |파싱 API 호출 실패: { lx->get_text( ) }|
                                        previous = lx ).
    ENDTRY.

    IF rs_resp-code <> zif_cm_excel_drm=>c_parse_ok.
      RAISE EXCEPTION NEW zcx_cm_drm( iv_text = |파싱 API 오류 ({ rs_resp-code })| ).
    ENDIF.

    IF rs_resp-parsestatus <> zif_cm_excel_drm=>c_parse_status_done.
      RAISE EXCEPTION NEW zcx_cm_drm( iv_text = |파싱 미완료 (상태: { rs_resp-parsestatus })| ).
    ENDIF.

    IF rs_resp-datas IS INITIAL.
      RAISE EXCEPTION NEW zcx_cm_drm( iv_text = `파싱 결과가 비어 있습니다` ).
    ENDIF.
  ENDMETHOD.


  METHOD fill_target_table.
    DATA lr_line TYPE REF TO data.

    CREATE DATA lr_line LIKE LINE OF et_data.
    ASSIGN lr_line->* TO FIELD-SYMBOL(<ls_line>).

    IF cl_abap_typedescr=>describe_by_data( <ls_line> )->kind <> cl_abap_typedescr=>kind_struct.
      RAISE EXCEPTION NEW zcx_cm_drm( iv_text = `et_data는 구조체 테이블이어야 합니다` ).
    ENDIF.

    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<lt_row>).
      DATA(lv_excel_row) = iv_start_row + sy-tabix - 1.
      CLEAR <ls_line>.

      LOOP AT <lt_row> ASSIGNING FIELD-SYMBOL(<lv_value>).
        DATA(lv_col_no) = sy-tabix.

        ASSIGN COMPONENT lv_col_no OF STRUCTURE <ls_line> TO FIELD-SYMBOL(<lv_field>).
        IF sy-subrc <> 0.
          EXIT.                                 " 구조보다 엑셀 컬럼이 많으면 나머지 무시
        ENDIF.

        TRY.
            <lv_field> = <lv_value>.
          CATCH cx_sy_conversion_error INTO DATA(lx_conv).
            RAISE EXCEPTION NEW zcx_cm_drm( iv_text  = |{ lv_excel_row }행 { lv_col_no }열 값 변환 오류: { <lv_value> }|
                                            previous = lx_conv ).
        ENDTRY.
      ENDLOOP.

      IF iv_skip_empty = abap_true AND <ls_line> IS INITIAL.
        CONTINUE.
      ENDIF.

      APPEND <ls_line> TO et_data.
    ENDLOOP.
  ENDMETHOD.


  METHOD delete_cdn_file.
    " 삭제에 실패해도 결과는 돌려주도록 예외를 무시 (필요하면 애플리케이션 로그 기록)
    TRY.
        zcl_cm_if_communication=>run(
          EXPORTING iv_apiid = zif_cm_excel_drm=>c_apiid-delete
                    is_body  = VALUE zif_cm_excel_drm=>ty_s_del_body( seq   = iv_seq
                                                                      empno = iv_empno
                                                                      key   = iv_key ) ).
      CATCH cx_root.                                    " run이 던지는 실제 예외 클래스로
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
