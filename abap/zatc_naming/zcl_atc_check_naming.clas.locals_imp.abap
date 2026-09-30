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
    " run( ) 이 규칙의 msgtext 를 param_1 로 채운다.
    "
    " 🔴 필드 이름 확인 필요. text 가 message 나 description 일 수 있다.
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
