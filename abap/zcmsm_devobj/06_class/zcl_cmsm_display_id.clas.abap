"! 화면 표시 번호 채번 (RQ-0001, MP-0001, VH-0001, SB-0001, TD-001)
"!
"! 번호 범위 오브젝트 ZCMSM_DOID 하나에 탭별 구간을 둔다.
"!   01 요청 / 02 매핑 / 03 Value Help / 04 OData 서비스 / 05 기술부채
"! 채번 실패(오브젝트·구간 없음, 구간 소진 등)는 빈 값을 돌려준다.
CLASS zcl_cmsm_display_id DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    TYPES ty_range TYPE c LENGTH 2.

    CONSTANTS gc_object TYPE c LENGTH 10 VALUE 'ZCMSM_DOID'.

    CONSTANTS:
      BEGIN OF gc_range,
        request       TYPE ty_range VALUE '01',
        mapping       TYPE ty_range VALUE '02',
        value_help    TYPE ty_range VALUE '03',
        odata_service TYPE ty_range VALUE '04',
        tech_debt     TYPE ty_range VALUE '05',
      END OF gc_range.

    "! 다음 표시 번호. 채번 실패 시 빈 값
    CLASS-METHODS next
      IMPORTING iv_range     TYPE ty_range
      RETURNING VALUE(rv_id) TYPE string.

  PRIVATE SECTION.

    CLASS-METHODS prefix
      IMPORTING iv_range         TYPE ty_range
      RETURNING VALUE(rv_prefix) TYPE string.

ENDCLASS.


CLASS zcl_cmsm_display_id IMPLEMENTATION.

  METHOD next.

    TRY.
        cl_numberrange_runtime=>number_get(
          EXPORTING
            nr_range_nr = iv_range
            object      = gc_object
          IMPORTING
            number      = DATA(lv_number) ).
      CATCH cx_nr_object_not_found.
        RETURN.
      CATCH cx_number_ranges.
        RETURN.
    ENDTRY.

    DATA(lv_seq)   = CONV i( lv_number ).
    " 딕셔너리 기준: 기술부채만 TD-nnn (3자리), 나머지는 4자리
    DATA(lv_width) = COND i( WHEN iv_range = gc_range-tech_debt THEN 3 ELSE 4 ).

    rv_id = |{ prefix( iv_range ) }-{ lv_seq WIDTH = lv_width ALIGN = RIGHT PAD = '0' }|.

  ENDMETHOD.


  METHOD prefix.

    rv_prefix = SWITCH #( iv_range
                          WHEN gc_range-request       THEN `RQ`
                          WHEN gc_range-mapping       THEN `MP`
                          WHEN gc_range-value_help    THEN `VH`
                          WHEN gc_range-odata_service THEN `SB`
                          WHEN gc_range-tech_debt     THEN `TD` ).

  ENDMETHOD.

ENDCLASS.
