"! To-Be 오브젝트 사용처 — custom entity ZCE_CMSM_TobeUsage 의 쿼리 클래스
"!
"! To-Be 오브젝트(Z CDS·Z 테이블)와 같은 모듈 패키지(패키지 앞 3자리, 예: ZCM → ZCM*)의 CDS 만 XCO 로 읽어서,
"!   To-Be 를 데이터 소스(select from …)나 연관(association) 대상으로 쓰는 CDS 를 돌려준다.
"! 시스템 Z CDS 전부(1만 개 이상)를 읽으면 너무 느려서 범위를 같은 모듈 패키지로 좁혔다.
"!   ZCM 의 테이블을 ZCM01 패키지 CDS 가 써도 찾는다. 범위는 lc_prefix_len 으로 (3 = Z + 모듈 2자리)
"! 못 찾는 것: 다른 패키지에서 쓰는 곳, join 대상, view entity 가 아닌 CDS(DDIC 기반 define view, custom entity 등)
"! To-Be 가 클래스·FM·T-code 이거나 표준 오브젝트면 빈 목록 (ABAP Cloud 에 where-used API 가 없음)
CLASS zcl_cmsm_tobeuse_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.

ENDCLASS.


CLASS zcl_cmsm_tobeuse_query IMPLEMENTATION.

  METHOD if_rap_query_provider~select.

    DATA lt_result TYPE STANDARD TABLE OF zce_cmsm_tobeusage WITH EMPTY KEY.
    DATA lt_page   LIKE lt_result.
    DATA lt_target TYPE string_table.
    DATA lv_main   TYPE string.
    DATA lv_package TYPE c LENGTH 30.
    DATA lv_like    TYPE c LENGTH 31.
    " 패키지 앞 몇 자리가 같으면 같은 모듈로 본다 (ZCM·ZCM01·ZCM_FI → ZCM*). 범위를 바꾸려면 이 값만
    CONSTANTS lc_prefix_len TYPE i VALUE 3.

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

        " 2) To-Be 의 패키지 (Z CDS 나 Z 테이블일 때만. 아니면 CDS 가 쓰는 오브젝트가 아니거나 표준이라 건너뜀)
        SELECT SINGLE ABAPPackage
          FROM I_CustABAPObjDirectoryEntry
          WHERE ABAPObject = @lv_tobe
            AND ( ABAPObjectType = 'DDLS' OR ABAPObjectType = 'TABL' )
          INTO @lv_package.
        IF sy-subrc <> 0 OR lv_package IS INITIAL.
          CONTINUE.
        ENDIF.

        " 3) 같은 모듈 패키지(앞 lc_prefix_len 자리가 같은 패키지 전부)의 CDS
        lv_like = COND string( WHEN strlen( condense( lv_package ) ) > lc_prefix_len
                               THEN substring( val = condense( lv_package ) len = lc_prefix_len )
                               ELSE condense( lv_package ) ) && `%`.
        SELECT ABAPObject, ABAPPackage
          FROM I_CustABAPObjDirectoryEntry
          WHERE ABAPObjectType = 'DDLS'
            AND ABAPPackage    LIKE @lv_like
          ORDER BY ABAPObject
          INTO TABLE @DATA(lt_ddls).

        LOOP AT lt_ddls INTO DATA(ls_ddls).

          DATA(lv_cds) = to_upper( condense( CONV string( ls_ddls-ABAPObject ) ) ).
          IF lv_cds = lv_tobe OR strlen( lv_cds ) > 30.
            CONTINUE.
          ENDIF.

          CLEAR: lv_main, lt_target.

          " 4) XCO 로 메인 데이터 소스·연관 대상. CDS 하나를 못 읽어도(비활성·깨진 정의 등) 나머지는 계속
          TRY.
              DATA(lo_view) = xco_cp_cds=>view_entity( CONV #( lv_cds ) ).
              IF lo_view->exists( ) = abap_false.
                CONTINUE.
              ENDIF.

              " 4-1) 메인 데이터 소스: content( )->get( ) 결과의 DATA_SOURCE 항목을 동적으로 찾는다
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
                    lv_main = to_upper( condense( CONV string( <la_value> ) ) ).
                    IF lv_main IS NOT INITIAL.
                      EXIT.
                    ENDIF.
                  ENDIF.
                ENDLOOP.
              ENDIF.

              " 4-2) 연관 대상
              LOOP AT lo_view->associations->all->get( ) INTO DATA(lo_assoc).
                DATA(lv_target) = to_upper( condense( CONV string( lo_assoc->content( )->get( )-target ) ) ).
                APPEND lv_target TO lt_target.
              ENDLOOP.

            CATCH cx_root.
              CONTINUE.
          ENDTRY.

          " 5) To-Be 를 쓰고 있으면 결과에 추가 (CDS 하나에 한 줄, 둘 다면 '데이터 소스·연관')
          DATA(lv_in_main)  = xsdbool( lv_main = lv_tobe ).
          DATA(lv_in_assoc) = xsdbool( line_exists( lt_target[ table_line = lv_tobe ] ) ).
          IF lv_in_main = abap_false AND lv_in_assoc = abap_false.
            CONTINUE.
          ENDIF.

          APPEND VALUE #( tobename = lv_tobe
                          usedby   = lv_cds
                          package  = ls_ddls-ABAPPackage
                          usekind  = COND #( WHEN lv_in_main = abap_true AND lv_in_assoc = abap_true THEN `데이터 소스·연관`
                                             WHEN lv_in_main = abap_true                             THEN `데이터 소스`
                                             ELSE                                                         `연관` ) ) TO lt_result.

        ENDLOOP.

      ENDLOOP.
    ENDLOOP.

    " 6) 건수·페이징 (순서는 CDS 이름순, 요청 정렬 정보는 읽기만)
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
