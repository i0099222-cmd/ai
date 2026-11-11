"! 포털에 노출할 항목 목록 + 사용자 범위 설정
"!
"! 항목 추가/삭제/이름 변경은 get_items 한 곳만 고친다. (항목명 + 순서)
"! 파라미터 ID 는 zcl_cmup_value_help=>c_param 에 있는 것 (VH 출처와 같이 관리).
CLASS zcl_cmup_config DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES:
      ty_category TYPE c LENGTH 10,

      BEGIN OF ty_item,
        item_id   TYPE zif_cmup_user_api=>ty_item,
        category  TYPE ty_category,
        item_name TYPE c LENGTH 60,    " 웹 화면에 보일 항목 이름
        sort_no   TYPE i,              " 웹 화면 배치 순서
      END OF ty_item,
      tt_item TYPE SORTED TABLE OF ty_item WITH UNIQUE KEY item_id.

    CONSTANTS:
      BEGIN OF c_category,
        user_info TYPE ty_category VALUE 'USERINFO',   " SU3 기본값 탭
        parameter TYPE ty_category VALUE 'PARAM',      " SU3 파라미터 탭
      END OF c_category,

      "! abap_true  = 로그온 사용자 본인 것만 조회/변경
      "!              (포털 사용자 그대로 SAP 에 로그온 = Principal Propagation)
      "! abap_false = UserId 로 다른 사용자도 조회/변경 (기술 사용자 하나로 호출)
      "!              → 기술 사용자에 S_USER_GRP 03(조회)/02(변경) 필요, 보안 검토
      c_self_only TYPE abap_boolean VALUE abap_true.

    CLASS-METHODS get_items
      RETURNING VALUE(rt_item) TYPE tt_item.

    "! 목록에 없는 항목이면 빈 값
    CLASS-METHODS get_item
      IMPORTING iv_item_id     TYPE zif_cmup_user_api=>ty_item
      RETURNING VALUE(rs_item) TYPE ty_item.

    "! 빈 값이면 로그온 사용자, 아니면 대문자로
    CLASS-METHODS resolve_user
      IMPORTING iv_user        TYPE zif_cmup_user_api=>ty_user OPTIONAL
      RETURNING VALUE(rv_user) TYPE zif_cmup_user_api=>ty_user.

    "! c_self_only 기준으로 이 사용자를 다뤄도 되는지
    CLASS-METHODS is_user_allowed
      IMPORTING iv_user           TYPE zif_cmup_user_api=>ty_user
      RETURNING VALUE(rv_allowed) TYPE abap_boolean.
ENDCLASS.


CLASS zcl_cmup_config IMPLEMENTATION.

  METHOD get_items.
    " 초안: 사용자정보 5 + 파라미터 5. 확정 목록(사용자정보 7 + 파라미터 16)이 오면 여기만 채운다.
    rt_item = VALUE #(
      " ── 사용자정보 (SU3 기본값 탭)
      ( item_id = zif_cmup_user_api=>c_default-langu  category = c_category-user_info item_name = '로그온 언어' sort_no = 10 )
      ( item_id = zif_cmup_user_api=>c_default-datfm  category = c_category-user_info item_name = '날짜 형식'   sort_no = 20 )
      ( item_id = zif_cmup_user_api=>c_default-dcpfm  category = c_category-user_info item_name = '소수점 표기' sort_no = 30 )
      ( item_id = zif_cmup_user_api=>c_default-timefm category = c_category-user_info item_name = '시간 형식'   sort_no = 40 )
      ( item_id = zif_cmup_user_api=>c_default-tzone  category = c_category-user_info item_name = '타임존'      sort_no = 50 )
      " ── 자주 쓰는 파라미터 (SU3 파라미터 탭)
      ( item_id = zcl_cmup_value_help=>c_param-company_code     category = c_category-parameter item_name = '회사코드'     sort_no = 110 )
      ( item_id = zcl_cmup_value_help=>c_param-controlling_area category = c_category-parameter item_name = '관리회계영역' sort_no = 120 )
      ( item_id = zcl_cmup_value_help=>c_param-purchasing_org   category = c_category-parameter item_name = '구매조직'     sort_no = 130 )
      ( item_id = zcl_cmup_value_help=>c_param-sales_org        category = c_category-parameter item_name = '판매조직'     sort_no = 140 )
      ( item_id = zcl_cmup_value_help=>c_param-plant            category = c_category-parameter item_name = '플랜트'       sort_no = 150 ) ).
  ENDMETHOD.


  METHOD get_item.
    DATA(lt_item) = get_items( ).
    rs_item = VALUE #( lt_item[ item_id = iv_item_id ] OPTIONAL ).
  ENDMETHOD.


  METHOD resolve_user.
    rv_user = COND #( WHEN iv_user IS INITIAL THEN cl_abap_context_info=>get_user_technical_name( )
                      ELSE to_upper( iv_user ) ).
  ENDMETHOD.


  METHOD is_user_allowed.
    rv_allowed = xsdbool( c_self_only = abap_false
                       OR iv_user = cl_abap_context_info=>get_user_technical_name( ) ).
  ENDMETHOD.

ENDCLASS.
