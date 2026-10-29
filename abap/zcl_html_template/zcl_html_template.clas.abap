" HTML 템플릿 치환 공통 클래스.
" SMW0 등에 올린 HTML 템플릿을 읽어 {{이름}} 자리를 값으로 바꾼다.
"
" 템플릿 문법 (이름은 대소문자, 앞뒤 공백 무시)
"   {{NAME}}                  값 치환 (HTML 이스케이프됨)
"   {{&NAME}}                 값 치환 (이스케이프 안 함: HTML 조각을 그대로 넣을 때)
"   {{#ITEMS}} ... {{/ITEMS}} set_table 로 넘긴 테이블이면 행마다 반복,
"                             set 으로 넘긴 값이면 initial 이 아닐 때만 1회 출력
"   {{^ITEMS}} ... {{/ITEMS}} 위의 반대: 빈 테이블 / initial 값 / 미지정일 때만 출력
"   {{! 주석 }}               출력하지 않음
"   반복 블록 안에서는 행의 필드, 바깥에서 지정한 값,
"   {{_INDEX}}(1부터 시작하는 행 번호)를 쓸 수 있다.
"
" 사용 예
"   DATA(lv_html) = zcl_html_template=>create_from_smw0( 'ZPR_APPROVAL_MAIL'
"     )->set_structure( ls_header
"     )->set( iv_name = 'TODAY' iv_value = cl_abap_context_info=>get_system_date( )
"     )->set_table( iv_name = 'ITEMS' it_data = lt_item
"     )->render( ).
"
" 치환은 템플릿을 한 번만 훑으면서 하므로, 값 안에 {{...}} 가 들어 있어도
" 다시 치환되지 않는다.
" 이 클래스는 문자열만 다루므로 ABAP Cloud 언어버전으로 두어도 되며,
" released API 가 아닌 SMW0 조회는 zcl_html_template_smw0 에만 있다.
CLASS zcl_html_template DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    "! 금액 필드명 → 통화키 필드명 매핑.
    "! KRW, JPY 처럼 소수 자리가 없는 통화를 올바르게 표시하기 위해 쓴다.
    TYPES:
      BEGIN OF ty_amount_field,
        amount   TYPE string,
        currency TYPE string,
      END OF ty_amount_field,
      tt_amount_field TYPE STANDARD TABLE OF ty_amount_field WITH EMPTY KEY.

    CONSTANTS:
      c_open  TYPE string VALUE `{{`,
      c_close TYPE string VALUE `}}`.

    "! SMW0(웹 저장소 > 바이너리 데이터)에 업로드한 HTML 로 템플릿 생성
    "! @parameter iv_objid    | SMW0 오브젝트명
    "! @parameter iv_codepage | 파일 인코딩
    CLASS-METHODS create_from_smw0
      IMPORTING
        iv_objid           TYPE csequence
        iv_codepage        TYPE string DEFAULT `UTF-8`
      RETURNING
        VALUE(ro_template) TYPE REF TO zcl_html_template
      RAISING
        zcx_html_template.

    "! 바이너리(RAWSTRING 컬럼, 첨부파일 등)로 템플릿 생성. UTF-8 BOM 은 제거한다.
    "! @parameter iv_content  | 파일 내용
    "! @parameter iv_codepage | 파일 인코딩
    CLASS-METHODS create_from_xstring
      IMPORTING
        iv_content         TYPE xstring
        iv_codepage        TYPE string DEFAULT `UTF-8`
      RETURNING
        VALUE(ro_template) TYPE REF TO zcl_html_template
      RAISING
        zcx_html_template.

    "! 문자열로 템플릿 생성 (STRING 컬럼 등 이미 문자열로 읽은 경우)
    CLASS-METHODS create_from_string
      IMPORTING
        iv_template        TYPE string
      RETURNING
        VALUE(ro_template) TYPE REF TO zcl_html_template.

    METHODS constructor
      IMPORTING
        iv_template TYPE string.

    "! 값 1개 지정. 같은 이름으로 다시 지정하면 덮어쓴다.
    "! 날짜/시간/숫자/타임스탬프는 사용자 설정 형식으로 변환된다.
    "! @parameter iv_raw | X: HTML 이스케이프 없이 그대로 삽입 (HTML 조각)
    METHODS set
      IMPORTING
        iv_name        TYPE csequence
        iv_value       TYPE simple
        iv_raw         TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(ro_self) TYPE REF TO zcl_html_template.

    "! 금액 지정. 통화별 소수 자리(KRW, JPY 등)를 반영해 변환한다.
    METHODS set_amount
      IMPORTING
        iv_name        TYPE csequence
        iv_amount      TYPE p
        iv_currency    TYPE csequence
      RETURNING
        VALUE(ro_self) TYPE REF TO zcl_html_template.

    "! 구조체의 elementary 필드를 필드명 그대로 한꺼번에 지정 (예: {{COMPANYCODE}})
    "! @parameter iv_prefix | 필드명 앞에 붙일 접두어 (예: HDR_ 이면 {{HDR_COMPANYCODE}})
    "! @parameter it_amount | 통화키를 참조해 변환할 금액 필드
    METHODS set_structure
      IMPORTING
        is_data        TYPE any
        iv_prefix      TYPE csequence OPTIONAL
        it_amount      TYPE tt_amount_field OPTIONAL
      RETURNING
        VALUE(ro_self) TYPE REF TO zcl_html_template.

    "! 반복 블록 {{#NAME}}...{{/NAME}} 에 쓸 테이블 지정.
    "! 행의 필드명이 블록 안에서 쓰는 이름이 된다.
    "! 행이 구조체가 아니면(예: string_table) 블록 안에서 {{LINE}} 으로 쓴다.
    "! @parameter it_amount | 통화키를 참조해 변환할 금액 필드
    METHODS set_table
      IMPORTING
        iv_name        TYPE csequence
        it_data        TYPE ANY TABLE
        it_amount      TYPE tt_amount_field OPTIONAL
      RETURNING
        VALUE(ro_self) TYPE REF TO zcl_html_template.

    "! 치환한 HTML 반환
    "! @parameter iv_strict | X: 템플릿에 값이 지정되지 않은 이름이 있으면 예외.
    "!                        공백: 빈 문자열로 치환
    "! @raising zcx_html_template | 태그가 닫히지 않는 등 템플릿 문법 오류, 엄격 모드의 값 누락
    METHODS render
      IMPORTING
        iv_strict      TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rv_html) TYPE string
      RAISING
        zcx_html_template.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_param,
        name       TYPE string,
        value      TYPE string,
        raw        TYPE abap_bool,
        is_initial TYPE abap_bool,
      END OF ty_param,
      tt_param TYPE HASHED TABLE OF ty_param WITH UNIQUE KEY name,
      tt_row   TYPE STANDARD TABLE OF tt_param WITH EMPTY KEY,

      BEGIN OF ty_block,
        name  TYPE string,
        t_row TYPE tt_row,
      END OF ty_block,
      tt_block TYPE HASHED TABLE OF ty_block WITH UNIQUE KEY name,

      "! 템플릿 안의 {{...}} 1개
      BEGIN OF ty_tag,
        begin_off TYPE i,           " 여는 구분자 위치 (-1: 더 이상 태그 없음)
        end_off   TYPE i,           " 닫는 구분자 다음 위치
        kind      TYPE c LENGTH 1,  " # ^ / & ! 또는 공백(일반 값)
        name      TYPE string,
      END OF ty_tag.

    DATA mv_template TYPE string.
    DATA mt_param    TYPE tt_param.
    DATA mt_block    TYPE tt_block.
    DATA mv_strict   TYPE abap_bool.
    DATA mv_timezone TYPE c LENGTH 6.

    METHODS render_part
      IMPORTING
        iv_template    TYPE string
        it_param       TYPE tt_param
      RETURNING
        VALUE(rv_html) TYPE string
      RAISING
        zcx_html_template.

    METHODS render_section
      IMPORTING
        is_tag         TYPE ty_tag
        iv_inner       TYPE string
        it_param       TYPE tt_param
      RETURNING
        VALUE(rv_html) TYPE string
      RAISING
        zcx_html_template.

    METHODS resolve_value
      IMPORTING
        is_tag         TYPE ty_tag
        it_param       TYPE tt_param
      RETURNING
        VALUE(rv_text) TYPE string
      RAISING
        zcx_html_template.

    CLASS-METHODS find_tag
      IMPORTING
        iv_template   TYPE string
        iv_from       TYPE i
      RETURNING
        VALUE(rs_tag) TYPE ty_tag
      RAISING
        zcx_html_template.

    CLASS-METHODS find_close_tag
      IMPORTING
        iv_template     TYPE string
        is_open         TYPE ty_tag
      RETURNING
        VALUE(rs_close) TYPE ty_tag
      RAISING
        zcx_html_template.

    METHODS struct_to_params
      IMPORTING
        is_data         TYPE any
        iv_prefix       TYPE csequence OPTIONAL
        it_amount       TYPE tt_amount_field OPTIONAL
      RETURNING
        VALUE(rt_param) TYPE tt_param.

    METHODS make_param
      IMPORTING
        iv_name         TYPE csequence
        iv_value        TYPE any
        iv_raw          TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rs_param) TYPE ty_param.

    METHODS to_text
      IMPORTING
        iv_value       TYPE any
      RETURNING
        VALUE(rv_text) TYPE string.

    CLASS-METHODS format_amount
      IMPORTING
        iv_amount      TYPE p
        iv_currency    TYPE csequence
      RETURNING
        VALUE(rv_text) TYPE string.

    CLASS-METHODS put_param
      IMPORTING
        is_param TYPE ty_param
      CHANGING
        ct_param TYPE tt_param.

