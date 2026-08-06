"! 예시: RAP BO(예: ZI_ExcelUpload)의 behavior implementation에서
"! 공통 클래스 zcl_excel_table_migrator를 호출하는 uploadExcel 액션 구현 예시.
"!
"! CDS behavior definition에 필요한 정의 (예시):
"!   define behavior for ZI_ExcelUpload alias ExcelUpload
"!   {
"!     action ( features : instance ) uploadExcel
"!       parameter ZI_ExcelUploadParams result [1] $self;
"!   }
"!
"! ZI_ExcelUploadParams (액션 파라미터 구조체, abstract entity로 정의):
"!   TabName      : TABNAME;   " 마이그레이션 대상 테이블명
"!   FileName     : STRING;
"!   FileContent  : ABAP.RAWSTRING; " xlsx 바이너리 (Fiori 파일 업로드 컨트롤에서 전달)
"!
"! 프론트엔드(UI5)는 파일을 파싱하지 않고 바이너리 그대로 액션 파라미터로
"! 전달한다 - 파싱은 백엔드(CL_FDT_XL_SPREADSHEET, Standard ABAP)에서 수행한다.
CLASS lhc_excelupload DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS uploadexcel FOR MODIFY
      IMPORTING keys FOR ACTION excelupload~uploadexcel RESULT result.

ENDCLASS.


CLASS lhc_excelupload IMPLEMENTATION.

  METHOD uploadexcel.

    DATA(lo_migrator) = NEW zcl_excel_table_migrator( ).

    LOOP AT keys INTO DATA(ls_key).

      TRY.

          DATA(ls_accept_result) = lo_migrator->zif_excel_table_migrator~accept_request(
            VALUE #(
              tabname      = ls_key-%param-tabname
              filename     = ls_key-%param-filename
              file_content = ls_key-%param-filecontent ) ).

          APPEND VALUE #( %tky = ls_key-%tky ) TO mapped-excelupload.

          " 접수만 완료된 상태 - 실제 처리 결과는 ZEXCEL_MIGR_REQ를 request_id로
          " 조회해서 확인한다 (예: 별도 조회용 CDS 뷰/액션을 두는 것을 권장).
          APPEND VALUE #(
            %tky = ls_key-%tky
            %msg = new_message(
                     id       = 'ZEXCEL_MIGR'
                     number   = '000'
                     v1       = CONV sysuuid_c32( ls_accept_result-request_id )
                     v2       = ls_accept_result-job_name
                     severity = if_abap_behv_message=>severity-information ) )
            TO reported-excelupload.

        CATCH zcx_excel_migr_error INTO DATA(lx_error).

          APPEND VALUE #( %tky = ls_key-%tky ) TO failed-excelupload.

          APPEND VALUE #(
            %tky = ls_key-%tky
            %msg = lx_error )
            TO reported-excelupload.

      ENDTRY.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
