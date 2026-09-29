CLASS lhc_finding DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS requestexemption FOR MODIFY
      IMPORTING keys FOR ACTION finding~requestexemption RESULT result.

ENDCLASS.


CLASS lhc_finding IMPLEMENTATION.

  METHOD requestexemption.

    READ ENTITIES OF zi_atcfinding IN LOCAL MODE
      ENTITY finding
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_finding).

    DATA lt_action TYPE TABLE FOR ACTION IMPORT zr_atcexemption\\exemption~createfromfinding.

    " 같은 그룹은 신청서 하나로 묶는다.
    "   PCKG : 패키지 + 체크가 같으면 한 건. 패키지 전체가 덮이므로 오브젝트를
    "          여럿 골라도 신청서는 하나면 된다.
    "   그 외 : 오브젝트 + 체크마다 한 건.
    DATA lt_seen TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.

    LOOP AT lt_finding INTO DATA(ls_finding).

      DATA(ls_param) = VALUE #( keys[ %tky-ResultId      = ls_finding-ResultId
                                      %tky-ItemId        = ls_finding-ItemId
                                      %tky-CheckRunIndex = ls_finding-CheckRunIndex
                                    ]-%param OPTIONAL ).

      DATA(lv_group) = COND string(
        WHEN ls_param-scopetype = zif_atc_exemption=>scope-pckg
        THEN |{ ls_finding-CheckVariant }|
          && |/{ ls_finding-Devclass }|
          && |/{ ls_finding-CheckClass }/{ ls_finding-CheckCode }|
        ELSE |{ ls_finding-CheckVariant }|
          && |/{ ls_finding-Devclass }|
          && |/{ ls_finding-ObjectType }/{ ls_finding-ObjectName }|
          && |/{ ls_finding-CheckClass }/{ ls_finding-CheckCode }| ).

      IF line_exists( lt_seen[ table_line = lv_group ] ).
        CONTINUE.
      ENDIF.
      INSERT lv_group INTO TABLE lt_seen.

      APPEND VALUE #(
        %cid  = |RE{ lines( lt_action ) + 1 }|
        %param = VALUE #( checkvariant = ls_finding-CheckVariant
                          devclass     = ls_finding-Devclass
                          objecttype   = ls_finding-ObjectType
                          objectname   = ls_finding-ObjectName
                          checkclass   = ls_finding-CheckClass
                          checkcode    = ls_finding-CheckCode
                          scopetype    = ls_param-scopetype
                          reasoncode   = ls_param-reasoncode
                          reasontext   = ls_param-reasontext
                          validto      = ls_param-validto ) ) TO lt_action.

    ENDLOOP.

    " 🔴 초안으로 만들지 활성 인스턴스로 만들지는 %is_draft 가 정한다.
    "   여기서는 활성으로 만든다 - 초안으로 만들면 사용자가 신청서를 하나씩
    "   열어 저장해야 하고, 여러 건을 한 번에 만드는 의미가 없어진다.
    MODIFY ENTITIES OF zr_atcexemption
      ENTITY exemption
        EXECUTE createfromfinding FROM lt_action
      FAILED DATA(lt_failed)
      REPORTED DATA(lt_reported).

    " 생성 쪽에서 나온 메시지를 그대로 화면에 올린다. 몇 건 중 몇 건이
    " 실패했는지는 사용자가 알아야 한다.
    LOOP AT lt_reported-exemption INTO DATA(ls_rep).
      APPEND VALUE #( %tky = keys[ 1 ]-%tky
                      %msg = ls_rep-%msg ) TO reported-finding.
    ENDLOOP.

    " 선택한 행을 그대로 돌려준다. finding 은 바뀌지 않지만, 화면이
    " 새로고침되면서 예외 상태 컬럼이 갱신된다.
    result = VALUE #( FOR ls_key IN keys ( %tky = ls_key-%tky ) ).

  ENDMETHOD.

ENDCLASS.
