"! zcl_html_template 의 치환 규칙 테스트.
"! 날짜/숫자/금액 형식은 사용자 설정에 따라 달라지므로 문자 값 위주로 확인한다.
CLASS ltc_render DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_item,
        material TYPE c LENGTH 10,
        unit     TYPE c LENGTH 3,
      END OF ty_item,
      tt_item TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

    METHODS value_is_html_escaped     FOR TESTING RAISING zcx_html_template.
    METHODS raw_value_is_not_escaped  FOR TESTING RAISING zcx_html_template.
    METHODS value_is_not_reparsed     FOR TESTING RAISING zcx_html_template.
    METHODS structure_with_prefix     FOR TESTING RAISING zcx_html_template.
    METHODS table_block_repeats_rows  FOR TESTING RAISING zcx_html_template.
    METHODS empty_table_inverted      FOR TESTING RAISING zcx_html_template.
    METHODS flag_section              FOR TESTING RAISING zcx_html_template.
    METHODS initial_date_is_empty     FOR TESTING RAISING zcx_html_template.
    METHODS comment_is_removed        FOR TESTING RAISING zcx_html_template.
    METHODS missing_value_is_empty    FOR TESTING RAISING zcx_html_template.
    METHODS strict_mode_raises        FOR TESTING.
    METHODS unclosed_block_raises     FOR TESTING.
    METHODS stray_close_tag_raises    FOR TESTING.

ENDCLASS.


CLASS ltc_render IMPLEMENTATION.

  METHOD value_is_html_escaped.

    DATA(lv_html) = zcl_html_template=>create_from_string( `<p>{{ name }}</p>`
      )->set( iv_name = 'NAME' iv_value = `A&B <C>`
      )->render( ).

    cl_abap_unit_assert=>assert_equals( exp = `<p>A&amp;B &lt;C&gt;</p>` act = lv_html ).

  ENDMETHOD.


  METHOD raw_value_is_not_escaped.

    DATA(lv_html) = zcl_html_template=>create_from_string( `{{&A}}|{{B}}`
      )->set( iv_name = 'A' iv_value = `<b>x</b>`
      )->set( iv_name = 'B' iv_value = `<i>y</i>` iv_raw = abap_true
      )->render( ).

    cl_abap_unit_assert=>assert_equals( exp = `<b>x</b>|<i>y</i>` act = lv_html ).

  ENDMETHOD.


  METHOD value_is_not_reparsed.

    DATA(lv_html) = zcl_html_template=>create_from_string( `{{A}}`
      )->set( iv_name = 'A' iv_value = `{{B}}`
      )->set( iv_name = 'B' iv_value = `x`
      )->render( ).

    cl_abap_unit_assert=>assert_equals( exp = `{{B}}` act = lv_html ).

  ENDMETHOD.


  METHOD structure_with_prefix.

    TYPES:
      BEGIN OF ty_header,
        companycode    TYPE c LENGTH 4,
        accountingdoc  TYPE c LENGTH 10,
      END OF ty_header.

    DATA(ls_header) = VALUE ty_header( companycode = '1000' accountingdoc = '0100000001' ).

    DATA(lv_html) = zcl_html_template=>create_from_string( `{{HDR_COMPANYCODE}}-{{hdr_accountingdoc}}`
      )->set_structure( is_data = ls_header iv_prefix = 'HDR_'
      )->render( ).

    cl_abap_unit_assert=>assert_equals( exp = `1000-0100000001` act = lv_html ).

  ENDMETHOD.


  METHOD table_block_repeats_rows.

    DATA(lt_item) = VALUE tt_item( ( material = 'MAT-A' unit = 'EA' )
                                   ( material = 'MAT-B' unit = 'KG' ) ).

    DATA(lv_html) = zcl_html_template=>create_from_string(
        `<ul>{{#ITEMS}}<li>{{_INDEX}}.{{MATERIAL}} {{UNIT}} {{TITLE}}</li>{{/ITEMS}}</ul>`
      )->set( iv_name = 'TITLE' iv_value = `t`
      )->set_table( iv_name = 'ITEMS' it_data = lt_item
      )->render( ).

    cl_abap_unit_assert=>assert_equals(
      exp = `<ul><li>1.MAT-A EA t</li><li>2.MAT-B KG t</li></ul>`
      act = lv_html ).

  ENDMETHOD.


  METHOD empty_table_inverted.

    DATA lt_item TYPE tt_item.

    DATA(lv_html) = zcl_html_template=>create_from_string(
        `{{#ITEMS}}row{{/ITEMS}}{{^ITEMS}}none{{/ITEMS}}`
      )->set_table( iv_name = 'ITEMS' it_data = lt_item
      )->render( ).

    cl_abap_unit_assert=>assert_equals( exp = `none` act = lv_html ).

  ENDMETHOD.


  METHOD flag_section.

    DATA(lo_template) = zcl_html_template=>create_from_string(
      `{{#REJECTED}}반려: {{REASON}}{{/REJECTED}}{{^REJECTED}}승인{{/REJECTED}}` ).

    cl_abap_unit_assert=>assert_equals(
      exp = `반려: 금액 초과`
      act = lo_template->set( iv_name = 'REJECTED' iv_value = abap_true
                     )->set( iv_name = 'REASON' iv_value = `금액 초과`
                     )->render( ) ).

    cl_abap_unit_assert=>assert_equals(
      exp = `승인`
      act = lo_template->set( iv_name = 'REJECTED' iv_value = abap_false )->render( ) ).

  ENDMETHOD.


  METHOD initial_date_is_empty.

    DATA(lv_html) = zcl_html_template=>create_from_string( `[{{D}}]`
      )->set( iv_name = 'D' iv_value = VALUE d( )
      )->render( ).

    cl_abap_unit_assert=>assert_equals( exp = `[]` act = lv_html ).

  ENDMETHOD.


  METHOD comment_is_removed.

    DATA(lv_html) = zcl_html_template=>create_from_string( `a{{! 메모 }}b` )->render( ).

    cl_abap_unit_assert=>assert_equals( exp = `ab` act = lv_html ).

  ENDMETHOD.


  METHOD missing_value_is_empty.

    DATA(lv_html) = zcl_html_template=>create_from_string( `[{{NOPE}}]{{#NOPE}}x{{/NOPE}}` )->render( ).

    cl_abap_unit_assert=>assert_equals( exp = `[]` act = lv_html ).

  ENDMETHOD.


  METHOD strict_mode_raises.

    TRY.
        zcl_html_template=>create_from_string( `{{NOPE}}` )->render( iv_strict = abap_true ).
        cl_abap_unit_assert=>fail( msg = '값이 없는데 예외가 발생하지 않음' ).
      CATCH zcx_html_template ##NO_HANDLER.
        " 기대한 예외
    ENDTRY.

  ENDMETHOD.


  METHOD unclosed_block_raises.

    TRY.
        zcl_html_template=>create_from_string( `{{#ITEMS}}x` )->render( ).
        cl_abap_unit_assert=>fail( msg = '닫히지 않은 블록인데 예외가 발생하지 않음' ).
      CATCH zcx_html_template ##NO_HANDLER.
        " 기대한 예외
    ENDTRY.

  ENDMETHOD.


  METHOD stray_close_tag_raises.

    TRY.
        zcl_html_template=>create_from_string( `x{{/ITEMS}}` )->render( ).
        cl_abap_unit_assert=>fail( msg = '여는 태그 없는 닫는 태그인데 예외가 발생하지 않음' ).
      CATCH zcx_html_template ##NO_HANDLER.
        " 기대한 예외
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
