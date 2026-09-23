"! 사내 네이밍 규칙 ATC 체크.
"!
"! 오브젝트 이름을 ZTATCNAMING 의 정규식과 대조한다. 규칙은 이 클래스에 없다.
"! 전부 테이블에 있고 SM30 으로 유지한다.
"!
"! 전제: S/4HANA 2022 이상 (IF_CI_ATC_CHECK 지원 릴리스).
CLASS zcl_atc_check_naming DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_ci_atc_check.

    "! 심각도별 finding 코드.
    "! ty_finding 에 심각도 필드가 없어서 코드로 나눈다.
    CONSTANTS:
      BEGIN OF finding_codes,
        error   TYPE if_ci_atc_check=>ty_finding_code VALUE 'NAMING_E',
        warning TYPE if_ci_atc_check=>ty_finding_code VALUE 'NAMING_W',
        note    TYPE if_ci_atc_check=>ty_finding_code VALUE 'NAMING_N',
      END OF finding_codes.

    TYPES: BEGIN OF ty_violation,
             seqnr    TYPE ztatcnaming-seqnr,
             priority TYPE ztatcnaming-priority,
             msgtext  TYPE string,
           END OF ty_violation,
           tt_violation TYPE STANDARD TABLE OF ty_violation WITH EMPTY KEY.

    "! 이름 하나를 규칙과 대조한다. ATC 를 돌리지 않고 콘솔에서 확인용.
    "!   NEW zcl_atc_check_naming( )->check_name( iv_objtype = 'CLAS'
    "!                                            iv_objname = 'ZCL_FOO' )
    METHODS check_name
      IMPORTING iv_objtype          TYPE if_ci_atc_check=>ty_object-type
                iv_objname          TYPE if_ci_atc_check=>ty_object-name
      RETURNING VALUE(rt_violation) TYPE tt_violation.

ENDCLASS.


CLASS zcl_atc_check_naming IMPLEMENTATION.

  METHOD check_name.

    SELECT seqnr, priority, pattern, msgtext FROM ztatcnaming
      WHERE objtype = @iv_objtype
        AND active  = @abap_true
      ORDER BY seqnr
      INTO TABLE @DATA(lt_rule).

    LOOP AT lt_rule INTO DATA(ls_rule).

      DATA(lv_msgtext) = CONV string( ls_rule-msgtext ).

      TRY.
          " matches( ) 는 전체 일치다. 접두어만 보는 규칙은 뒤에 .* 가 있어야 한다.
          " pcre = 는 7.55 이상. 하위 릴리스면 regex = 로 바꾼다.
          IF matches( val  = CONV string( iv_objname )
                      pcre = CONV string( ls_rule-pattern ) ).
            CONTINUE.
          ENDIF.

        CATCH cx_sy_invalid_regex.
          " 잘못 쓴 정규식은 위반으로 올린다. 넘기면 규칙이 꺼진 줄 모른다.
          lv_msgtext = |Invalid pattern { iv_objtype }/{ ls_rule-seqnr }: | &&
                       |{ ls_rule-pattern }|.
      ENDTRY.

      APPEND VALUE #( seqnr    = ls_rule-seqnr
                      priority = ls_rule-priority
                      msgtext  = lv_msgtext ) TO rt_violation.

    ENDLOOP.

  ENDMETHOD.


  METHOD if_ci_atc_check~run.

    " data_provider 는 쓰지 않는다. 검사 대상이 이름뿐이고 object 에 있다.
    LOOP AT check_name( iv_objtype = object-type
                        iv_objname = object-name ) INTO DATA(ls_violation).

      " 위치는 오브젝트까지만. 이름 검사라 줄/칼럼이 없다.
      " 메시지는 param_1 로 넘긴다. 규칙마다 문장이 다르다.
      INSERT VALUE #(
        code       = SWITCH #( ls_violation-priority
                               WHEN '1' THEN finding_codes-error
                               WHEN '2' THEN finding_codes-warning
                               ELSE          finding_codes-note )
        location   = VALUE #( object = object )
        parameters = VALUE #( param_1 = ls_violation-msgtext
                              param_2 = CONV string( object-name ) )
      ) INTO TABLE findings.

    ENDLOOP.

  ENDMETHOD.


  METHOD if_ci_atc_check~get_meta_data.

    " 메타데이터는 Local Types 의 lcl_meta_data 다.
    meta_data = NEW lcl_meta_data( ).

  ENDMETHOD.


  METHOD if_ci_atc_check~set_assistant_factory.
    " 소스를 읽지 않으므로 필요 없다.
  ENDMETHOD.


  METHOD if_ci_atc_check~set_attributes.
    " 체크 파라미터를 쓰지 않는다. 규칙은 ZTATCNAMING 에 있다.
  ENDMETHOD.


  METHOD if_ci_atc_check~verify_prerequisites.
    " 전제 조건 없음.
  ENDMETHOD.

ENDCLASS.
