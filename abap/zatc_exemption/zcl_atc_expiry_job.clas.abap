"! 예외 만료 처리 배치.
"!
"! 유효기간이 조용히 지나면 어느 날 갑자기 TR 릴리즈가 막히고, 개발자는 이유를
"! 모른 채 헤맨다. 그래서 만료 전환과 사전 알림을 이 배치가 담당한다.
"!
"! TODO 표준 예외의 set_notification_type( ) 이 무엇을 알려주는지 확인할 것.
"!   표준 알림이 만료 예고까지 해 준다면 이 배치의 알림 부분은 중복이고,
"!   상태 전환만 남기면 된다.
"!
"! TODO 스케줄링 연결. 일 1회 실행.
"!   시스템의 Application Job 인터페이스(IF_APJ_DT_EXEC_OBJECT /
"!   IF_APJ_RT_EXEC_OBJECT)를 이 클래스에 구현하고 run( ) 을 호출하거나,
"!   클래식이면 리포트에서 run( ) 을 호출해 SM36 으로 건다.
"!   릴리즈별로 인터페이스 시그니처가 다르므로 시스템에서 확인 후 붙일 것.
CLASS zcl_atc_expiry_job DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! 만료 안내를 보낼 시점 (일 단위)
    CONSTANTS c_notify_days TYPE i VALUE 30.

    TYPES:
      BEGIN OF ty_result,
        expired  TYPE i,
        expiring TYPE i,
      END OF ty_result.

    "! 배치 진입점
    METHODS run
      RETURNING VALUE(rs_result) TYPE ty_result.

    "! 유효기간이 지난 승인 건을 만료 상태로 바꾼다.
    METHODS expire_overdue
      RETURNING VALUE(rv_count) TYPE i.

    "! 만료 임박 건 목록. 알림 발송의 입력이 된다.
    METHODS get_expiring_soon
      IMPORTING iv_days          TYPE i DEFAULT c_notify_days
      RETURNING VALUE(rt_exempt) TYPE zif_atc_exemption=>tt_exempt.

ENDCLASS.


CLASS zcl_atc_expiry_job IMPLEMENTATION.

  METHOD run.

    rs_result-expired = expire_overdue( ).

    DATA(lt_soon) = get_expiring_soon( ).
    rs_result-expiring = lines( lt_soon ).

    " TODO 알림 채널 확정 후 연결 (메일 / 런치패드 알림 / 사내 메신저).
    "   채널은 조직 결정 사항이라 임의로 고르지 않았다.
    "   보낼 내용: 신청번호, 적용범위, 대상, 만료일, 연장 신청 링크
    "   받는 사람: 신청자 + 승인자

  ENDMETHOD.


  METHOD expire_overdue.

    " 면제 판정 자체는 이 배치가 없어도 풀린다. ZI_AtcActiveExemption 이
    " 유효기간으로 거르고, 표준 예외에도 create 시 같은 validto 를 넘겨 두었다.
    " 이 배치가 하는 일은 셋이다.
    "   - 대장의 상태 값을 실제와 맞춘다
    "   - 표준 예외를 명시적으로 무효화한다. 유효기간에만 기대지 않는 이유는,
    "     set_validity_date 가 반영되지 않았을 때 두 저장소가 조용히 어긋나기
    "     때문이다. 이 앱의 존재 이유가 그 어긋남을 없애는 것이다
    "   - 알림 대상을 만든다
    SELECT exemptuuid, exemptstat, extexemptid
      FROM ztatcexempt
      WHERE exemptstat = @zif_atc_exemption=>status-approved
        AND validto    < @sy-datum
      INTO TABLE @DATA(lt_overdue).

    IF lt_overdue IS INITIAL.
      RETURN.
    ENDIF.

    GET TIME STAMP FIELD DATA(lv_now).

    DATA lt_log TYPE STANDARD TABLE OF ztatcexemptlog WITH EMPTY KEY.

    DATA(lo_sync) = NEW zcl_atc_exempt_sync( ).

    LOOP AT lt_overdue INTO DATA(ls_overdue).

      DATA(lv_note) = |유효기간 경과로 자동 만료|.

      " 표준 예외도 함께 닫는다. 배치는 RAP 의 interaction phase 가 아니므로
      " 여기서 외부 호출을 해도 된다 (saver 를 거치지 않는 경로다).
      IF ls_overdue-extexemptid IS NOT INITIAL.
        DATA(ls_revoked) = lo_sync->revoke_exemption(
                             iv_extexemptid = ls_overdue-extexemptid
                             iv_reason      = lv_note ).
        lv_note = |{ lv_note } / { ls_revoked-message }|.
      ENDIF.

      UPDATE ztatcexempt
        SET exemptstat    = @zif_atc_exemption=>status-expired,
            lastchangedat = @lv_now,
            loclastchgat  = @lv_now
        WHERE exemptuuid = @ls_overdue-exemptuuid.

      " 순번은 기존 이력 다음이다. 0 으로 고정하면 이력 탭 정렬이 무너진다.
      SELECT MAX( seqnr ) FROM ztatcexemptlog
        WHERE exemptuuid = @ls_overdue-exemptuuid
        INTO @DATA(lv_max).

      " 이력을 남겨야 "왜 갑자기 면제가 풀렸는지" 를 나중에 추적할 수 있다.
      APPEND VALUE #(
        loguuid    = cl_system_uuid=>create_uuid_x16_static( )
        exemptuuid = ls_overdue-exemptuuid
        seqnr      = lv_max + 1
        actioncode = zif_atc_exemption=>logaction-expire
        fromstat   = ls_overdue-exemptstat
        tostat     = zif_atc_exemption=>status-expired
        commenttxt = lv_note
        actionby   = sy-uname
        actionat   = lv_now ) TO lt_log.

    ENDLOOP.

    INSERT ztatcexemptlog FROM TABLE @lt_log.

    rv_count = lines( lt_overdue ).

    COMMIT WORK.

  ENDMETHOD.


  METHOD get_expiring_soon.

    DATA(lv_limit) = CONV d( sy-datum + iv_days ).

    SELECT *
      FROM ztatcexempt
      WHERE exemptstat = @zif_atc_exemption=>status-approved
        AND validto   >= @sy-datum
        AND validto   <= @lv_limit
      INTO TABLE @rt_exempt.

  ENDMETHOD.

ENDCLASS.
