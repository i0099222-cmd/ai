*&---------------------------------------------------------------------*
*& 템플릿 다운로드 액션 - RAP 쪽에 필요한 정의 + 핸들러 예시
*&---------------------------------------------------------------------*
*&
*& [1] 액션 결과를 담을 abstract entity (ZI_TemplateFile)
*&     Fiori 쪽에서 이 세 필드를 받아 파일로 저장한다.
*&
*&   @EndUserText.label: 'Template file for download'
*&   define abstract entity ZI_TemplateFile
*&   {
*&     FileName    : abap.string(0);
*&     MimeType    : abap.string(0);
*&     FileContent : abap.rawstring(0);
*&   }
*&
*&
*& [2] behavior definition에 static action 추가
*&     인스턴스와 무관하게 "정해진 템플릿 하나"를 주는 것이므로 static.
*&
*&   define behavior for ZI_ExcelUpload alias ExcelUpload
*&   {
*&     static action downloadTemplate result [1] ZI_TemplateFile;
*&   }
*&
*&
*& [3] behavior implementation (아래 핸들러)
*&---------------------------------------------------------------------*

CLASS lhc_excelupload DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS downloadtemplate FOR MODIFY
      IMPORTING keys FOR ACTION excelupload~downloadtemplate RESULT result.

ENDCLASS.


CLASS lhc_excelupload IMPLEMENTATION.

  METHOD downloadtemplate.

    DATA(lo_migrator) = NEW zcl_excel_table_migrator( ).

    " static action이라 keys는 보통 1건이지만, 형식상 루프로 처리한다.
    LOOP AT keys INTO DATA(ls_key).

      APPEND VALUE #(
        %cid   = ls_key-%cid
        %param = VALUE #(
          filename    = zcl_excel_table_migrator=>gc_template-filename
          mimetype    = zcl_excel_table_migrator=>gc_template-mimetype
          filecontent = lo_migrator->get_template( ) ) )
        TO result.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
