"! 사내 네이밍 규칙 ATC 체크.
"!
"! 오브젝트 이름을 ZTATCNAMING 의 정규식과 대조하고, 어긋나면 finding 을 낸다.
"! 규칙은 이 클래스에 없다. 전부 테이블에 있고 SM30 으로 유지한다 - 개발 표준이
"! 바뀔 때 이 클래스를 고치게 되면 테이블로 뺀 의미가 없다.
"!
"! 신규 ATC API(IF_CI_ATC_CHECK)를 쓴다. 구 Code Inspector(CL_CI_TEST_ROOT)가
"! 아니다. 구 API 는 SCI 의 "Management of Tests" 등록과 카테고리 클래스명을
"! 요구하는데, 신규 API 는 그 자리를 ADT 의 ATC Check / ATC Check Category
"! 오브젝트가 대신한다. 카테고리는 코드가 아니라 그 오브젝트에서 고른다.
"!
"! 전제: S/4HANA 2022 이상. 미만이면 이 인터페이스가 없다.
CLASS zcl_atc_check_naming DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_ci_atc_check.

    "! finding 코드를 심각도별로 셋 둔다.
    "!
    "! ty_finding 에는 심각도 필드가 없다. 심각도는 finding 코드마다
    "! get_meta_data( ) 에서 한 번 정해지는 값이다. 그래서 규칙의 priority 를
    "! 건별로 반영하려면 코드를 심각도만큼 나누는 수밖에 없다.
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

    "! 이름 하나를 규칙과 대조한다. 위반한 규칙들을 돌려준다.
    "!
    "! run( ) 과 나눈 이유는 재사용이 아니라 확인 때문이다. 규칙을 새로 넣을
    "! 때마다 ATC 를 돌려 보면 한 번에 몇 분씩 걸린다. 이 메서드는 콘솔에서
    "! 바로 부를 수 있다.
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
          " matches( ) 는 전체 일치다. 이름의 일부만 보고 싶어도 부분 일치가
          " 되지 않으므로, 접두어만 보는 규칙은 뒤에 .* 를 붙여 써야 한다.
          "   ^Z(CL|CX|BP)_[A-Z]{2}.*$   <- 접두어 + 모듈코드까지만 본다
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
                      msgtext  = lv_msgtext ) TO rt_violation.

    ENDLOOP.

  ENDMETHOD.


  METHOD if_ci_atc_check~run.

    " 🔴 형식 인자 이름 확인 필요.
    "   검사 대상(ty_object)과 결과(ty_findings)를 어떤 이름으로 주고받는지는
    "   ADT 에서 if_ci_atc_check 의 METHODS run 선언을 보고 맞춘다.
    "   아래 ls_object / findings 를 그 이름으로 바꾸면 된다.
    DATA(ls_object) = VALUE if_ci_atc_check=>ty_object( ).

    LOOP AT check_name( iv_objtype = ls_object-type
                        iv_objname = ls_object-name ) INTO DATA(ls_violation).

      " 위치는 오브젝트까지만 준다. 검사 대상이 소스의 한 줄이 아니라
      " 오브젝트의 "이름" 이라 줄/칼럼이 존재하지 않는다.
      "
      " 메시지 본문은 param_1 로 넘긴다. 규칙마다 문장이 다르므로 finding
      " 코드에 고정 텍스트를 걸 수 없고, get_meta_data( ) 에 등록하는 텍스트는
      " &1 하나만 두고 그 자리를 규칙의 msgtext 로 채운다.
      INSERT VALUE #(
        code       = SWITCH #( ls_violation-priority
                               WHEN '1' THEN finding_codes-error
                               WHEN '2' THEN finding_codes-warning
                               ELSE          finding_codes-note )
        location   = VALUE #( object = ls_object )
        parameters = VALUE #( param_1 = ls_violation-msgtext
                              param_2 = CONV string( ls_object-name ) )
      ) INTO TABLE findings.

    ENDLOOP.

  ENDMETHOD.


  METHOD if_ci_atc_check~get_meta_data.

    " 🔴 반환 파라미터의 이름과 타입 확인 필요 (ADT 의 인터페이스 선언).
    "
    " 여기에 넣을 것:
    "   - 체크 제목/설명
    "   - 다룰 오브젝트 타입. ZTATCNAMING 에 규칙이 있는 타입만 넣는다.
    "       SELECT DISTINCT objtype FROM ztatcnaming WHERE active = @abap_true
    "     이렇게 테이블에서 끌어오면 새 타입의 규칙을 넣을 때 코드를 안 고친다.
    "   - finding 코드 3개와 각각의 심각도/메시지 텍스트
    "       NAMING_E -> error   / '&1'
    "       NAMING_W -> warning / '&1'
    "       NAMING_N -> note    / '&1'
    "     텍스트를 '&1' 하나로 두는 이유는 위 run( ) 의 주석과 같다.

  ENDMETHOD.


  METHOD if_ci_atc_check~set_assistant_factory.

    " 소스를 읽지 않으므로 보조 팩토리가 필요 없다. 오브젝트의 이름만 보는
    " 체크이고, 이름은 run( ) 이 받는 ty_object 에 이미 들어 있다.

  ENDMETHOD.


  METHOD if_ci_atc_check~set_attributes.

    " 체크 파라미터를 쓰지 않는다.
    "
    " SAP 예제는 이름 패턴을 체크 변형의 파라미터로 둔다. 그러면 규칙을 바꿀
    " 때마다 변형을 고쳐 이송해야 하고 개발자가 아니면 손댈 수 없다. 규칙을
    " ZTATCNAMING 에 둔 이유가 그것이므로 여기서는 비워 둔다.

  ENDMETHOD.


  METHOD if_ci_atc_check~verify_prerequisites.

    " 전제 조건 없음. 규칙 테이블이 비어 있으면 위반이 하나도 안 나올 뿐
    " 체크가 실패하는 것은 아니다.

  ENDMETHOD.

ENDCLASS.
