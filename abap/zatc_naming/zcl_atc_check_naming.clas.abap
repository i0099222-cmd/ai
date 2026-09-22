"! 사내 네이밍 규칙 ATC 체크.
"!
"! 오브젝트 이름을 ZTATCNAMING 의 정규식과 대조하고, 어긋나면 finding 을 낸다.
"! 규칙은 이 클래스에 없다. 전부 테이블에 있고 SM30 으로 유지한다 - 개발 표준이
"! 바뀔 때 이 클래스를 고치게 되면 테이블로 뺀 의미가 없다.
"!
"! 소스 코드는 보지 않는다. 검사 대상이 오브젝트의 "이름" 이기 때문이고,
"! 그래서 CL_CI_TEST_SCAN(소스 스캔)이 아니라 CL_CI_TEST_ROOT 를 상속한다.
"! 메서드명/변수명 같은 내부 이름까지 보려면 그때 스캔 계열로 확장한다(Phase 2).
"!
"! 🔴 프레임워크 접점 3곳은 ADT 에서 CL_CI_TEST_ROOT 를 열어 확인할 것.
"!   1) add_obj_type( )   - 이 체크가 다룰 오브젝트 타입 등록. 메서드명 확인.
"!   2) inform( )         - 파라미터 이름과 필수 여부 확인.
"!   3) get_message_text( ) - 메시지 텍스트를 여기서 주는 게 맞는지,
"!                            아니면 SCIMESSAGES 등록 방식인지 확인.
"! 나머지(규칙 조회와 대조)는 프레임워크와 무관하므로 그대로 쓰면 된다.
CLASS zcl_atc_check_naming DEFINITION
  PUBLIC
  INHERITING FROM cl_ci_test_root
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES: BEGIN OF ty_violation,
             seqnr    TYPE ztatcnaming-seqnr,
             priority TYPE ztatcnaming-priority,
             pattern  TYPE ztatcnaming-pattern,
             msgtext  TYPE ztatcnaming-msgtext,
           END OF ty_violation,
           tt_violation TYPE STANDARD TABLE OF ty_violation WITH EMPTY KEY.

    METHODS constructor.

    METHODS run             REDEFINITION.
    METHODS get_message_text REDEFINITION.

    "! 이름 하나를 규칙과 대조한다.
    "!
    "! public 인 이유: 규칙을 새로 넣을 때마다 ATC 를 돌려 확인하면 한 번에
    "! 몇 분씩 걸린다. 이 메서드는 콘솔에서 바로 부를 수 있다.
    "!   zcl_atc_check_naming=>...->check_name( iv_objtype = 'CLAS'
    "!                                          iv_objname = 'ZCL_FOO' )
    METHODS check_name
      IMPORTING iv_objtype          TYPE trobjtype
                iv_objname          TYPE sobj_name
      RETURNING VALUE(rt_violation) TYPE tt_violation.

ENDCLASS.


CLASS zcl_atc_check_naming IMPLEMENTATION.

  METHOD constructor.

    super->constructor( ).

    " 체크 트리와 ATC 결과에 뜨는 이름이다. 시스템 언어가 EN 이라 영어로 쓴다.
    description    = 'Naming conventions (customer rules)'.
    category       = 'CL_CI_CATEGORY_SYNTAX'.
    version        = '001'.
    position       = '001'.

    " 체크 파라미터를 변형에 두지 않는다. 규칙은 전부 ZTATCNAMING 이다.
    has_attributes = c_false.
    attributes_ok  = c_true.

    " 다룰 오브젝트 타입을 규칙 테이블에서 정한다. 이렇게 두면 새 타입의
    " 규칙을 넣을 때 행만 추가하면 되고 이 클래스는 그대로다. 등록하지 않은
    " 타입에 대해서는 ATC 가 이 체크를 부르지 않으므로 헛도는 호출도 없다.
    SELECT DISTINCT objtype FROM ztatcnaming
      WHERE active = @abap_true
      INTO TABLE @DATA(lt_objtype).

    LOOP AT lt_objtype INTO DATA(ls_objtype).
      add_obj_type( CONV #( ls_objtype-objtype ) ).
    ENDLOOP.

  ENDMETHOD.


  METHOD run.

    " object_type / object_name 은 상위 클래스가 호출 직전에 채워 준다.
    LOOP AT check_name( iv_objtype = object_type
                        iv_objname = object_name ) INTO DATA(ls_violation).

      inform( p_sub_obj_type = object_type
              p_sub_obj_name = object_name
              p_test         = myname
              p_code         = '001'
              " 우선순위를 규칙마다 다르게 둔다. 접두어 위반은 error,
              " 권장 사항은 note 로 두는 식으로 팀이 조절할 수 있어야 한다.
              p_kind         = SWITCH #( ls_violation-priority
                                         WHEN 1 THEN c_error
                                         WHEN 2 THEN c_warning
                                         ELSE        c_note )
              p_param_1      = CONV #( object_name )
              p_param_2      = CONV #( ls_violation-msgtext ) ).

    ENDLOOP.

  ENDMETHOD.


  METHOD check_name.

    SELECT seqnr, priority, pattern, msgtext FROM ztatcnaming
      WHERE objtype = @iv_objtype
        AND active  = @abap_true
      ORDER BY seqnr
      INTO TABLE @DATA(lt_rule).

    LOOP AT lt_rule INTO DATA(ls_rule).

      DATA(lv_msgtext) = ls_rule-msgtext.

      TRY.
          " matches( ) 는 전체 일치다. 이름의 일부만 보고 싶어도 부분 일치가
          " 되지 않으므로, 접두어만 보는 규칙은 뒤에 .* 를 붙여 써야 한다.
          "   ^Z(CL|CX|BP)_[A-Z]{2}.*$   <- 접두어 + 모듈코드까지만 본다
          " ^ 와 $ 는 그래서 없어도 같지만, 규칙을 읽는 사람이 범위를 오해하지
          " 않도록 붙여 쓰는 것을 권한다.
          "
          " pcre = 는 7.55 이상이다. 하위 릴리스면 regex = 로 바꾼다.
          IF matches( val  = CONV string( iv_objname )
                      pcre = CONV string( ls_rule-pattern ) ).
            CONTINUE.
          ENDIF.

        CATCH cx_sy_invalid_regex.
          " 잘못 쓴 정규식을 조용히 넘기면 그 규칙은 꺼진 것과 같은데
          " 아무도 모른다. 위반으로 올려서 눈에 띄게 한다.
          lv_msgtext = |Invalid pattern in ZTATCNAMING { iv_objtype }/| &&
                       |{ ls_rule-seqnr }: { ls_rule-pattern }|.
      ENDTRY.

      APPEND VALUE #( seqnr    = ls_rule-seqnr
                      priority = ls_rule-priority
                      pattern  = ls_rule-pattern
                      msgtext  = lv_msgtext ) TO rt_violation.

    ENDLOOP.

  ENDMETHOD.


  METHOD get_message_text.

    " 규칙마다 다른 문장을 보여야 하므로 텍스트를 여기 고정하지 않고
    " 파라미터로 받는다. &2 가 ZTATCNAMING-msgtext 다.
    CASE p_code.
      WHEN '001'.
        p_text = '&1: &2'.
      WHEN OTHERS.
        super->get_message_text(
          EXPORTING p_test = p_test
                    p_code = p_code
          IMPORTING p_text = p_text ).
    ENDCASE.

  ENDMETHOD.

ENDCLASS.
