"! 템플릿 다운로드용 HTTP 서비스 핸들러.
"!
"! RAP 액션은 엔티티에 바인딩되므로 엔티티셋이 없으면 URL로 도달할 수 없고,
"! POST라서 <a href>로도 못 받는다. HTTP 서비스로 노출하면 평범한 GET URL이
"! 생겨서 프론트는 링크만 걸면 된다.
"!
"! ADT에서 생성:
"!   New > Other ABAP Repository Object > HTTP Service
"!   Handler Class에 이 클래스를 지정하면 URL이 함께 표시된다.
"!   (보통 /sap/bc/http/sap/<service_name> 형태)
"!
"! 프론트는 그 URL을 그대로 쓰면 끝:
"!   oLink.href = "<HTTP 서비스 URL>";
"!   oLink.download = "Template.xlsx";
CLASS zcl_excel_template_http DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_service_extension.

ENDCLASS.


CLASS zcl_excel_template_http IMPLEMENTATION.

  METHOD if_http_service_extension~handle_request.

    DATA(lv_file_content) = NEW zcl_excel_table_migrator( )->get_template( ).

    response->set_header_field(
      i_name  = 'Content-Type'
      i_value = zcl_excel_table_migrator=>gc_template-mimetype ).

    " attachment로 줘야 브라우저가 표시하지 않고 다운로드한다.
    response->set_header_field(
      i_name  = 'Content-Disposition'
      i_value = |attachment; filename="{ zcl_excel_table_migrator=>gc_template-filename }"| ).

    response->set_binary( lv_file_content ).
    response->set_status( i_code = 200 i_reason = 'OK' ).

  ENDMETHOD.

ENDCLASS.
