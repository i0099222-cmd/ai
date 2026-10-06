"! 요청서 1건의 표준 예외 반영을 별도 LUW 에서 수행한다.
"!
"! 왜 별도 LUW 인가:
"!   send_to_approver( ) 를 비롯한 표준 API 가 내부에서 COMMIT 을 한다.
"!   RAP 액션 안에서 COMMIT 하면 우리 트랜잭션이 깨진다. cl_abap_parallel 이
"!   인스턴스를 별도 워크프로세스에서 돌리므로 그 안의 COMMIT 은 우리 LUW 를
"!   건드리지 않는다.
"!
"! 🔴 이 태스크는 **다른 DB 세션**에서 돈다. 우리 쪽 변경은 아직 커밋 전이라
"!   여기서 ztatcexempt / ztatcexempti 를 읽으면 안 된다. 필요한 값은 전부
"!   인스턴스 속성으로 받아 온다. 결과도 여기서 쓰지 않고 돌려준다.
"!
"! 요청서 단위로 전부 성공해야 성공이다.
"!   상신 : 한 줄이라도 실패하면 이번에 만든 표준 예외를 지워 되돌린다.
"!   승인 / 반려 : 표준 API 가 한 건씩 처리해서 이미 처리된 줄은 되돌릴 수 없다.
"!          실패하면 멈추고, 처리된 줄은 상태(stdstatus)로 알려 다음 시도가 건너뛰게 한다.
"!   철회 : 지울 수 있는 줄은 다 지운다. 남은 줄은 다음 시도가 지운다.
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
        "! 승인 -> 표준 승인
        approve  TYPE char10 VALUE 'APPROVE',
        "! 반려 -> 표준 반려 (승인 건도 반려할 수 있다)
        reject   TYPE char10 VALUE 'REJECT',
        "! 철회 / 만료 -> 표준 예외 삭제
        withdraw TYPE char10 VALUE 'WITHDRAW',
      END OF operation.

    METHODS constructor
      IMPORTING is_exemption TYPE ztatcexempt
                it_item      TYPE zif_atc_exemption=>tt_item
                iv_operation TYPE char10
                iv_reason    TYPE string OPTIONAL.

    METHODS if_abap_parallel~do REDEFINITION.

    "! 실행 결과. run_inst( ) 가 인스턴스를 돌려주므로 여기서 읽는다.
    METHODS get_result
      RETURNING VALUE(rs_result) TYPE zif_atc_exemption=>ty_batch_result.

  PRIVATE SECTION.

    DATA ms_exemption TYPE ztatcexempt.
    DATA mt_item      TYPE zif_atc_exemption=>tt_item.
    DATA mv_operation TYPE char10.
    DATA mv_reason    TYPE string.
    DATA ms_result    TYPE zif_atc_exemption=>ty_batch_result.

ENDCLASS.


