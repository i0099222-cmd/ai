"! 표준 예외 저장소 반영을 별도 LUW 에서 수행한다.
"!
"! 왜 별도 LUW 인가:
"!   send_to_approver( ) 를 비롯한 표준 API 가 내부에서 COMMIT 을 한다.
"!   RAP 저장 시퀀스(save_modified) 안에서는 COMMIT 이 금지라 덤프가 난다.
"!   cl_abap_parallel 이 각 인스턴스를 별도 워크프로세스에서 돌리므로
"!   그 안의 COMMIT 은 우리 LUW 를 건드리지 않는다.
"!
"! 🔴 중요한 제약: 이 태스크는 **다른 DB 세션**에서 돈다.
"!   save_modified 시점에 우리 트랜잭션은 아직 커밋되지 않았으므로, 여기서
"!   ztatcexempt 를 다시 읽으면 변경 전 값이 보이거나 아예 안 보인다.
"!   그래서 필요한 데이터를 전부 인스턴스 속성으로 받아 온다. 읽지 않는다.
"!
"! 같은 이유로 결과(extexemptid)도 여기서 쓰지 않는다. 속성에 담아 돌려주고,
"! 호출자가 자기 LUW 에서 기록한다. 여기서 쓰면 우리 커밋과 순서가 엉킨다.
CLASS zcl_atc_exempt_parallel DEFINITION
  PUBLIC
  INHERITING FROM cl_abap_parallel
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF operation,
        "! 상신 -> 표준에 승인대기로 생성
        register TYPE char10 VALUE 'REGISTER',
        "! 승인 -> 표준 승인. extexemptid 가 없으면 생성부터 한다.
        approve  TYPE char10 VALUE 'APPROVE',
        "! 반려 / 철회 / 만료 -> 표준 무효화 (승인자 행위)
        revoke   TYPE char10 VALUE 'REVOKE',
        "! 상신철회 -> 신청자가 자기 신청을 삭제
        withdraw TYPE char10 VALUE 'WITHDRAW',
      END OF operation.

    METHODS constructor
      IMPORTING is_exemption TYPE ztatcexempt
                iv_operation TYPE char10
                iv_reason    TYPE string OPTIONAL.

    METHODS if_abap_parallel~do REDEFINITION.

    "! 실행 결과. run_inst( ) 가 인스턴스를 돌려주므로 여기서 읽는다.
    METHODS get_result
      RETURNING VALUE(rs_result) TYPE zcl_atc_exempt_sync=>ty_result.

    METHODS get_exemptuuid
      RETURNING VALUE(rv_uuid) TYPE sysuuid_x16.

    METHODS get_operation
      RETURNING VALUE(rv_operation) TYPE char10.

  PRIVATE SECTION.

    "! 호출자가 넘겨 준 신청서 전체. 태스크 안에서 DB 를 읽지 않기 위함이다.
    DATA ms_exemption TYPE ztatcexempt.
    DATA mv_operation TYPE char10.
    DATA mv_reason    TYPE string.
    DATA ms_result    TYPE zcl_atc_exempt_sync=>ty_result.

ENDCLASS.


CLASS zcl_atc_exempt_parallel IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    ms_exemption = is_exemption.
    mv_operation = iv_operation.
    mv_reason    = iv_reason.
  ENDMETHOD.


  METHOD get_result.
    rs_result = ms_result.
  ENDMETHOD.


  METHOD get_exemptuuid.
    rv_uuid = ms_exemption-exemptuuid.
  ENDMETHOD.


  METHOD get_operation.
    rv_operation = mv_operation.
  ENDMETHOD.


  METHOD if_abap_parallel~do.

    " 여기는 별도 워크프로세스, 별도 LUW 다. 표준 API 의 내부 COMMIT 이
    " 허용되는 유일한 지점이다.
    DATA(lo_sync) = NEW zcl_atc_exempt_sync( ).

    CASE mv_operation.

      WHEN operation-register.
        ms_result = lo_sync->create_exemption( ms_exemption ).

      WHEN operation-approve.

        " 상신 때 등록이 실패했던 건이면 생성부터 한다. 이 보정이 없으면
        " 대장은 승인인데 ATC 는 계속 막는 상태로 굳는다.
        DATA(lv_extid) = ms_exemption-extexemptid.

        IF lv_extid IS INITIAL.
          DATA(ls_created) = lo_sync->create_exemption( ms_exemption ).
          lv_extid = ls_created-extexemptid.
        ENDIF.

        IF lv_extid IS INITIAL.
          ms_result = ls_created.
        ELSE.
          ms_result = lo_sync->approve_exemption(
                        iv_extexemptid = lv_extid
                        iv_assessment  = ms_exemption-reasontext ).
        ENDIF.

      WHEN operation-withdraw.
        ms_result = lo_sync->withdraw_exemption( ms_exemption ).

      WHEN operation-revoke.
        ms_result = lo_sync->revoke_exemption(
                      iv_extexemptid = ms_exemption-extexemptid
                      iv_reason      = mv_reason ).

    ENDCASE.

    " 여기는 자기 LUW 이므로 COMMIT 이 합법이고, 필요하다.
    "
    " create 는 send_to_approver( ) 가 내부에서 커밋하기 때문에 이것 없이도
    " 행이 남았다. 하지만 approve_exemption_by_id( ) / reject_exemptions_by_id( )
    " 는 커밋하지 않는 것으로 보인다 - 철회 후에도 state 가 OPEN 그대로였다.
    " 커밋 없이 워크프로세스가 끝나면 변경이 사라진다.
    "
    " 실패한 경우에는 커밋하지 않는다. 표준이 중간까지 바꿔 둔 것을 확정시키면
    " 어느 상태인지 알 수 없는 행이 남는다.
    IF ms_result-success = abap_true.
      COMMIT WORK.
    ELSE.
      ROLLBACK WORK.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
