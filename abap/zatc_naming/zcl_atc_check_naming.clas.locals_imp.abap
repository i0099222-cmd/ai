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

    " 규칙마다 코드 하나. 제목은 그 규칙의 msgtext 이고 자리표시자를 넣지 않는다.
    "
    " ATC 는 코드마다 제목을 SATC_AC_MSGT 에 등록하고 조회 뷰의 messagetitle 은
    " 거기서 온다. 파라미터는 finding 마다 달라 제목에 못 들어가므로 &1 은
    " '...' 으로 저장된다(확인함). 규칙 문장을 제목 자체로 두면 그대로 들어간다.
    "
    " 한 번 등록된 코드의 제목은 바뀌지 않는다(확인함 - 문장을 바꾸고 재활성화해도
    " 그대로였다). 그래서 규칙 문장을 고칠 때는 행을 고치지 말고, 새 순번으로 행을
    " 추가하고 옛 행을 끈다. 새 순번이 새 코드가 되어 새 제목으로 등록된다.
    SELECT objtype, seqnr, priority, msgtext FROM ztatcnaming
      WHERE active = @abap_true
      INTO TABLE @DATA(lt_rule).

    finding_code_infos = VALUE #(
      FOR ls_rule IN lt_rule
      ( code     = zcl_atc_check_naming=>rule_code( iv_objtype = ls_rule-objtype
                                                    iv_seqnr   = ls_rule-seqnr )
        severity = SWITCH #( ls_rule-priority
                             WHEN '1' THEN if_ci_atc_check=>finding_severities-error
                             WHEN '2' THEN if_ci_atc_check=>finding_severities-warning
                             ELSE          if_ci_atc_check=>finding_severities-note )
        text     = CONV #( ls_rule-msgtext ) ) ).

    " 잘못 쓴 정규식. 어느 규칙인지는 ADT 에서 &1 로 보인다.
    INSERT VALUE #( code     = zcl_atc_check_naming=>invalid_pattern_code
                    severity = if_ci_atc_check=>finding_severities-error
                    text     = 'Invalid naming rule pattern: &1' )
           INTO TABLE finding_code_infos.

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