CLASS zcl_atc_exempt_parallel IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    ms_exemption = is_exemption.
    mt_item      = it_item.
    mv_operation = iv_operation.
    mv_reason    = iv_reason.
  ENDMETHOD.


  METHOD get_result.
    rs_result = ms_result.
  ENDMETHOD.


  METHOD if_abap_parallel~do.

    " 여기는 별도 워크프로세스, 별도 LUW 다. 표준 API 의 내부 COMMIT 이
    " 허용되는 유일한 지점이다.
    DATA(lo_sync) = NEW zcl_atc_exempt_sync( ).

    " 결과는 들어온 상태에서 시작한다. 처리한 줄만 바꾼다.
    ms_result-success = abap_true.
    ms_result-items   = VALUE #( FOR ls_in IN mt_item
                                 ( itemuuid    = ls_in-itemuuid
                                   extexemptid = ls_in-extexemptid
                                   stdstatus   = ls_in-stdstatus ) ).

    LOOP AT mt_item INTO DATA(ls_item).

      ASSIGN ms_result-items[ itemuuid = ls_item-itemuuid ] TO FIELD-SYMBOL(<ls_res>).
      DATA(lv_target) = |{ ls_item-devclass }| &&
                        COND string( WHEN ls_item-objectname IS NOT INITIAL
                                     THEN | { ls_item-objecttype } { ls_item-objectname }| ).
      DATA(ls_sync) = VALUE zcl_atc_exempt_sync=>ty_result( success = abap_true ).

      CASE mv_operation.

        WHEN operation-register.
          " 앞선 상신에서 되돌리지 못하고 남은 줄이면 다시 만들지 않는다.
          IF ls_item-extexemptid IS NOT INITIAL.
            CONTINUE.
          ENDIF.
          ls_sync = lo_sync->create_exemption( is_exemption = ms_exemption
                                               is_item      = ls_item ).
          IF ls_sync-success = abap_true.
            <ls_res>-extexemptid = ls_sync-extexemptid.
            <ls_res>-stdstatus   = zif_atc_exemption=>stdstatus-pending.
          ENDIF.

        WHEN operation-approve.
          IF ls_item-stdstatus = zif_atc_exemption=>stdstatus-approved.
            CONTINUE.
          ENDIF.
          IF ls_item-extexemptid IS INITIAL.
            ls_sync = VALUE #( success = abap_false message = |표준 예외 없음 (상신 필요)| ).
          ELSE.
            ls_sync = lo_sync->approve_exemption( iv_extexemptid = ls_item-extexemptid
                                                  iv_assessment  = ms_exemption-reasontext ).
          ENDIF.
          IF ls_sync-success = abap_true.
            <ls_res>-stdstatus = zif_atc_exemption=>stdstatus-approved.
          ENDIF.

        WHEN operation-reject.
          IF ls_item-stdstatus = zif_atc_exemption=>stdstatus-rejected
          OR ls_item-extexemptid IS INITIAL.
            CONTINUE.
          ENDIF.
          ls_sync = lo_sync->reject_exemption( iv_extexemptid = ls_item-extexemptid
                                               iv_reason      = mv_reason ).
          IF ls_sync-success = abap_true.
            <ls_res>-stdstatus = zif_atc_exemption=>stdstatus-rejected.
          ENDIF.

        WHEN operation-withdraw.
          IF ls_item-extexemptid IS INITIAL.
            CONTINUE.
          ENDIF.
          ls_sync = lo_sync->revoke_exemption( iv_extexemptid = ls_item-extexemptid
                                               iv_reason      = mv_reason ).
          IF ls_sync-success = abap_true.
            CLEAR: <ls_res>-extexemptid, <ls_res>-stdstatus.
          ENDIF.

      ENDCASE.

      " 줄마다 확정한다. 표준은 한 건씩 바뀌므로 줄 단위로 맞춰 둬야 결과에 적은
      " 상태와 실제가 같다. 실패한 줄은 표준이 중간까지 바꾼 것을 버린다.
      IF ls_sync-success = abap_true.
        COMMIT WORK.
        CONTINUE.
      ENDIF.

      ROLLBACK WORK.
      ms_result-success = abap_false.
      ms_result-message = COND #( WHEN ms_result-message IS INITIAL
                                  THEN |{ lv_target }: { ls_sync-message }|
                                  ELSE |{ ms_result-message } / { lv_target }: { ls_sync-message }| ).

      " 철회는 남은 줄도 계속 지운다. 나머지는 첫 실패에서 멈춘다.
      IF mv_operation <> operation-withdraw.
        EXIT.
      ENDIF.

    ENDLOOP.

    " 상신 실패: 이번에 만든 표준 예외를 지워 요청서를 상신 전으로 되돌린다.
    " 처음부터 있던 ID(앞선 실패의 잔재)는 건드리지 않는다.
    IF mv_operation = operation-register AND ms_result-success = abap_false.
      LOOP AT ms_result-items ASSIGNING <ls_res> WHERE extexemptid IS NOT INITIAL.
        IF line_exists( mt_item[ itemuuid = <ls_res>-itemuuid extexemptid = <ls_res>-extexemptid ] ).
          CONTINUE.
        ENDIF.
        DATA(ls_undo) = lo_sync->revoke_exemption( iv_extexemptid = <ls_res>-extexemptid
                                                   iv_reason      = |상신 실패로 되돌림| ).
        IF ls_undo-success = abap_true.
          CLEAR: <ls_res>-extexemptid, <ls_res>-stdstatus.
        ELSE.
          ms_result-message = |{ ms_result-message } / 되돌리기 실패 { <ls_res>-extexemptid }: { ls_undo-message }|.
        ENDIF.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
