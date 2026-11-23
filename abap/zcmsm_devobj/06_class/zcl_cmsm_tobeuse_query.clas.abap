"! To-Be 오브젝트 사용처 — custom entity ZCE_CMSM_TobeUsage 의 쿼리 클래스
"!
"! 래퍼 ZCL_CMSM_DDL_WHERE_USED(12_wrapper, Standard ABAP)가 표준 테이블 DDLS_RIS_INDEX(CDS 사용처 인덱스)에서
"!   To-Be 를 쓰는 Z CDS 를 돌려준다 (Z CDS 전부, join·연관 포함, 패키지 제한 없음). 여기선 패키지만 붙인다.
"! 예전 방식(CDS 마다 XCO 로 정의 파싱)은 CDS 가 많으면 1분 넘게 걸려서 바꿨다.
"! 못 찾는 것: ABAP 코드(클래스·프로그램)에서 쓰는 곳, 표준(SAP) CDS 에서 쓰는 곳
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
    DATA lr_names  TYPE RANGE OF i_custabapobjdirectoryentry-abapobject.

    " 1) 필터에서 To-Be 이름 (매핑 상세에서 열면 연관 조건 TobeName = 그 To-Be 이름이 들어온다)
    TRY.
        DATA(lt_filter) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR lt_filter.
    ENDTRY.

    LOOP AT lt_filter INTO DATA(ls_filter) WHERE name = 'TOBENAME'.
      LOOP AT ls_filter-range INTO DATA(ls_range) WHERE sign = 'I' AND option = 'EQ'.

        DATA(lv_tobe) = to_upper( condense( CONV string( ls_range-low ) ) ).
        IF lv_tobe IS INITIAL OR strlen( lv_tobe ) > 40 OR line_exists( lt_result[ tobename = lv_tobe ] ).
          CONTINUE.
        ENDIF.

        " 2) 래퍼: CDS 소스에서 To-Be 이름을 쓰는 Z CDS 와 쓰는 방식
        DATA(lt_usage) = zcl_cmsm_ddl_where_used=>find( lv_tobe ).
        IF lt_usage IS INITIAL.
          CONTINUE.
        ENDIF.

        " 3) 패키지 (고객 오브젝트 목록에서 한 번에)
        lr_names = VALUE #( FOR ls_u IN lt_usage ( sign = 'I' option = 'EQ' low = ls_u-ddlname ) ).
        SELECT ABAPObject, ABAPPackage
          FROM I_CustABAPObjDirectoryEntry
          WHERE ABAPObjectType = 'DDLS'
            AND ABAPObject     IN @lr_names
          INTO TABLE @DATA(lt_package).

        LOOP AT lt_usage INTO DATA(ls_usage).
          READ TABLE lt_package INTO DATA(ls_package) WITH KEY ABAPObject = ls_usage-ddlname.
          APPEND VALUE #( tobename = lv_tobe
                          usedby   = ls_usage-ddlname
                          usekind  = ls_usage-kind
                          package  = COND #( WHEN sy-subrc = 0 THEN ls_package-ABAPPackage ) ) TO lt_result.
        ENDLOOP.

      ENDLOOP.
    ENDLOOP.

    " 4) 건수·페이징 (순서는 CDS 이름순, 요청 정렬 정보는 읽기만)
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
