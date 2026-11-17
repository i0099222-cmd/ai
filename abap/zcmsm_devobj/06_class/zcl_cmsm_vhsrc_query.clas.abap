"! Value Help 데이터 소스 조회 — custom entity ZCE_CMSM_VhSource 의 쿼리 클래스
"!
"! VH 이름(CDS view entity)의 정의를 XCO 로 읽어서
"!   - 메인 데이터 소스 (select from …)
"!   - 연관(association) 대상
"! 을 돌려준다. 저장하지 않으니 CDS 를 고치면 다음에 열 때 바로 반영된다.
"! 읽지 못하는 것: join 대상, Search Help 로 만든 VH, DDIC 기반 CDS 뷰(define view) → 빈 목록
CLASS zcl_cmsm_vhsrc_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_rap_query_provider.

    TYPES tt_source TYPE STANDARD TABLE OF zce_cmsm_vhsource WITH EMPTY KEY.

    "! VH 하나의 데이터 소스 (class run 등에서 따로 시험해 볼 수 있게 public)
    METHODS read_sources
      IMPORTING iv_vh_name       TYPE string
      RETURNING VALUE(rt_source) TYPE tt_source.

  PRIVATE SECTION.

    "! 뷰 내용(content->get( ) 결과)에서 메인 데이터 소스 이름 찾기.
    "! XCO 버전마다 구조가 조금씩 달라서 DATA_SOURCE 항목을 동적으로 찾는다.
    METHODS main_source_name
      IMPORTING is_content     TYPE any
      RETURNING VALUE(rv_name) TYPE string.

    "! 소스 이름 → 유형 (CDS / 테이블 / 도메인 고정값 / 확인 불가)
    METHODS source_kind
      IMPORTING iv_name        TYPE string
      RETURNING VALUE(rv_kind) TYPE string.

    "! 문자형이면 값, 아니면 빈 값
    METHODS char_value
      IMPORTING ia_data         TYPE any
      RETURNING VALUE(rv_value) TYPE string.

ENDCLASS.


CLASS zcl_cmsm_vhsrc_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

    DATA lt_result TYPE tt_source.
    DATA lt_page   TYPE tt_source.

    " 필터: VH 상세에서 열면 연관 조건(VhName = 그 VH 이름)이 필터로 들어온다
    TRY.
        DATA(lt_filter) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR lt_filter.
    ENDTRY.

    LOOP AT lt_filter INTO DATA(ls_filter) WHERE name = 'VHNAME'.
      LOOP AT ls_filter-range INTO DATA(ls_range) WHERE sign = 'I' AND option = 'EQ'.
        APPEND LINES OF read_sources( CONV #( ls_range-low ) ) TO lt_result.
      ENDLOOP.
    ENDLOOP.

    " 정렬은 순번 고정 (요청 정렬 정보는 읽기만)
    DATA(lt_sort) = io_request->get_sort_elements( ).
    SORT lt_result BY vhname srcpos.

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_result ) ).
    ENDIF.

    IF io_request->is_data_requested( ).
      DATA(lv_offset) = io_request->get_paging( )->get_offset( ).
      DATA(lv_size)   = io_request->get_paging( )->get_page_size( ).
      IF lv_size = if_rap_query_paging=>page_size_unlimited.
        lv_size = lines( lt_result ).
      ENDIF.
      DATA(lv_from) = lv_offset + 1.
      LOOP AT lt_result INTO DATA(ls_row) FROM lv_from.
        IF lines( lt_page ) >= lv_size.
          EXIT.
        ENDIF.
        APPEND ls_row TO lt_page.
      ENDLOOP.
      io_response->set_data( lt_page ).
    ENDIF.

  ENDMETHOD.


  METHOD read_sources.

    DATA lv_pos TYPE i.

    DATA(lv_name) = to_upper( condense( iv_vh_name ) ).
    IF lv_name IS INITIAL OR strlen( lv_name ) > 30.
      RETURN.
    ENDIF.

    DATA(lo_view) = xco_cp_cds=>view_entity( CONV #( lv_name ) ).
    IF lo_view->exists( ) = abap_false.
      " CDS view entity 가 아니면 (Search Help, DDIC 기반 CDS 뷰 등) 빈 목록
      RETURN.
    ENDIF.

    " 1) 메인 데이터 소스 (select from …)
    DATA(lv_main) = main_source_name( lo_view->content( )->get( ) ).
    IF lv_main IS NOT INITIAL.
      lv_pos += 1.
      APPEND VALUE #( vhname  = lv_name
                      srcpos  = lv_pos
                      srcrole = '메인 소스'
                      srckind = source_kind( lv_main )
                      srcname = lv_main ) TO rt_source.
    ENDIF.

    " 2) 연관 대상
    LOOP AT lo_view->associations->all->get( ) INTO DATA(lo_assoc).
      DATA(lv_target) = condense( CONV string( lo_assoc->content( )->get( )-target ) ).
      IF lv_target IS INITIAL.
        CONTINUE.
      ENDIF.
      lv_pos += 1.
      APPEND VALUE #( vhname    = lv_name
                      srcpos    = lv_pos
                      srcrole   = '연관'
                      srckind   = source_kind( lv_target )
                      srcname   = lv_target
                      assocname = lo_assoc->name ) TO rt_source.
    ENDLOOP.

  ENDMETHOD.


  METHOD main_source_name.

    ASSIGN COMPONENT 'DATA_SOURCE' OF STRUCTURE is_content TO FIELD-SYMBOL(<la_ds>).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " DATA_SOURCE 자체가 이름이면 그대로
    rv_name = char_value( <la_ds> ).
    IF rv_name IS NOT INITIAL.
      RETURN.
    ENDIF.

    " 구조면 이름이 들어 있을 만한 항목을 차례로 본다
    DATA(lt_candidate) = VALUE string_table( ( `ENTITY` ) ( `NAME` ) ( `VIEW_ENTITY` ) ( `VIEW` )
                                             ( `DATABASE_TABLE` ) ( `TABLE_FUNCTION` ) ).
    LOOP AT lt_candidate INTO DATA(lv_component).
      ASSIGN COMPONENT lv_component OF STRUCTURE <la_ds> TO FIELD-SYMBOL(<la_value>).
      IF sy-subrc = 0.
        rv_name = char_value( <la_value> ).
        IF rv_name IS NOT INITIAL.
          RETURN.
        ENDIF.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD source_kind.

    DATA(lv_name) = to_upper( condense( iv_name ) ).

    IF lv_name CP 'DDCDS_CUSTOMER_DOMAIN_VALUE*'.
      rv_kind = `도메인 고정값`.
    ELSEIF strlen( lv_name ) <= 30
       AND xco_cp_abap_repository=>object->ddls->for( CONV #( lv_name ) )->exists( ) = abap_true.
      rv_kind = `CDS`.
    ELSEIF strlen( lv_name ) <= 16
       AND xco_cp_abap_dictionary=>database_table( CONV #( lv_name ) )->exists( ) = abap_true.
      rv_kind = `테이블`.
    ELSE.
      rv_kind = `확인 불가`.
    ENDIF.

  ENDMETHOD.


  METHOD char_value.

    DATA(lv_kind) = cl_abap_typedescr=>describe_by_data( ia_data )->type_kind.

    IF lv_kind = cl_abap_typedescr=>typekind_char OR lv_kind = cl_abap_typedescr=>typekind_string.
      rv_value = condense( CONV string( ia_data ) ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
