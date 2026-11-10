"! Value Help 출처 · 파라미터 ID 별로 고를 수 있는 값 (코드 + 텍스트)
"!
"! ② Value Help 목록, ① 현재값 텍스트(ValueText), ③ 수정 값 검증이 이 목록을 같이 쓴다.
"! 출처는 릴리스된 CDS → 그 CDS 의 DCL 권한이 적용된다.
"! 사용자정보(언어·타임존 등)는 팝업 대상이 아니라 빈 목록.
"!
"! 건수가 많은 마스터(자재, 거래처 등)를 넣을 때는 전체를 읽지 말고 검색어를 SQL 조건으로 내린다.
CLASS zcl_cmup_value_help DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    CLASS-METHODS read_source
      IMPORTING iv_item_id      TYPE zif_cmup_user_api=>ty_item
      RETURNING VALUE(rt_value) TYPE zif_cmup_user_api=>tt_code_text.
ENDCLASS.


CLASS zcl_cmup_value_help IMPLEMENTATION.

  METHOD read_source.
    DATA(lv_langu) = cl_abap_context_info=>get_user_language_abap_format( ).

    CASE iv_item_id.
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
