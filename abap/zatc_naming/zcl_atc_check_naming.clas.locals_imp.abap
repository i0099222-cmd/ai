"! ZCL_ATC_CHECK_NAMING 의 Local Types (ADT 의 Local Types 탭).
"!
"! get_meta_data( ) 가 돌려줄 메타데이터 객체. SAP 이 주는 클래스가 아니라
"! 체크를 만드는 쪽이 직접 만든다.
CLASS lcl_meta_data DEFINITION
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_ci_atc_check_meta_data.

ENDCLASS.


CLASS lcl_meta_data IMPLEMENTATION.

  METHOD if_ci_atc_check_meta_data~get_description.

    description = 'Naming conventions (customer rules)'.

  ENDMETHOD.


  METHOD if_ci_atc_check_meta_data~get_checked_object_types.

    " 규칙이 있는 타입만. 새 타입은 행만 추가하면 되고 코드는 그대로다.
    SELECT DISTINCT objtype FROM ztatcnaming
      WHERE active = @abap_true
      INTO TABLE @DATA(lt_objtype).

    " 🔴 반환이 구조체 테이블이면 ( objtype = ls-objtype ) 로 바꾼다.
    checked_object_types = VALUE #( FOR ls IN lt_objtype
                                    ( CONV #( ls-objtype ) ) ).

  ENDMETHOD.


  METHOD if_ci_atc_check_meta_data~get_finding_code_infos.

    " 텍스트가 전부 '&1' 인 것은 실수가 아니다. 규칙마다 문장이 달라서
    " run( ) 이 규칙의 msgtext 를 param_1 로 채운다. ADT 결과에는 그 문장이 뜬다.
    "
    " ATC 는 코드마다 제목을 SATC_AC_MSGT 에 등록하고, SATC_API_FINDINGS-messagetitle
    " 은 거기서 온다. 파라미터는 finding 마다 달라 제목에 넣을 수 없으니 '&1' 은
    " '...' 으로 바뀌어 저장된다(확인함). 그 뒤 문장을 바꾸고 재활성화해도 그 제목은
    " 바뀌지 않았다 - 기존 코드의 제목을 다시 읽게 하는 방법은 아직 모른다.
    " 그래서 조회 앱의 문장은 ZI_AtcFinding 이 ZTATCNAMING 에서 직접 가져온다.
    finding_code_infos = VALUE #(
      ( code     = zcl_atc_check_naming=>finding_codes-error
        severity = if_ci_atc_check=>finding_severities-error
        text     = '&1' )
      ( code     = zcl_atc_check_naming=>finding_codes-warning
        severity = if_ci_atc_check=>finding_severities-warning
        text     = '&1' )
      ( code     = zcl_atc_check_naming=>finding_codes-note
        severity = if_ci_atc_check=>finding_severities-note
        text     = '&1' ) ).

  ENDMETHOD.


  METHOD if_ci_atc_check_meta_data~get_attributes.
    " 체크 파라미터를 쓰지 않는다.
  ENDMETHOD.


  METHOD if_ci_atc_check_meta_data~get_quickfix_code_infos.
    " 퀵픽스 없음. 이름 변경은 참조를 따라가야 해서 자동으로 못 고친다.
  ENDMETHOD.


  METHOD if_ci_atc_check_meta_data~is_remote_enabled.

    " 검사 대상 시스템의 데이터를 읽지 않는다.
    " 단, ZTATCNAMING 은 체크가 도는 쪽에 있어야 한다.
    is_remote_enabled = abap_true.

  ENDMETHOD.


  METHOD if_ci_atc_check_meta_data~uses_checksums.

    " finding 이 소스 줄이 아니라 오브젝트 이름에 붙는다.
    uses_checksums = abap_false.

  ENDMETHOD.

ENDCLASS.
