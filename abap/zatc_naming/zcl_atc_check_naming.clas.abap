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

    "! 정규식이 잘못된 규칙에 쓰는 코드. 규칙별 코드와 겹치지 않게 N 뒤를 유형이
    "! 아닌 문자로 둔다.
    CONSTANTS invalid_pattern_code TYPE if_ci_atc_check=>ty_finding_code VALUE 'NINVALID'.

    "! 규칙 하나의 finding 코드. N + 오브젝트 유형 + 순번 (예: NDOMA010, 8자).
    "!
    "! 규칙마다 코드를 따로 두는 이유: ATC 는 코드마다 제목을 하나 등록하고
    "! (SATC_AC_MSGT), 조회 뷰의 messagetitle 은 거기서 온다. 코드를 심각도별
    "! 셋으로 두고 규칙 문장을 &1 로 넘겼더니 제목이 '...' 으로 저장됐다.
    "! 규칙마다 코드를 두면 그 규칙의 문장이 곧 제목이 된다.
    "!
    "! 메타데이터와 run( ) 이 같은 코드를 만들어야 해서 한 곳에 둔다.
    CLASS-METHODS rule_code
      IMPORTING iv_objtype     TYPE ztatcnaming-objtype
                iv_seqnr       TYPE ztatcnaming-seqnr
      RETURNING VALUE(rv_code) TYPE if_ci_atc_check=>ty_finding_code.

ENDCLASS.


CLASS zcl_atc_check_naming IMPLEMENTATION.

  METHOD rule_code.

    rv_code = |N{ iv_objtype }{ iv_seqnr }|.

  ENDMETHOD.


  METHOD if_ci_atc_check~run.

    " data_provider 는 쓰지 않는다. 검사 대상이 이름뿐이고 object 에 있다.
    SELECT seqnr, pattern, msgtext FROM ztatcnaming
      WHERE objtype = @object-type
        AND active  = @abap_true
      ORDER BY seqnr
      INTO TABLE @DATA(lt_rule).

    LOOP AT lt_rule INTO DATA(ls_rule).

      DATA(lv_code)    = rule_code( iv_objtype = CONV #( object-type ) iv_seqnr = ls_rule-seqnr ).
      DATA(lv_msgtext) = CONV string( ls_rule-msgtext ).

      TRY.
          " matches( ) 는 전체 일치다. 접두어만 보는 규칙은 뒤에 .* 가 있어야 한다.
          " pcre = 는 7.55 이상. 하위 릴리스면 regex = 로 바꾼다.
          IF matches( val  = CONV string( object-name )
                      pcre = CONV string( ls_rule-pattern ) ).
            CONTINUE.
          ENDIF.

        CATCH cx_sy_invalid_regex.
          " 잘못 쓴 정규식은 위반으로 올린다. 넘기면 규칙이 꺼진 줄 모른다.
          lv_code    = invalid_pattern_code.
          lv_msgtext = |{ object-type }/{ ls_rule-seqnr }: { ls_rule-pattern }|.
      ENDTRY.

      " 위치는 오브젝트까지만. 이름 검사라 줄/칼럼이 없다.
      " 심각도와 문장은 코드에 붙어 있다(get_finding_code_infos). param_1 은
      " 잘못된 정규식 코드의 &1 에만 쓰인다.
      INSERT VALUE #(
        code       = lv_code
        location   = VALUE #( object = object )
        parameters = VALUE #( param_1 = lv_msgtext )
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
