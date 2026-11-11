"! Value Help 출처 · 항목 ID 별로 고를 수 있는 값 (코드 + 텍스트)
"!
"! ② Value Help 목록, ① 현재값 텍스트(ValueText), ③ 수정 값 검증이 이 목록을 같이 쓴다.
"!
"! 출처
"!   사용자정보 날짜·소수점·시간 형식 : 고정값 (도메인 XUDATFM / XUDCPFM / XUTIMEFM 기준)
"!   사용자정보 로그온 언어·타임존     : Tier 2 zcl_cmup_vh_tier2 (T002 / TTZZ 는 미공개 테이블)
"!   파라미터                         : 릴리스된 CDS → 그 CDS 의 DCL 권한이 적용된다
"!
"! 항목을 추가하면 상수(c_userinfo / c_param)와 read_source 의 WHEN 을 같이 넣는다.
"! 건수가 많은 마스터(자재, 거래처 등)를 넣을 때는 전체를 읽지 말고 검색어를 SQL 조건으로 내린다.
CLASS zcl_cmup_value_help DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES:
      "! 항목 ID = 파라미터 ID (TPARA-PARAMID) 또는 사용자정보 항목 ID (DATFM 등)
      ty_param_id TYPE c LENGTH 20,

      BEGIN OF ty_value,
        code TYPE c LENGTH 40,
        text TYPE c LENGTH 80,
      END OF ty_value,
      tt_value TYPE STANDARD TABLE OF ty_value WITH EMPTY KEY.

    CONSTANTS:
      "! 사용자정보 항목 (SU3 기본값 탭)
      BEGIN OF c_userinfo,
        langu  TYPE ty_param_id VALUE 'LANGU',    " 로그온 언어
        datfm  TYPE ty_param_id VALUE 'DATFM',    " 날짜 형식
        dcpfm  TYPE ty_param_id VALUE 'DCPFM',    " 소수점 표기
        timefm TYPE ty_param_id VALUE 'TIMEFM',   " 시간 형식
        tzone  TYPE ty_param_id VALUE 'TZONE',    " 타임존
      END OF c_userinfo,

      "! 파라미터 ID (SU3 파라미터 탭)
      BEGIN OF c_param,
        company_code     TYPE ty_param_id VALUE 'BUK',
        controlling_area TYPE ty_param_id VALUE 'CAC',
        purchasing_org   TYPE ty_param_id VALUE 'EKO',
        sales_org        TYPE ty_param_id VALUE 'VKO',
        plant            TYPE ty_param_id VALUE 'WRK',
      END OF c_param.

    "! 지원하지 않는 항목 ID 면 예외
    CLASS-METHODS read_source
      IMPORTING iv_param_id     TYPE ty_param_id
      RETURNING VALUE(rt_value) TYPE tt_value
      RAISING   zcx_cmup_query.
ENDCLASS.


CLASS zcl_cmup_value_help IMPLEMENTATION.

  METHOD read_source.
    DATA(lv_langu) = cl_abap_context_info=>get_user_language_abap_format( ).

    CASE iv_param_id.

      " ── 사용자정보: 고정값
      WHEN c_userinfo-datfm.
        rt_value = VALUE #( ( code = '1' text = 'DD.MM.YYYY' )
                            ( code = '2' text = 'MM/DD/YYYY' )
                            ( code = '3' text = 'MM-DD-YYYY' )
                            ( code = '4' text = 'YYYY.MM.DD' )
                            ( code = '5' text = 'YYYY/MM/DD' )
                            ( code = '6' text = 'YYYY-MM-DD' ) ).

      WHEN c_userinfo-dcpfm.
        rt_value = VALUE #( ( code = ''  text = '1.234.567,89' )
                            ( code = 'X' text = '1,234,567.89' )
                            ( code = 'Y' text = '1 234 567,89' ) ).

      WHEN c_userinfo-timefm.
        rt_value = VALUE #( ( code = '0' text = '24시간 (12:05:10)' )
                            ( code = '1' text = '12시간 (12:05:10 PM)' )
                            ( code = '2' text = '12시간 (12:05:10 pm)' )
                            ( code = '3' text = '12시간, 0~11시 (00:05:10 PM)' )
                            ( code = '4' text = '12시간, 0~11시 (00:05:10 pm)' ) ).

      " ── 사용자정보: Tier 2
      WHEN c_userinfo-langu.
        rt_value = CORRESPONDING #( zcl_cmup_vh_tier2=>get_languages( ) ).

      WHEN c_userinfo-tzone.
        rt_value = CORRESPONDING #( zcl_cmup_vh_tier2=>get_time_zones( ) ).

      " ── 파라미터: 릴리스된 CDS
      WHEN c_param-company_code.
        SELECT CompanyCode AS code, CompanyCodeName AS text
          FROM I_CompanyCode
          ORDER BY CompanyCode
          INTO CORRESPONDING FIELDS OF TABLE @rt_value.

      WHEN c_param-controlling_area.
        SELECT ControllingArea AS code, ControllingAreaName AS text
          FROM I_ControllingArea
          ORDER BY ControllingArea
          INTO CORRESPONDING FIELDS OF TABLE @rt_value.

      WHEN c_param-purchasing_org.
        SELECT PurchasingOrganization AS code, PurchasingOrganizationName AS text
          FROM I_PurchasingOrganization
          ORDER BY PurchasingOrganization
          INTO CORRESPONDING FIELDS OF TABLE @rt_value.

      WHEN c_param-sales_org.
        SELECT o~SalesOrganization AS code, t~SalesOrganizationName AS text
          FROM I_SalesOrganization AS o
            LEFT OUTER JOIN I_SalesOrganizationText AS t
              ON  t~SalesOrganization = o~SalesOrganization
              AND t~Language          = @lv_langu
          ORDER BY o~SalesOrganization
          INTO CORRESPONDING FIELDS OF TABLE @rt_value.

      WHEN c_param-plant.
        SELECT Plant AS code, PlantName AS text
          FROM I_Plant
          ORDER BY Plant
          INTO CORRESPONDING FIELDS OF TABLE @rt_value.

      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_cmup_query
          EXPORTING
            iv_text = |{ iv_param_id } 는 Value Help 를 지원하지 않는 항목입니다|.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
