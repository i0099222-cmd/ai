"! ZI_AtcFinding 의 behavior pool.
"!
"! 조회 화면에서 고른 위반들로 예외 신청서를 만든다. 신청서 생성 자체는
"! ZR_AtcExemption 의 createFromFinding 이 하고, 여기서는 선택 건을 묶어
"! 몇 건을 만들지만 정한다.
"!
"! create_requests 는 패키지 탭(zbp_i_atcfindingpkg)도 같이 쓴다.
CLASS zbp_i_atcfinding DEFINITION
  PUBLIC
  ABSTRACT
  FINAL
  FOR BEHAVIOR OF zi_atcfinding.

  PUBLIC SECTION.

    TYPES tt_create  TYPE TABLE FOR ACTION IMPORT zr_atcexemption\\exemption~createfromfinding.
    TYPES tt_message TYPE STANDARD TABLE OF REF TO if_abap_behv_message WITH EMPTY KEY.

    "! 신청서를 만들고 저장 전 검증(checkRequest)까지 돌린다.
    "! @parameter et_message | 생성 단계에서 나온 메시지. 호출한 탭의 reported 로 올린다
    "! @parameter ev_created | 만든 건수. 검증에 하나라도 걸리면 0 - 저장 단계에서 전부 실패한다
    CLASS-METHODS create_requests
      IMPORTING it_action  TYPE tt_create
      EXPORTING et_message TYPE tt_message
                ev_created TYPE i.

ENDCLASS.


CLASS zbp_i_atcfinding IMPLEMENTATION.

  METHOD create_requests.

    CLEAR: et_message, ev_created.

    IF it_action IS INITIAL.
      RETURN.
    ENDIF.

    " 🔴 초안으로 만들지 활성 인스턴스로 만들지는 %is_draft 가 정한다.
    "   여기서는 활성으로 만든다 - 초안으로 만들면 사용자가 신청서를 하나씩
    "   열어 저장해야 하고, 여러 건을 한 번에 만드는 의미가 없어진다.
    MODIFY ENTITIES OF zr_atcexemption
      ENTITY exemption
        EXECUTE createfromfinding FROM it_action
      MAPPED DATA(lt_mapped)
      FAILED DATA(lt_failed)
      REPORTED DATA(lt_reported).

    " 생성 쪽에서 나온 메시지를 그대로 화면에 올린다. 몇 건 중 몇 건이
    " 실패했는지는 사용자가 알아야 한다.
    LOOP AT lt_reported-exemption INTO DATA(ls_rep) WHERE %msg IS BOUND.
      APPEND ls_rep-%msg TO et_message.
    ENDLOOP.

    IF lt_mapped-exemption IS INITIAL.
      RETURN.
    ENDIF.

    " 여기서 만든 것은 버퍼의 신청서이고, 검증은 저장 단계에서 돈다.
    " 그대로 성공을 알리면 저장에서 실패할 건에도 성공 메시지가 에러와 같이 뜬다.
    " 그래서 checkRequest 로 같은 검증을 지금 돌려 보고, 하나라도 걸리면 성공을
    " 알리지 않는다. 그 에러는 여기서 올리지 않는다 - 저장 단계의 검증이 같은
    " 에러를 다시 올리므로, 여기서도 올리면 두 번 뜬다.
    "
    " 판정은 FAILED 가 아니라 REPORTED 의 에러 메시지로 한다. determine action 은
    " 안에서 돈 validation 이 failed 를 채워도 그것을 호출한 쪽에 돌려주지 않는다
    " (확인함 - validateValidity 가 failed 를 채웠는데 여기서는 비어 있었다).
    MODIFY ENTITIES OF zr_atcexemption
      ENTITY exemption
        EXECUTE checkrequest FROM VALUE #( FOR ls_new IN lt_mapped-exemption
                                           ( %tky = ls_new-%tky ) )
      FAILED DATA(lt_check_failed)
      REPORTED DATA(lt_check_reported).

    IF lt_check_failed-exemption IS NOT INITIAL.
      RETURN.
    ENDIF.
    LOOP AT lt_check_reported-exemption INTO DATA(ls_check) WHERE %msg IS BOUND.
      IF ls_check-%msg->m_severity = if_abap_behv_message=>severity-error.
        RETURN.
      ENDIF.
    ENDLOOP.

    ev_created = lines( lt_mapped-exemption ).

  ENDMETHOD.

ENDCLASS.
