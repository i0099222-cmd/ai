"! To-Be 데이터 소스 (최하위까지) — custom entity ZCE_CMSM_TobeSource 의 쿼리 클래스
"!
"! To-Be CDS 정의를 XCO 로 읽어 메인 데이터 소스(select from …)를 찾고, 그게 CDS 면 또 그 CDS 의 메인 소스를…
"!   테이블(최하위)이 나오거나 더 못 읽을 때까지 따라 내려간다 (최대 10단계, 같은 이름이 다시 나오면 멈춤).
"! 못 읽는 것: join 대상, 연관, view entity 가 아닌 CDS(DDIC 기반 define view 등)에서 멈춤,
"!   ABAP Cloud 에서 안 보이는 SAP 오브젝트(릴리즈 안 된 표준 뷰·테이블)는 이름까지만 나오거나 거기서 멈춤
"! To-Be 가 CDS 가 아니면(클래스·FM 등) 빈 목록. As-Is 는 다른 시스템(ECC) 오브젝트라 못 읽는다
CLASS zcl_cmsm_tobesrc_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

ENDCLASS.


CLASS zcl_cmsm_tobesrc_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

    DATA lt_result TYPE STANDARD TABLE OF zce_cmsm_tobesource WITH EMPTY KEY.
    DATA lt_page   LIKE lt_result.
    DATA lv_src    TYPE string.

    " DATA_SOURCE 안에서 이름을 찾아볼 항목 (VH 데이터 소스 조회와 같음. 빈 값 = DATA_SOURCE 자체가 이름)
    DATA(lt_component) = VALUE string_table( ( `` ) ( `ENTITY` ) ( `NAME` ) ( `VIEW_ENTITY` ) ( `VIEW` )
                                             ( `DATABASE_TABLE` ) ( `TABLE_FUNCTION` ) ).

    " 1) 필터에서 To-Be 이름 (매핑 상세에서 열면 연관 조건 TobeName = 그 To-Be 이름이 들어온다)
    TRY.
        DATA(lt_filter) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR lt_filter.
    ENDTRY.

    LOOP AT lt_filter INTO DATA(ls_filter) WHERE name = 'TOBENAME'.
      LOOP AT ls_filter-range INTO DATA(ls_range) WHERE sign = 'I' AND option = 'EQ'.

        DATA(lv_tobe) = to_upper( condense( CONV string( ls_range-low ) ) ).
        IF lv_tobe IS INITIAL OR strlen( lv_tobe ) > 30 OR line_exists( lt_result[ tobename = lv_tobe ] ).
          CONTINUE.
        ENDIF.

        " 2) To-Be 부터 메인 데이터 소스를 따라 내려간다
        DATA(lv_cur)   = lv_tobe.
        DATA(lv_pos)   = 0.
        DATA(lv_level) = 0.

        DO 10 TIMES.

          CLEAR lv_src.
          TRY.
              DATA(lo_view) = xco_cp_cds=>view_entity( CONV #( lv_cur ) ).
              IF lo_view->exists( ) = abap_false.
                EXIT.                                   " view entity 가 아니면(테이블·DDIC 뷰 등) 더 못 내려감
              ENDIF.

              " 메인 데이터 소스: content( )->get( ) 결과의 DATA_SOURCE 항목을 동적으로 찾는다
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
                  DATA(lv_type_kind) = cl_abap_typedescr=>describe_by_data( <la_value> )->type_kind.
                  IF lv_type_kind = cl_abap_typedescr=>typekind_char OR lv_type_kind = cl_abap_typedescr=>typekind_string.
                    lv_src = to_upper( condense( CONV string( <la_value> ) ) ).
                    IF lv_src IS NOT INITIAL.
                      EXIT.
                    ENDIF.
                  ENDIF.
                ENDLOOP.
              ENDIF.
            CATCH cx_root.
              EXIT.
          ENDTRY.

          " 소스를 못 찾았거나, 같은 이름이 다시 나오면(순환) 멈춤
          IF lv_src IS INITIAL OR lv_src = lv_cur OR line_exists( lt_result[ tobename = lv_tobe srcname = lv_src ] ).
            EXIT.
          ENDIF.

          " 3) 유형: CDS 면 계속 내려가고, 테이블이면 최하위
          DATA(lv_is_cds) = xsdbool( strlen( lv_src ) <= 30
                                     AND xco_cp_abap_repository=>object->ddls->for( CONV #( lv_src ) )->exists( ) = abap_true ).
          DATA(lv_kind) = COND string(
            WHEN lv_src CP 'DDCDS_CUSTOMER_DOMAIN_VALUE*'
              THEN `도메인 고정값`
            WHEN lv_is_cds = abap_true
              THEN `CDS`
            WHEN strlen( lv_src ) <= 16
             AND xco_cp_abap_dictionary=>database_table( CONV #( lv_src ) )->exists( ) = abap_true
              THEN `테이블`
            ELSE `테이블·기타` ).                       " ABAP Cloud 에서 안 보이는 표준 테이블(MARA 등)도 여기

          lv_pos   += 1.
          lv_level += 1.
          APPEND VALUE #( tobename = lv_tobe
                          srcpos   = lv_pos
                          srclevel = lv_level
                          srckind  = lv_kind
                          srcname  = lv_src
                          usedby   = lv_cur ) TO lt_result.

          IF lv_is_cds = abap_false OR lv_kind = `도메인 고정값`.
            EXIT.                                       " 최하위
          ENDIF.
          lv_cur = lv_src.

        ENDDO.

      ENDLOOP.
    ENDLOOP.

    " 4) 건수·페이징 (순서는 단계 순, 요청 정렬 정보는 읽기만)
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
