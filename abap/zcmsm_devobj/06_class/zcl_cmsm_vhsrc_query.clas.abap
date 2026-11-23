"! Value Help 데이터 소스 조회 — custom entity ZCE_CMSM_VhSource 의 쿼리 클래스
"!
"! VH 이름(CDS view entity)의 정의를 XCO 로 읽어서 데이터 소스의 유형·이름을 돌려준다.
"!   메인 데이터 소스(select from …) 먼저, 그다음 연관(association) 대상. 같은 이름은 한 번만.
"! 저장하지 않으니 CDS 를 고치면 다음에 열 때 바로 반영된다.
"! 도메인 고정값 VH(DDCDS_CUSTOMER_DOMAIN_VALUE)는 파라미터 p_domain_name 값, 즉 도메인 이름을 보여 준다
"! 읽지 못하는 것: join 대상, Search Help 로 만든 VH, DDIC 기반 CDS 뷰(define view) → 빈 목록
CLASS zcl_cmsm_vhsrc_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

ENDCLASS.


CLASS zcl_cmsm_vhsrc_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

    DATA lt_result TYPE STANDARD TABLE OF zce_cmsm_vhsource WITH EMPTY KEY.
    DATA lt_page   LIKE lt_result.
    DATA lt_names  TYPE string_table.
    DATA lv_pos    TYPE i.
    DATA lv_main   TYPE string.
    DATA lv_domain TYPE string.
    DATA lo_pvalue TYPE REF TO object.
    FIELD-SYMBOLS <lt_param> TYPE ANY TABLE.

    " DATA_SOURCE 안에서 이름을 찾아볼 항목 (빈 값 = DATA_SOURCE 자체가 이름인 경우)
    DATA(lt_component) = VALUE string_table( ( `` ) ( `ENTITY` ) ( `NAME` ) ( `VIEW_ENTITY` ) ( `VIEW` )
                                             ( `DATABASE_TABLE` ) ( `TABLE_FUNCTION` ) ).

    " 1) 필터에서 VH 이름 (VH 상세에서 열면 연관 조건 VhName = 그 VH 이름이 들어온다)
    TRY.
        DATA(lt_filter) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR lt_filter.
    ENDTRY.

    LOOP AT lt_filter INTO DATA(ls_filter) WHERE name = 'VHNAME'.
      LOOP AT ls_filter-range INTO DATA(ls_range) WHERE sign = 'I' AND option = 'EQ'.

        DATA(lv_vh) = to_upper( condense( CONV string( ls_range-low ) ) ).
        IF lv_vh IS INITIAL OR strlen( lv_vh ) > 30.
          CONTINUE.
        ENDIF.

        " 2) VH 의 CDS view entity 정의 (아니면 Search Help·define view 등 → 건너뜀)
        DATA(lo_view) = xco_cp_cds=>view_entity( CONV #( lv_vh ) ).
        IF lo_view->exists( ) = abap_false.
          CONTINUE.
        ENDIF.

        CLEAR: lt_names, lv_pos, lv_main, lv_domain.

        " 2-1) 메인 데이터 소스: content( )->get( ) 결과의 DATA_SOURCE 항목.
        "      XCO 버전마다 구조가 조금씩 달라서 동적으로 찾는다 (이름이 다르면 컴파일 에러 대신 빈 값)
        DATA(ls_content) = lo_view->content( )->get( ).
        ASSIGN COMPONENT 'DATA_SOURCE' OF STRUCTURE ls_content TO FIELD-SYMBOL(<la_ds>).
        IF sy-subrc = 0.
          LOOP AT lt_component INTO DATA(lv_component).
            IF lv_component IS INITIAL.
              ASSIGN <la_ds> TO FIELD-SYMBOL(<la_value>).
            ELSE.
              ASSIGN COMPONENT lv_component OF STRUCTURE <la_ds> TO <la_value>.
              IF sy-subrc <> 0.
                CONTINUE.
              ENDIF.
            ENDIF.
            " 문자형일 때만 이름으로 본다
            DATA(lv_type_kind) = cl_abap_typedescr=>describe_by_data( <la_value> )->type_kind.
            IF lv_type_kind = cl_abap_typedescr=>typekind_char OR lv_type_kind = cl_abap_typedescr=>typekind_string.
              lv_main = condense( CONV string( <la_value> ) ).
              IF lv_main IS NOT INITIAL.
                APPEND lv_main TO lt_names.
                EXIT.
              ENDIF.
            ENDIF.
          ENDLOOP.

          " 2-1-1) 도메인 고정값 VH: 엔터티 이름(DDCDS_CUSTOMER_DOMAIN_VALUE) 대신 파라미터 p_domain_name 값 = 도메인 이름
          "        XCO: DATA_SOURCE-PARAMETERS[]-VALUE(오브젝트) 의 MV_VALUE. 공개 속성이 아니면 GET_VALUE( ) 로.
          "        못 읽으면 엔터티 이름 그대로 둔다
          IF lv_main CP 'DDCDS_CUSTOMER_DOMAIN_VALUE*'.
            TRY.
                ASSIGN COMPONENT 'PARAMETERS' OF STRUCTURE <la_ds> TO <lt_param>.
                IF sy-subrc = 0.
                  LOOP AT <lt_param> ASSIGNING FIELD-SYMBOL(<ls_param>).
                    ASSIGN COMPONENT 'VALUE' OF STRUCTURE <ls_param> TO FIELD-SYMBOL(<la_pvalue>).
                    IF sy-subrc <> 0.
                      CONTINUE.
                    ENDIF.
                    lo_pvalue ?= <la_pvalue>.
                    ASSIGN lo_pvalue->('MV_VALUE') TO FIELD-SYMBOL(<la_domain>).
                    IF sy-subrc = 0.
                      lv_domain = CONV string( <la_domain> ).
                    ELSE.
                      " 공개 GET_VALUE( ) 메서드 (반환 파라미터 이름은 RTTI 로)
                      DATA(lo_class) = CAST cl_abap_classdescr( cl_abap_typedescr=>describe_by_object_ref( lo_pvalue ) ).
                      LOOP AT lo_class->methods INTO DATA(ls_method)
                           WHERE name CP '*GET_VALUE' AND visibility = cl_abap_objectdescr=>public.
                        LOOP AT ls_method-parameters INTO DATA(ls_parm) WHERE parm_kind = cl_abap_objectdescr=>returning.
                          DATA(lt_ptab) = VALUE abap_parmbind_tab( ( name  = ls_parm-name
                                                                     kind  = cl_abap_objectdescr=>receiving
                                                                     value = REF #( lv_domain ) ) ).
                          CALL METHOD lo_pvalue->(ls_method-name) PARAMETER-TABLE lt_ptab.
                        ENDLOOP.
                        EXIT.
                      ENDLOOP.
                    ENDIF.
                    " 'ZDO_DM_MODULE' 처럼 따옴표가 붙어 있으면 뗀다
                    lv_domain = to_upper( replace( val = condense( lv_domain ) sub = `'` with = `` occ = 0 ) ).
                    IF lv_domain IS NOT INITIAL.
                      EXIT.
                    ENDIF.
                  ENDLOOP.
                ENDIF.
              CATCH cx_root.
                CLEAR lv_domain.
            ENDTRY.
            IF lv_domain IS NOT INITIAL.
              lt_names[ 1 ] = lv_domain.      " 메인 소스는 맨 앞에 들어가 있다
            ENDIF.
          ENDIF.
        ENDIF.

        " 2-2) 연관 대상
        LOOP AT lo_view->associations->all->get( ) INTO DATA(lo_assoc).
          DATA(lv_target) = condense( CONV string( lo_assoc->content( )->get( )-target ) ).
          IF lv_target IS NOT INITIAL.
            APPEND lv_target TO lt_names.
          ENDIF.
        ENDLOOP.

        " 3) 유형 붙여서 결과에 추가. 같은 이름은 한 번만, 순서는 읽은 순서. 순번은 VH 안에서 1부터 (키)
        LOOP AT lt_names INTO DATA(lv_name).

          DATA(lv_src) = to_upper( lv_name ).
          IF line_exists( lt_result[ vhname = lv_vh srcname = lv_src ] ).
            CONTINUE.
          ENDIF.

          DATA(lv_kind) = COND string(
            WHEN lv_src CP 'DDCDS_CUSTOMER_DOMAIN_VALUE*' OR ( lv_domain IS NOT INITIAL AND lv_src = lv_domain )
              THEN `도메인 고정값`
            WHEN strlen( lv_src ) <= 30
             AND xco_cp_abap_repository=>object->ddls->for( CONV #( lv_src ) )->exists( ) = abap_true
              THEN `CDS`
            WHEN strlen( lv_src ) <= 16
             AND xco_cp_abap_dictionary=>database_table( CONV #( lv_src ) )->exists( ) = abap_true
              THEN `테이블`
            ELSE `확인 불가` ).

          lv_pos += 1.
          APPEND VALUE #( vhname  = lv_vh
                          srcpos  = lv_pos
                          srcname = lv_src
                          srckind = lv_kind ) TO lt_result.

        ENDLOOP.

      ENDLOOP.
    ENDLOOP.

    " 4) 건수·페이징 (순서는 읽은 순서 그대로, 요청 정렬 정보는 읽기만)
    DATA(lt_sort) = io_request->get_sort_elements( ).

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

ENDCLASS.
