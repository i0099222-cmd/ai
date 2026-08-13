"! 업로드된 CSV를 대상 구조 타입의 내부테이블로 변환한다.
"!
"! DB에는 쓰지 않는다. 쓰기는 호출부(behavior implementation)가 EML로 하므로
"! RAP LUW 안에 머물고, COMMIT WORK나 별도 세션이 필요 없다.
"!
"! 파일은 액션 파라미터가 아니라 @Semantics.largeObject 스트림으로 들어온다.
"! 표준 Fiori 업로드 컨트롤이 파일을 테이블에 저장하므로 UI5 코드가 필요 없고,
"! 바이너리가 잘리거나 base64로 뒤틀릴 일도 없다.
"!
"! CSV 형식 전제: 1행 = 헤더, 2행부터 = 데이터, 컬럼 순서 = 대상 구조 필드 순서.
CLASS zcl_excel_table_migrator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! @parameter iv_file_content | 업로드된 CSV 바이너리
    "! @parameter iv_delimiter    | 구분자. 한국/유럽 로케일 엑셀은 세미콜론으로 저장한다.
    "! @parameter ct_data         | 대상 구조 타입의 내부테이블. 파싱 결과가 append된다.
    METHODS parse
      IMPORTING
        iv_file_content TYPE xstring
        iv_delimiter    TYPE c DEFAULT ','
      CHANGING
        ct_data         TYPE STANDARD TABLE.

ENDCLASS.


CLASS zcl_excel_table_migrator IMPLEMENTATION.

  METHOD parse.

    DATA(lv_bytes) = iv_file_content.

    " UTF-8 BOM을 떼지 않으면 첫 필드 앞에 안 보이는 문자가 붙는다.
    IF xstrlen( lv_bytes ) >= 3 AND lv_bytes(3) = 'EFBBBF'.
      lv_bytes = lv_bytes+3.
    ENDIF.

    " XCO는 릴리즈 API라 클라우드에서 래퍼 없이 쓸 수 있다.
    DATA(lv_content) = xco_cp=>xstring( lv_bytes
      )->as_string( xco_cp_character=>code_page->utf_8 )->value.

    " 줄바꿈은 CRLF일 수도 LF일 수도 있다.
    REPLACE ALL OCCURRENCES OF |\r\n| IN lv_content WITH |\n|.
    SPLIT lv_content AT |\n| INTO TABLE DATA(lt_lines).

    " 1행은 헤더.
    DELETE lt_lines INDEX 1.

    FIELD-SYMBOLS <lv_field> TYPE any.

    LOOP AT lt_lines INTO DATA(lv_line).

      " 파일 끝에 딸려오는 빈 줄은 건너뛴다.
      IF lv_line IS INITIAL.
        CONTINUE.
      ENDIF.

      SPLIT lv_line AT iv_delimiter INTO TABLE DATA(lt_values).

      APPEND INITIAL LINE TO ct_data ASSIGNING FIELD-SYMBOL(<ls_row>).

      LOOP AT lt_values INTO DATA(lv_value).

        DATA(lv_index) = sy-tabix.

        " 대상 구조 필드 수보다 컬럼이 많으면 초과분은 버린다.
        UNASSIGN <lv_field>.
        ASSIGN COMPONENT lv_index OF STRUCTURE <ls_row> TO <lv_field>.

        IF <lv_field> IS ASSIGNED.
          <lv_field> = lv_value.
        ENDIF.

      ENDLOOP.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
