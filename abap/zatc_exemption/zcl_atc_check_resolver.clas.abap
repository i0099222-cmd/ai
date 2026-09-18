"! finding 의 체크 식별자를 표준 예외 API 가 받는 값으로 옮기는 전담 클래스.
"!
"! 두 세계가 체크를 다르게 부른다.
"!
"!   SATC_API_FINDINGS      moduleid      RAW16   (체크 모듈 GUID)
"!                          module_msg_key CHAR25 (메시지 키)
"!
"!   create_exemption( )    i_check_class CSEQUENCE (예: CL_CI_TEST_DB)
"!                          i_check_code  CHAR10    (예: DBREAD, UPDATE_SUC)
"!
"! findings 뷰에는 체크 클래스명도 체크 코드도 없다(뷰의 필드 중 check 가 들어간
"! 것은 checkrunindex / checkvariant / checksumversion 뿐이다). 그래서 환산이
"! 필요하고, 그 환산을 앱 전체에서 이 클래스 한 곳에만 둔다.
"!
"! 아직 열려 있는 부분은 resolve_class( ) 하나다. 그 메서드만 채우면 앱 전체가
"! 동작한다. 그 전까지 resolve( ) 는 checkclass 를 비워 돌려주고, 호출자는
"! 사용자에게 직접 입력받는다.
CLASS zcl_atc_check_resolver DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    CLASS-METHODS get
      RETURNING VALUE(ro_resolver) TYPE REF TO zcl_atc_check_resolver.

    "! finding 의 모듈 식별자를 표준 API 가 받는 체크 클래스/코드로 옮긴다.
    "! 옮기지 못하면 해당 필드를 비워 돌려준다. 예외를 던지지 않는 이유는,
    "! 환산 실패가 오류가 아니라 "사용자가 직접 채워야 하는 상태" 이기 때문이다.
    METHODS resolve
      IMPORTING iv_moduleid     TYPE sysuuid_x16 OPTIONAL
                iv_modulemsgkey TYPE char25      OPTIONAL
      RETURNING VALUE(rs_check) TYPE zif_atc_exemption=>ty_check.

    "! 두 값이 모두 채워졌는가. 신청서 저장 가능 여부 판정에 쓴다.
    METHODS is_complete
      IMPORTING is_check           TYPE zif_atc_exemption=>ty_check
      RETURNING VALUE(rv_complete) TYPE abap_boolean.

  PRIVATE SECTION.

    CLASS-DATA go_instance TYPE REF TO zcl_atc_check_resolver.

    "! 모듈 GUID -> 체크 클래스명.
    METHODS resolve_class
      IMPORTING iv_moduleid           TYPE sysuuid_x16
      RETURNING VALUE(rv_checkclass)  TYPE char30.

    "! 메시지 키 -> 체크 코드.
    METHODS resolve_code
      IMPORTING iv_modulemsgkey      TYPE char25
      RETURNING VALUE(rv_checkcode)  TYPE char10.

    "! 같은 모듈이 화면 한 번에 수십 건 나오므로 세션 버퍼를 둔다.
    TYPES: BEGIN OF ty_buffer,
             moduleid   TYPE sysuuid_x16,
             checkclass TYPE char30,
           END OF ty_buffer.

    DATA mt_buffer TYPE HASHED TABLE OF ty_buffer WITH UNIQUE KEY moduleid.

ENDCLASS.


CLASS zcl_atc_check_resolver IMPLEMENTATION.

  METHOD get.
    IF go_instance IS NOT BOUND.
      go_instance = NEW #( ).
    ENDIF.
    ro_resolver = go_instance.
  ENDMETHOD.


  METHOD resolve.

    IF iv_moduleid IS NOT INITIAL.
      rs_check-checkclass = resolve_class( iv_moduleid ).
    ENDIF.

    IF iv_modulemsgkey IS NOT INITIAL.
      rs_check-checkcode = resolve_code( iv_modulemsgkey ).
    ENDIF.

  ENDMETHOD.


  METHOD is_complete.
    rv_complete = xsdbool( is_check-checkclass IS NOT INITIAL
                       AND is_check-checkcode  IS NOT INITIAL ).
  ENDMETHOD.


  METHOD resolve_class.

    " 🔴 미해결: 모듈 GUID 에서 체크 클래스명을 얻는 경로.
    "
    " 확인된 것
    "   - SATC_API_FINDINGS 에는 클래스명이 없다.
    "   - SATC_CI_R_EXEMPTION 에는 checkclass 가 있고 값은 CL_CI_TEST_DB 처럼
    "     고전 Code Inspector 의 체크 클래스명이다.
    "
    " 확인할 것 (아래 중 하나가 답이다)
    "   1. SATC_CI_R_EXEMPTION 에 moduleid 도 함께 있는가.
    "      있다면 그 뷰 자체가 GUID <-> 클래스명 대응표이므로 여기서 읽으면 된다.
    "   2. SATC_* 중 체크 모듈 레지스트리 테이블이 무엇인가.
    "      ADT 에서 SATC_API_FINDINGS 정의를 열어 moduleid 가 어느 테이블에서
    "      오는지 따라가면 나온다.
    "   3. CL_SATC_API 에 모듈 정보를 주는 메서드가 있는가.
    "
    " 셋 중 무엇으로 정해지든 고치는 곳은 이 메서드뿐이다.
    " 버퍼와 호출부는 그대로 둔 채 SELECT 한 줄만 들어간다.

    READ TABLE mt_buffer INTO DATA(ls_buffer) WITH KEY moduleid = iv_moduleid.
    IF sy-subrc = 0.
      rv_checkclass = ls_buffer-checkclass.
      RETURN.
    ENDIF.

    CLEAR rv_checkclass.

    INSERT VALUE #( moduleid   = iv_moduleid
                    checkclass = rv_checkclass ) INTO TABLE mt_buffer.

  ENDMETHOD.


  METHOD resolve_code.

    " 가설: module_msg_key 가 곧 체크 코드다.
    "   표준 예외의 checkcode 값이 DBREAD / UPDATE_SUC 처럼 기호 이름이고,
    "   module_msg_key 도 같은 성격의 메시지 키다. 타입만 CHAR25 로 넓다.
    "
    " 검증 방법: finding 한 건의 module_msg_key 를 적어두고 ADT 에서 그 건에
    "   Request Exemption 을 건 뒤, SATC_CI_R_EXEMPTION 의 checkcode 와 같은지
    "   비교한다. 다르면 이 메서드만 고치면 된다.
    "
    " 10 자를 넘으면 코드가 아니다. 잘라서 틀린 값을 만드는 대신 비워 돌려주고,
    " 호출자가 사용자에게 입력받게 한다.
    IF strlen( iv_modulemsgkey ) > 10.
      CLEAR rv_checkcode.
      RETURN.
    ENDIF.

    rv_checkcode = iv_modulemsgkey.

  ENDMETHOD.

ENDCLASS.