ENDCLASS.


CLASS zcl_html_template IMPLEMENTATION.

  METHOD create_from_smw0.

    ro_template = create_from_xstring(
      iv_content  = zcl_html_template_smw0=>read( iv_objid )
      iv_codepage = iv_codepage ).

  ENDMETHOD.


  METHOD create_from_xstring.

    CONSTANTS lc_utf8_bom TYPE x LENGTH 3 VALUE 'EFBBBF'.

    DATA lv_template TYPE string.

    " 메모장 등에서 UTF-8 로 저장하면 앞에 BOM 이 붙어 화면에 깨진 문자로 보이므로 제거
    DATA(lv_content) = iv_content.
    IF xstrlen( lv_content ) >= 3 AND lv_content(3) = lc_utf8_bom.
      lv_content = lv_content+3.
    ENDIF.

    TRY.
        lv_template = cl_abap_conv_codepage=>create_in( codepage = iv_codepage
          )->convert( source = lv_content ).
      CATCH cx_sy_conversion_codepage cx_parameter_invalid_range INTO DATA(lx_conv).
        RAISE EXCEPTION NEW zcx_html_template(
          iv_text  = |템플릿을 { iv_codepage } 로 변환하지 못했습니다.|
          previous = lx_conv ).
    ENDTRY.

    ro_template = NEW #( lv_template ).

  ENDMETHOD.


  METHOD create_from_string.

    ro_template = NEW #( iv_template ).

  ENDMETHOD.


  METHOD constructor.

    mv_template = iv_template.

    " 타임스탬프 필드를 사용자 시간대로 표시하기 위함 (조회 실패 시 UTC)
    TRY.
        mv_timezone = cl_abap_context_info=>get_user_time_zone( ).
      CATCH cx_abap_context_info_error.
        CLEAR mv_timezone.
    ENDTRY.

  ENDMETHOD.


  METHOD set.

    put_param( EXPORTING is_param = make_param( iv_name  = iv_name
                                                iv_value = iv_value
                                                iv_raw   = iv_raw )
               CHANGING  ct_param = mt_param ).
    ro_self = me.

  ENDMETHOD.


  METHOD set_amount.

    DATA(ls_param) = make_param( iv_name = iv_name iv_value = iv_amount ).
    ls_param-value = format_amount( iv_amount = iv_amount iv_currency = iv_currency ).

    put_param( EXPORTING is_param = ls_param
               CHANGING  ct_param = mt_param ).
    ro_self = me.

  ENDMETHOD.


  METHOD set_structure.

    DATA(lt_param) = struct_to_params( is_data   = is_data
                                       iv_prefix = iv_prefix
                                       it_amount = it_amount ).

    LOOP AT lt_param INTO DATA(ls_param).
      put_param( EXPORTING is_param = ls_param
                 CHANGING  ct_param = mt_param ).
    ENDLOOP.
    ro_self = me.

  ENDMETHOD.


  METHOD set_table.

    DATA lt_row TYPE tt_row.

    LOOP AT it_data ASSIGNING FIELD-SYMBOL(<ls_line>).
      APPEND struct_to_params( is_data = <ls_line> it_amount = it_amount ) TO lt_row.
    ENDLOOP.

    DATA(lv_name) = to_upper( condense( iv_name ) ).
    DELETE TABLE mt_block WITH TABLE KEY name = lv_name.
    INSERT VALUE #( name = lv_name t_row = lt_row ) INTO TABLE mt_block.
    ro_self = me.

  ENDMETHOD.


  METHOD render.

    mv_strict = iv_strict.
    rv_html = render_part( iv_template = mv_template
                           it_param    = mt_param ).

  ENDMETHOD.


  METHOD render_part.

    DATA lv_pos TYPE i.

    DO.

      DATA(ls_tag) = find_tag( iv_template = iv_template iv_from = lv_pos ).

      IF ls_tag-begin_off < 0.
        rv_html = rv_html && substring( val = iv_template off = lv_pos ).
        RETURN.
      ENDIF.

      rv_html = rv_html && substring( val = iv_template
                                      off = lv_pos
                                      len = ls_tag-begin_off - lv_pos ).
      lv_pos = ls_tag-end_off.

      CASE ls_tag-kind.

        WHEN '!'.
          " 주석은 출력하지 않는다.

        WHEN '#' OR '^'.
          DATA(ls_close) = find_close_tag( iv_template = iv_template is_open = ls_tag ).
          rv_html = rv_html && render_section(
            is_tag   = ls_tag
            iv_inner = substring( val = iv_template
                                  off = ls_tag-end_off
                                  len = ls_close-begin_off - ls_tag-end_off )
            it_param = it_param ).
          lv_pos = ls_close-end_off.

        WHEN '/'.
          RAISE EXCEPTION NEW zcx_html_template(
            iv_text = |{ c_open }/{ ls_tag-name }{ c_close } 에 해당하는 여는 태그가 없습니다.| ).

        WHEN OTHERS.
          rv_html = rv_html && resolve_value( is_tag = ls_tag it_param = it_param ).

      ENDCASE.

    ENDDO.

  ENDMETHOD.


  METHOD render_section.

    DATA(lv_inverted) = xsdbool( is_tag-kind = '^' ).

    " 1) set_table 로 지정한 테이블: 행마다 반복 (^ 이면 행이 없을 때만 1회)
    READ TABLE mt_block WITH TABLE KEY name = is_tag-name ASSIGNING FIELD-SYMBOL(<ls_block>).
    IF sy-subrc = 0.

      IF lv_inverted = abap_true.
        IF <ls_block>-t_row IS INITIAL.
          rv_html = render_part( iv_template = iv_inner it_param = it_param ).
        ENDIF.
        RETURN.
      ENDIF.

      LOOP AT <ls_block>-t_row INTO DATA(lt_row_param).
        DATA(lv_index) = sy-tabix.

        " 행의 값이 바깥 값보다 우선한다.
        DATA(lt_scope) = it_param.
        LOOP AT lt_row_param INTO DATA(ls_row_param).
          put_param( EXPORTING is_param = ls_row_param
                     CHANGING  ct_param = lt_scope ).
        ENDLOOP.
        put_param( EXPORTING is_param = make_param( iv_name = `_INDEX` iv_value = lv_index )
                   CHANGING  ct_param = lt_scope ).

        rv_html = rv_html && render_part( iv_template = iv_inner it_param = lt_scope ).
      ENDLOOP.
      RETURN.

    ENDIF.

    " 2) set 으로 지정한 값: initial 이 아니면 1회 (^ 이면 initial 일 때 1회)
    READ TABLE it_param WITH TABLE KEY name = is_tag-name INTO DATA(ls_param).
    IF sy-subrc <> 0.
      IF mv_strict = abap_true.
        RAISE EXCEPTION NEW zcx_html_template(
          iv_text = |템플릿의 { c_open }{ is_tag-kind }{ is_tag-name }{ c_close } 에 지정된 값이 없습니다.| ).
      ENDIF.
      " 지정하지 않은 이름은 initial 로 본다.
      ls_param-is_initial = abap_true.
    ENDIF.

    IF ls_param-is_initial = lv_inverted.
      rv_html = render_part( iv_template = iv_inner it_param = it_param ).
    ENDIF.

  ENDMETHOD.


  METHOD resolve_value.

    READ TABLE it_param WITH TABLE KEY name = is_tag-name INTO DATA(ls_param).
    IF sy-subrc <> 0.
      IF mv_strict = abap_true.
        RAISE EXCEPTION NEW zcx_html_template(
          iv_text = |템플릿의 { c_open }{ is_tag-name }{ c_close } 에 지정된 값이 없습니다.| ).
      ENDIF.
      " 엄격 모드가 아니면 빈 문자열로 치환한다.
      RETURN.
    ENDIF.

    IF ls_param-raw = abap_true OR is_tag-kind = '&'.
      rv_text = ls_param-value.
    ELSE.
      " 본문뿐 아니라 href="{{URL}}" 같은 속성값에 들어가도 안전하도록 따옴표까지 이스케이프
      rv_text = escape( val = ls_param-value format = cl_abap_format=>e_html_attr ).
    ENDIF.

  ENDMETHOD.


  METHOD find_tag.

    rs_tag-begin_off = find( val = iv_template sub = c_open off = iv_from ).
    IF rs_tag-begin_off < 0.
      RETURN.
    ENDIF.

    DATA(lv_content_off) = rs_tag-begin_off + strlen( c_open ).
    DATA(lv_close_off) = find( val = iv_template sub = c_close off = lv_content_off ).
    IF lv_close_off < 0.
      RAISE EXCEPTION NEW zcx_html_template(
        iv_text = |{ rs_tag-begin_off } 번째 문자에서 시작한 { c_open } 가 { c_close } 로 닫히지 않았습니다.| ).
    ENDIF.

    rs_tag-end_off = lv_close_off + strlen( c_close ).

    DATA(lv_content) = condense( substring( val = iv_template
                                            off = lv_content_off
                                            len = lv_close_off - lv_content_off ) ).
    IF lv_content IS INITIAL.
      RAISE EXCEPTION NEW zcx_html_template(
        iv_text = |{ rs_tag-begin_off } 번째 문자에 빈 태그 { c_open }{ c_close } 가 있습니다.| ).
    ENDIF.

    DATA(lv_first) = substring( val = lv_content len = 1 ).
    IF lv_first CA '#^/&!'.
      rs_tag-kind = lv_first.
      rs_tag-name = to_upper( condense( substring( val = lv_content off = 1 ) ) ).
      IF rs_tag-name IS INITIAL AND rs_tag-kind <> '!'.
        RAISE EXCEPTION NEW zcx_html_template(
          iv_text = |{ rs_tag-begin_off } 번째 문자의 { c_open }{ lv_first }{ c_close } 에 이름이 없습니다.| ).
      ENDIF.
    ELSE.
      rs_tag-kind = space.
      rs_tag-name = to_upper( lv_content ).
    ENDIF.

  ENDMETHOD.


  METHOD find_close_tag.

    " 같은 이름의 블록이 중첩될 수 있으므로 깊이를 세면서 짝이 맞는 닫는 태그를 찾는다.
    DATA(lv_depth) = 1.
    DATA(lv_pos) = is_open-end_off.

    DO.

      rs_close = find_tag( iv_template = iv_template iv_from = lv_pos ).
      IF rs_close-begin_off < 0.
        RAISE EXCEPTION NEW zcx_html_template(
          iv_text = |{ c_open }{ is_open-kind }{ is_open-name }{ c_close } 블록이 { c_open }/{ is_open-name }{ c_close } 로 닫히지 않았습니다.| ).
      ENDIF.
      lv_pos = rs_close-end_off.

      IF rs_close-name = is_open-name.
        CASE rs_close-kind.
          WHEN '#' OR '^'.
            lv_depth = lv_depth + 1.
          WHEN '/'.
            lv_depth = lv_depth - 1.
            IF lv_depth = 0.
              RETURN.
            ENDIF.
        ENDCASE.
      ENDIF.

    ENDDO.

  ENDMETHOD.


  METHOD struct_to_params.

    DATA lv_component TYPE string.

    DATA(lo_type) = cl_abap_typedescr=>describe_by_data( is_data ).

    IF lo_type->kind = cl_abap_typedescr=>kind_elem.
      INSERT make_param( iv_name = |{ iv_prefix }LINE| iv_value = is_data ) INTO TABLE rt_param.
      RETURN.
    ELSEIF lo_type->kind <> cl_abap_typedescr=>kind_struct.
      RETURN.
    ENDIF.

    " RAP 파생 타입(%control 등)처럼 중첩 구조체/테이블/참조 필드는 건너뛴다.
    DATA(lt_component) = CAST cl_abap_structdescr( lo_type )->components.
    LOOP AT lt_component INTO DATA(ls_component).
      ASSIGN COMPONENT ls_component-name OF STRUCTURE is_data TO FIELD-SYMBOL(<lv_value>).
      IF sy-subrc = 0.
        IF cl_abap_typedescr=>describe_by_data( <lv_value> )->kind = cl_abap_typedescr=>kind_elem.
          INSERT make_param( iv_name  = |{ iv_prefix }{ ls_component-name }|
                             iv_value = <lv_value> ) INTO TABLE rt_param.
        ENDIF.
      ENDIF.
    ENDLOOP.

    " CURR 필드는 통화키 필드를 참조해 통화별 소수 자리로 다시 변환한다.
    LOOP AT it_amount INTO DATA(ls_amount).

      lv_component = to_upper( ls_amount-amount ).
      ASSIGN COMPONENT lv_component OF STRUCTURE is_data TO FIELD-SYMBOL(<lv_amount>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      IF cl_abap_typedescr=>describe_by_data( <lv_amount> )->type_kind <> cl_abap_typedescr=>typekind_packed.
        CONTINUE.
      ENDIF.

      lv_component = to_upper( ls_amount-currency ).
      ASSIGN COMPONENT lv_component OF STRUCTURE is_data TO FIELD-SYMBOL(<lv_currency>).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      DATA(ls_param) = make_param( iv_name = |{ iv_prefix }{ ls_amount-amount }| iv_value = <lv_amount> ).
      ls_param-value = format_amount( iv_amount = <lv_amount> iv_currency = <lv_currency> ).
      put_param( EXPORTING is_param = ls_param
                 CHANGING  ct_param = rt_param ).

    ENDLOOP.

  ENDMETHOD.


  METHOD make_param.

    rs_param = VALUE #( name       = to_upper( condense( iv_name ) )
                        value      = to_text( iv_value )
                        raw        = iv_raw
                        is_initial = xsdbool( iv_value IS INITIAL ) ).

  ENDMETHOD.


  METHOD to_text.

    FIELD-SYMBOLS <lv_packed> TYPE p.

    DATA lv_timestamp TYPE timestampl.
    DATA lv_utclong   TYPE utclong.
    DATA lv_date      TYPE d.
    DATA lv_time      TYPE t.

    DATA(lo_type) = cl_abap_typedescr=>describe_by_data( iv_value ).

    CASE lo_type->type_kind.

      WHEN cl_abap_typedescr=>typekind_date.
        " 00000000 은 빈 칸으로 표시
        IF iv_value IS NOT INITIAL.
          rv_text = |{ CONV d( iv_value ) DATE = ENVIRONMENT }|.
        ENDIF.

      WHEN cl_abap_typedescr=>typekind_time.
        rv_text = |{ CONV t( iv_value ) TIME = ENVIRONMENT }|.

      WHEN cl_abap_typedescr=>typekind_utclong.
        IF iv_value IS NOT INITIAL.
          lv_utclong = iv_value.
          CONVERT UTCLONG lv_utclong TIME ZONE mv_timezone INTO DATE lv_date TIME lv_time.
          rv_text = |{ lv_date DATE = ENVIRONMENT } { lv_time TIME = ENVIRONMENT }|.
        ENDIF.

      WHEN cl_abap_typedescr=>typekind_packed.
        ASSIGN iv_value TO <lv_packed>.

        " TIMESTAMP(L) 계열 데이터 요소(RAP 관리 필드 등)는 숫자가 아니라 일시로 표시
        DATA(lv_type_name) = lo_type->get_relative_name( ).
        IF ( lv_type_name CS 'TIMESTAMP' OR lv_type_name CS 'TSTMP' )
           AND ( ( lo_type->length = 8 AND lo_type->decimals = 0 )
              OR ( lo_type->length = 11 AND lo_type->decimals = 7 ) ).
          IF iv_value IS NOT INITIAL.
            lv_timestamp = <lv_packed>.
            CONVERT TIME STAMP lv_timestamp TIME ZONE mv_timezone INTO DATE lv_date TIME lv_time.
            rv_text = |{ lv_date DATE = ENVIRONMENT } { lv_time TIME = ENVIRONMENT }|.
          ENDIF.
        ELSE.
          rv_text = |{ <lv_packed> NUMBER = ENVIRONMENT }|.
        ENDIF.

      WHEN cl_abap_typedescr=>typekind_int
        OR cl_abap_typedescr=>typekind_int1
        OR cl_abap_typedescr=>typekind_int2
        OR cl_abap_typedescr=>typekind_int8
        OR cl_abap_typedescr=>typekind_float
        OR cl_abap_typedescr=>typekind_decfloat16
        OR cl_abap_typedescr=>typekind_decfloat34.
        rv_text = |{ CONV decfloat34( iv_value ) NUMBER = ENVIRONMENT }|.

      WHEN OTHERS.
        rv_text = |{ iv_value }|.

    ENDCASE.

  ENDMETHOD.


  METHOD format_amount.

    " CURRENCY 지정 시 내부값(KRW 10,000 → 100.00)을 통화의 소수 자리(TCURX)에 맞게 표시
    rv_text = |{ iv_amount CURRENCY = iv_currency NUMBER = ENVIRONMENT }|.

  ENDMETHOD.


  METHOD put_param.

    " 같은 이름이 있으면 덮어쓴다.
    DELETE TABLE ct_param WITH TABLE KEY name = is_param-name.
    INSERT is_param INTO TABLE ct_param.

  ENDMETHOD.

ENDCLASS.
