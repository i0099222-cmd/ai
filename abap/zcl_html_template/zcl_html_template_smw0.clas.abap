"! SMW0(웹 저장소 > 바이너리 데이터, RELID 'MI')에 올린 파일 내용을 읽는다.
"! WWWDATA_IMPORT / WWWDATA / WWWPARAMS 는 released API 가 아니므로
"! 이 클래스만 Standard ABAP 언어버전으로 만들고,
"! API State 에서 "Use in Cloud Development"(C1)로 릴리즈한다.
"! 그러면 ABAP Cloud 언어버전인 zcl_html_template 에서 호출할 수 있다.
"! (zcl_html_template 도 Standard ABAP 언어버전으로 만든다면 릴리즈는 필요 없다.)
CLASS zcl_html_template_smw0 DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    "! @parameter iv_objid   | SMW0 오브젝트명
    "! @parameter rv_content | 파일 내용
    "! @raising zcx_html_template | 오브젝트가 없거나 읽기 실패
    CLASS-METHODS read
      IMPORTING
        iv_objid          TYPE csequence
      RETURNING
        VALUE(rv_content) TYPE xstring
      RAISING
        zcx_html_template.

ENDCLASS.


CLASS zcl_html_template_smw0 IMPLEMENTATION.

  METHOD read.

    DATA lt_mime TYPE STANDARD TABLE OF w3mime WITH EMPTY KEY.

    DATA(ls_key) = VALUE wwwdatatab( relid = 'MI'
                                     objid = to_upper( condense( iv_objid ) ) ).

    SELECT SINGLE @abap_true
      FROM wwwdata
      WHERE relid = @ls_key-relid
        AND objid = @ls_key-objid
      INTO @DATA(lv_exists).

    IF lv_exists = abap_false.
      RAISE EXCEPTION NEW zcx_html_template(
        iv_text = |SMW0 바이너리 데이터에 { ls_key-objid } 이(가) 없습니다.| ).
    ENDIF.

    CALL FUNCTION 'WWWDATA_IMPORT'
      EXPORTING
        key               = ls_key
      TABLES
        mime              = lt_mime
      EXCEPTIONS
        wrong_object_type = 1
        import_error      = 2
        OTHERS            = 3.

    IF sy-subrc <> 0.
      RAISE EXCEPTION NEW zcx_html_template(
        iv_text = |SMW0 의 { ls_key-objid } 을(를) 읽지 못했습니다.| ).
    ENDIF.

    LOOP AT lt_mime INTO DATA(ls_mime).
      CONCATENATE rv_content ls_mime-line INTO rv_content IN BYTE MODE.
    ENDLOOP.

    " w3mime 은 255바이트 단위라 마지막 행 뒤가 0x00 으로 채워져 있으므로
    " 업로드 시 저장된 실제 파일 크기로 잘라낸다.
    SELECT SINGLE value
      FROM wwwparams
      WHERE relid = @ls_key-relid
        AND objid = @ls_key-objid
        AND name  = 'filesize'
      INTO @DATA(lv_filesize).

    DATA(lv_size) = CONV i( condense( lv_filesize ) ).
    IF lv_size > 0 AND lv_size < xstrlen( rv_content ).
      rv_content = rv_content(lv_size).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
