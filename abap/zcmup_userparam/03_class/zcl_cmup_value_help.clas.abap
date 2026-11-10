"! Value Help 출처 · 항목 ID 별로 고를 수 있는 값 (코드 + 텍스트)
"!
"! ② Value Help 조회, ① 현재 설정의 값 텍스트, ③ 수정 값 검증이 모두 이 클래스를 쓴다.
"!
"! 출처
"!   날짜·소수점·시간 형식 : 고정값 (도메인 XUDATFM / XUDCPFM / XUTIMEFM 기준)
"!   로그온 언어·타임존     : Tier 2 래퍼 (T002 / TTZZ 는 미공개 테이블)
"!   파라미터               : 릴리스된 CDS (I_CompanyCode 등) → 그 CDS 의 DCL 권한이 적용된다
"!
"! 건수가 많은 마스터(자재, 거래처 등)를 넣을 때는 전체를 읽지 말고 검색어를 SQL 조건으로 내린다.
CLASS zcl_cmup_value_help DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    "! 검색어가 있으면 코드·텍스트에 포함된 것만 (대소문자 무시)
    CLASS-METHODS get_values
      IMPORTING iv_item_id      TYPE zif_cmup_user_api=>ty_item
                iv_search       TYPE string OPTIONAL
      RETURNING VALUE(rt_value) TYPE zif_cmup_user_api=>tt_code_text.

    "! 값의 텍스트 (1000 → 서울 본사). 없으면 빈 값
    CLASS-METHODS get_text
      IMPORTING iv_item_id     TYPE zif_cmup_user_api=>ty_item
                iv_value       TYPE zif_cmup_user_api=>ty_value
      RETURNING VALUE(rv_text) TYPE zif_cmup_user_api=>ty_text.

    "! 고를 수 있는 값인지
    CLASS-METHODS exists
      IMPORTING iv_item_id       TYPE zif_cmup_user_api=>ty_item
                iv_value         TYPE zif_cmup_user_api=>ty_value
      RETURNING VALUE(rv_exists) TYPE abap_boolean.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_cache,
        item_id TYPE zif_cmup_user_api=>ty_item,
        values  TYPE zif_cmup_user_api=>tt_code_text,
      END OF ty_cache.

    "! 한 요청 안에서 같은 항목을 여러 번 읽지 않게
    CLASS-DATA gt_cache TYPE HASHED TABLE OF ty_cache WITH UNIQUE KEY item_id.

    CLASS-METHODS get_all
      IMPORTING iv_item_id      TYPE zif_cmup_user_api=>ty_item
      RETURNING VALUE(rt_value) TYPE zif_cmup_user_api=>tt_code_text.

    CLASS-METHODS read_source
      IMPORTING iv_item_id      TYPE zif_cmup_user_api=>ty_item
      RETURNING VALUE(rt_value) TYPE zif_cmup_user_api=>tt_code_text.
ENDCLASS.


CLASS zcl_cmup_value_help IMPLEMENTATION.

  METHOD get_values.
    rt_value = get_all( iv_item_id ).
    IF iv_search IS NOT INITIAL.
      " CS = 대소문자 구분 없는 '포함' 비교
      DELETE rt_value WHERE NOT ( code CS iv_search OR text CS iv_search ).
    ENDIF.
  ENDMETHOD.


  METHOD get_text.
    DATA(lt_value) = get_all( iv_item_id ).
    rv_text = VALUE #( lt_value[ code = iv_value ]-text OPTIONAL ).
  ENDMETHOD.


  METHOD exists.
    DATA(lt_value) = get_all( iv_item_id ).
    rv_exists = xsdbool( line_exists( lt_value[ code = iv_value ] ) ).
  ENDMETHOD.


  METHOD get_all.
    READ TABLE gt_cache INTO DATA(ls_cache) WITH TABLE KEY item_id = iv_item_id.
    IF sy-subrc <> 0.
      ls_cache = VALUE #( item_id = iv_item_id
                          values  = read_source( iv_item_id ) ).
      INSERT ls_cache INTO TABLE gt_cache.
    ENDIF.
    rt_value = ls_cache-values.
  ENDMETHOD.


  METHOD read_source.
    DATA(lv_langu) = cl_abap_context_info=>get_user_language_abap_format( ).

    CASE iv_item_id.

      " ── 사용자정보: 고정값
      WHEN zif_cmup_user_api=>c_default-datfm.
        rt_value = VALUE #( ( code = '1' text = 'DD.MM.YYYY' )
                            ( code = '2' text = 'MM/DD/YYYY' )
                            ( code = '3' text = 'MM-DD-YYYY' )
                            ( code = '4' text = 'YYYY.MM.DD' )
                            ( code = '5' text = 'YYYY/MM/DD' )
                            ( code = '6' text = 'YYYY-MM-DD' ) ).

      WHEN zif_cmup_user_api=>c_default-dcpfm.
        rt_value = VALUE #( ( code = ''  text = '1.234.567,89' )
                            ( code = 'X' text = '1,234,567.89' )
                            ( code = 'Y' text = '1 234 567,89' ) ).

      WHEN zif_cmup_user_api=>c_default-timefm.
        rt_value = VALUE #( ( code = '0' text = '24시간 (12:05:10)' )
                            ( code = '1' text = '12시간 (12:05:10 PM)' )
                            ( code = '2' text = '12시간 (12:05:10 pm)' )
                            ( code = '3' text = '12시간, 0~11시 (00:05:10 PM)' )
                            ( code = '4' text = '12시간, 0~11시 (00:05:10 pm)' ) ).

      " ── 사용자정보: Tier 2 래퍼
      WHEN zif_cmup_user_api=>c_default-langu.
        rt_value = zcl_cmup_user_api=>create( )->get_languages( ).

      WHEN zif_cmup_user_api=>c_default-tzone.
        rt_value = zcl_cmup_user_api=>create( )->get_time_zones( ).

      " ── 파라미터: 릴리스된 CDS
      WHEN zcl_cmup_config=>c_param-company_code.
        SELECT CompanyCode AS code, CompanyCodeName AS text
          FROM I_CompanyCode
          ORDER BY CompanyCode
          INTO CORRESPONDING FIELDS OF TABLE @rt_value.

      WHEN zcl_cmup_config=>c_param-controlling_area.
        SELECT ControllingArea AS code, ControllingAreaName AS text
          FROM I_ControllingArea
          ORDER BY ControllingArea
          INTO CORRESPONDING FIELDS OF TABLE @rt_value.

      WHEN zcl_cmup_config=>c_param-purchasing_org.
        SELECT PurchasingOrganization AS code, PurchasingOrganizationName AS text
          FROM I_PurchasingOrganization
          ORDER BY PurchasingOrganization
          INTO CORRESPONDING FIELDS OF TABLE @rt_value.

      WHEN zcl_cmup_config=>c_param-sales_org.
        SELECT o~SalesOrganization AS code, t~SalesOrganizationName AS text
          FROM I_SalesOrganization AS o
            LEFT OUTER JOIN I_SalesOrganizationText AS t
              ON  t~SalesOrganization = o~SalesOrganization
              AND t~Language          = @lv_langu
          ORDER BY o~SalesOrganization
          INTO CORRESPONDING FIELDS OF TABLE @rt_value.

      WHEN zcl_cmup_config=>c_param-plant.
        SELECT Plant AS code, PlantName AS text
          FROM I_Plant
          ORDER BY Plant
          INTO CORRESPONDING FIELDS OF TABLE @rt_value.

    ENDCASE.
  ENDMETHOD.

ENDCLASS.
