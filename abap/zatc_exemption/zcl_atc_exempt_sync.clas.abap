"! 요청서 1건을 표준 ATC 예외 저장소에 반영한다. 대상 한 줄 = 표준 예외 1건.
"!
"! 관리는 CBO, 실행은 표준. 신청·승인·이력은 CBO 테이블이 원천이고, 억제 자체는
"! 표준 예외가 한다. 표준 진입점은 CL_SATC_API 의 예외 컨트롤러이고, 삭제만은
"! 표준 앱의 Delete 와 같은 RAP BO SATC_CI_R_EXEMPTION 의 delete 를 쓴다.
"!
"! 별도 LUW 에서 돈다. 표준 API 가 내부에서 COMMIT 을 해서 RAP 액션 안에서는
"! 부를 수 없다. behavior pool 이 이 인스턴스를 cl_abap_parallel 로 돌리고,
"! 만료 배치는 do( ) 를 직접 부른다.
"! 🔴 다른 DB 세션이라 우리 테이블을 읽으면 안 된다. 필요한 값은 전부 받아 온다.
"!
"! 요청서 단위로 전부 성공해야 성공이다.
"!   상신 : 한 줄이라도 실패하면 이번에 만든 표준 예외를 지워 되돌린다.
"!   승인 / 반려 : 표준이 한 건씩 처리해서 이미 처리된 줄은 되돌릴 수 없다.
"!          첫 실패에서 멈추고, 처리된 줄은 stdstatus 로 알려 다음 시도가 건너뛰게 한다.
"!   철회 : 지울 수 있는 줄은 다 지운다. 남은 줄은 다음 시도가 지운다.
CLASS zcl_atc_exempt_sync DEFINITION
  PUBLIC
  INHERITING FROM cl_abap_parallel
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF operation,
        register TYPE char10 VALUE 'REGISTER',
        approve  TYPE char10 VALUE 'APPROVE',
        reject   TYPE char10 VALUE 'REJECT',
        withdraw TYPE char10 VALUE 'WITHDRAW',
      END OF operation.

    "! is_exemption-approver : 상신 때 표준 예외에 넣을 승인자 (호출자가 정해 넘긴다)
    METHODS constructor
      IMPORTING is_exemption TYPE ztatcexempt
                it_item      TYPE zif_atc_exemption=>tt_item
                iv_operation TYPE char10.

    METHODS if_abap_parallel~do REDEFINITION.

    METHODS get_result
      RETURNING VALUE(rs_result) TYPE zif_atc_exemption=>ty_batch_result.

    "! 현재 사용자가 표준 승인자 목록(SATC_CI_APPROVER)에 있는지.
    "! 권한 오브젝트는 보지 않는다. S_Q_GOVERN 은 개발자 대부분이 가져서 가려내지 못한다.
    CLASS-METHODS is_approver
      RETURNING VALUE(rv_can) TYPE abap_boolean.

  PRIVATE SECTION.

    DATA ms_exemption TYPE ztatcexempt.
    DATA mt_item      TYPE zif_atc_exemption=>tt_item.
    DATA mv_operation TYPE char10.
    DATA ms_result    TYPE zif_atc_exemption=>ty_batch_result.

ENDCLASS.


CLASS zcl_atc_exempt_sync IMPLEMENTATION.

  METHOD constructor.
    super->constructor( ).
    ms_exemption = is_exemption.
    mt_item      = it_item.
    mv_operation = iv_operation.
  ENDMETHOD.


  METHOD get_result.
    rs_result = ms_result.
  ENDMETHOD.


  METHOD is_approver.
    SELECT SINGLE @abap_true FROM satc_ci_approver
      WHERE approver = @sy-uname
      INTO @rv_can.
  ENDMETHOD.


  METHOD if_abap_parallel~do.

    " 결과는 들어온 상태에서 시작한다. 처리한 줄만 바꾼다.
    ms_result-success = abap_true.
    ms_result-items   = VALUE #( FOR ls_in IN mt_item
                                 ( itemuuid    = ls_in-itemuuid
                                   extexemptid = ls_in-extexemptid
                                   stdstatus   = ls_in-stdstatus ) ).

    LOOP AT mt_item INTO DATA(ls_item).

      " 컨트롤러는 줄마다 새로 받는다. 한 컨트롤러로 여러 줄을 처리하면 첫 줄을 커밋한 뒤
      " 둘째 줄부터 "The operation cannot be executed in the current state" 로 실패했다.
      DATA(lo_controller) = cl_satc_api=>create_api_factory( )->get_exemption_controller( ).

      ASSIGN ms_result-items[ itemuuid = ls_item-itemuuid ] TO FIELD-SYMBOL(<ls_res>).
      DATA(lv_target) = |{ ls_item-devclass }| &&
                        COND string( WHEN ls_item-objectname IS NOT INITIAL
                                     THEN | { ls_item-objecttype } { ls_item-objectname }| ).
      DATA(lv_error) = VALUE string( ).

      TRY.
          CASE mv_operation.

            WHEN operation-register.
              " 앞선 상신에서 되돌리지 못하고 남은 줄이면 다시 만들지 않는다.
              IF ls_item-extexemptid IS NOT INITIAL.
                CONTINUE.
              ENDIF.

              " 패키지 대상은 오브젝트를 비워 넘긴다. 표준은 i_package_name 만으로
              " 받고 저장 행의 DEVC / 패키지명을 스스로 파생한다(선등록 상신으로 확인함).
              " 오브젝트 자리에 패키지를 넣으면 TADIR 조회가 실패한다(확인함).
              " i_contact_person 은 넘겨도 표준이 쓰지 않는다. 신청자는 이 호출을
              " 실행한 사용자로 기록된다(확인함).
              DATA(lv_is_obj) = xsdbool( ls_item-scopetype = zif_atc_exemption=>scope-obj ).
              DATA(lo_new) = lo_controller->create_exemption(
                i_object_type    = COND trobjtype( WHEN lv_is_obj = abap_true THEN ls_item-objecttype )
                i_object_name    = COND sobj_name( WHEN lv_is_obj = abap_true THEN ls_item-objectname )
                i_package_name   = ls_item-devclass
                i_check_class    = ms_exemption-checkclass
                i_check_code     = ls_item-checkcode
                i_contact_person = ms_exemption-requester ).

              lo_new->set_object_scope( CONV #( ls_item-scopetype ) ).
              lo_new->set_check_scope( CONV #( ls_item-rulescope ) ).
              " 위치 인자로 넘기면 서술이 코드 자리로 들어간다. 이름으로 넘긴다.
              lo_new->set_reason( i_reason  = CONV #( ms_exemption-reasoncode )
                                  i_comment = ms_exemption-reasontext ).
              lo_new->set_validity_date( ms_exemption-validto ).
              " 표준은 승인자 1명이 있어야 승인대기로 올린다. 승인 때 실제로 누른 사람으로 바꾼다.
              lo_new->set_approver( i_approver = ms_exemption-approver ).
              lo_new->set_notification_type( zif_atc_exemption=>policy-notiftype ).
              lo_new->send_to_approver( ).
              lo_new->unlock( ).

              <ls_res>-extexemptid = lo_new->get_exemption_id( ).
              <ls_res>-stdstatus   = zif_atc_exemption=>stdstatus-pending.
              CLEAR lo_new.

            WHEN operation-approve.
              IF ls_item-stdstatus = zif_atc_exemption=>stdstatus-approved.
                CONTINUE.
              ENDIF.
              IF ls_item-extexemptid IS INITIAL.
                lv_error = |표준 예외 없음 (상신 필요)|.
              ELSE.
                " 표준은 지정된 승인자만 승인하게 한다. 상신 때 넣은 사람이 아니어도
                " 승인자 목록에 있으면 승인할 수 있게, 누른 사람으로 맞춘다.
                DATA(lo_old) = lo_controller->get_exemption( ls_item-extexemptid ).
                lo_old->lock_and_refresh( ).
                lo_old->set_approver( i_approver = sy-uname ).
                lo_old->unlock( ).
                CLEAR lo_old.

                " 예외를 던지지 않고 결과로 거부를 알린다. 반드시 읽는다.
                " E 오류 / A 중단 / X 종료. 경고(W)와 정보(I)는 실패가 아니다.
                DATA(lt_approved) = lo_controller->approve_exemptions_by_id(
                                      VALUE #( exemption_id = ls_item-extexemptid
                                               assessment   = ms_exemption-reasontext ) ).
                LOOP AT lt_approved INTO DATA(ls_approved) WHERE message_kind CA 'EAX'.
                  lv_error = |{ lv_error }{ ls_approved-message } |.
                ENDLOOP.
              ENDIF.
              IF lv_error IS INITIAL.
                <ls_res>-stdstatus = zif_atc_exemption=>stdstatus-approved.
              ENDIF.

            WHEN operation-reject.
              IF ls_item-stdstatus = zif_atc_exemption=>stdstatus-rejected
              OR ls_item-extexemptid IS INITIAL.
                CONTINUE.
              ENDIF.
              " 삭제가 아니라 표준의 반려 전이다. REJ 로 남아야 표준 쪽에서도 반려를
              " 알 수 있고 알림 유형 REJ 도 이 전이에 걸린다.
              lo_old = lo_controller->get_exemption( ls_item-extexemptid ).
              lo_old->lock_and_refresh( ).
              lo_old->reject( ).
              lo_old->unlock( ).
              CLEAR lo_old.
              <ls_res>-stdstatus = zif_atc_exemption=>stdstatus-rejected.

            WHEN operation-withdraw.
              IF ls_item-extexemptid IS INITIAL.
                CONTINUE.
              ENDIF.
              " 표준 앱의 Delete 와 같은 길이다. 행이 실제로 없어진다. 컨트롤러의
              " delete( ) 는 아카이브만 해서 철회한 건을 표준 앱에서 승인할 수 있었다.
              " 🔴 키 필드명 확인: exemption_id 가 아니면 이 줄만 바꾼다.
              MODIFY ENTITIES OF satc_ci_r_exemption
                ENTITY satc_ci_r_exemption
                  DELETE FROM VALUE #( ( %is_draft    = if_abap_behv=>mk-off
                                         exemption_id = ls_item-extexemptid ) )
                FAILED DATA(ls_del_failed)
                REPORTED DATA(ls_del_reported).
              IF ls_del_failed IS NOT INITIAL.
                lv_error = |삭제 실패|.
                LOOP AT ls_del_reported-satc_ci_r_exemption INTO DATA(ls_del_msg) WHERE %msg IS BOUND.
                  lv_error = |{ lv_error }: { ls_del_msg-%msg->if_message~get_text( ) }|.
                ENDLOOP.
              ELSE.
                " 별도 세션이라 여기서 커밋할 수 있다. 우리 BO 의 저장 시퀀스였다면 막혔다.
                COMMIT ENTITIES RESPONSE OF satc_ci_r_exemption
                  FAILED DATA(ls_commit_failed)
                  REPORTED DATA(ls_commit_reported).
                IF ls_commit_failed IS INITIAL.
                  CLEAR: <ls_res>-extexemptid, <ls_res>-stdstatus.
                ELSE.
                  lv_error = |삭제 실패|.
                  LOOP AT ls_commit_reported-satc_ci_r_exemption INTO DATA(ls_commit_msg) WHERE %msg IS BOUND.
                    lv_error = |{ lv_error }: { ls_commit_msg-%msg->if_message~get_text( ) }|.
                  ENDLOOP.
                ENDIF.
              ENDIF.

          ENDCASE.

        CATCH cx_root INTO DATA(lo_error).
          " 실패해도 잠금은 푼다. 열어 두면 다음 시도가 상태가 아니라 잠금 때문에 실패한다.
          lv_error = lo_error->get_text( ).
          TRY.
              IF lo_new IS BOUND.
                lo_new->unlock( ).
              ENDIF.
              IF lo_old IS BOUND.
                lo_old->unlock( ).
              ENDIF.
            CATCH cx_root ##NO_HANDLER.
          ENDTRY.
          CLEAR: lo_new, lo_old.
      ENDTRY.

      " 줄마다 확정한다. 표준은 한 건씩 바뀌므로 줄 단위로 맞춰 둬야 결과에 적은
      " 상태와 실제가 같다. 실패한 줄은 표준이 중간까지 바꾼 것을 버린다.
      IF lv_error IS INITIAL.
        COMMIT WORK.
        CONTINUE.
      ENDIF.

      ROLLBACK WORK.
      ms_result-success = abap_false.
      ms_result-message = |{ ms_result-message }{ lv_target }: { lv_error } |.

      " 철회는 남은 줄도 계속 지운다. 나머지는 첫 실패에서 멈춘다.
      IF mv_operation <> operation-withdraw.
        EXIT.
      ENDIF.

    ENDLOOP.

    " 상신 실패: 이번에 만든 표준 예외만 같은 클래스의 철회로 지워 상신 전으로 되돌린다.
    " 처음부터 ID 가 있던 줄(앞선 실패의 잔재)은 건드리지 않는다.
    IF mv_operation = operation-register AND ms_result-success = abap_false.
      DATA lt_undo TYPE zif_atc_exemption=>tt_item.
      LOOP AT ms_result-items INTO DATA(ls_created) WHERE extexemptid IS NOT INITIAL.
        IF NOT line_exists( mt_item[ itemuuid = ls_created-itemuuid extexemptid = ls_created-extexemptid ] ).
          DATA(ls_undo) = mt_item[ itemuuid = ls_created-itemuuid ].
          ls_undo-extexemptid = ls_created-extexemptid.
          APPEND ls_undo TO lt_undo.
        ENDIF.
      ENDLOOP.

      IF lt_undo IS NOT INITIAL.
        DATA(lo_undo) = NEW zcl_atc_exempt_sync( is_exemption = ms_exemption
                                                 it_item      = lt_undo
                                                 iv_operation = operation-withdraw ).
        lo_undo->if_abap_parallel~do( ).
        DATA(ls_undone) = lo_undo->get_result( ).
        LOOP AT ls_undone-items INTO DATA(ls_back).
          ms_result-items[ itemuuid = ls_back-itemuuid ]-extexemptid = ls_back-extexemptid.
          ms_result-items[ itemuuid = ls_back-itemuuid ]-stdstatus   = ls_back-stdstatus.
        ENDLOOP.
        IF ls_undone-success = abap_false.
          ms_result-message = |{ ms_result-message }/ 되돌리기 실패 - { ls_undone-message }|.
        ENDIF.
      ENDIF.
    ENDIF.

  ENDMETHOD.

ENDCLASS.
