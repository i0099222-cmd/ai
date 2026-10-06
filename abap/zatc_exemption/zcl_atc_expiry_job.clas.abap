"! 예외 만료 처리 배치. 일 1회 run( ) 을 스케줄한다.
"!
"! 유효기간이 조용히 지나면 어느 날 갑자기 TR 릴리즈가 막히고 개발자는 이유를 모른다.
"! 그래서 만료 전환과 표준 예외 정리, 만료 임박 건수 집계를 여기서 한다.
"!
"! TODO 스케줄링 연결. Application Job(IF_APJ_DT_EXEC_OBJECT / IF_APJ_RT_EXEC_OBJECT)을
"!   붙이거나 클래식 리포트에서 run( ) 을 불러 SM36 으로 건다.
"! TODO 만료 임박 알림 채널(메일 / 런치패드 알림)은 조직 결정 후 연결한다.
CLASS zcl_atc_expiry_job DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! 만료 안내 기준 (일)
    CONSTANTS c_notify_days TYPE i VALUE 30.

    TYPES:
      BEGIN OF ty_result,
        expired  TYPE i,
        expiring TYPE i,
      END OF ty_result.

    METHODS run
      RETURNING VALUE(rs_result) TYPE ty_result.

ENDCLASS.


CLASS zcl_atc_expiry_job IMPLEMENTATION.

  METHOD run.

    " 면제 판정 자체는 이 배치가 없어도 풀린다(ZI_AtcActiveExemption 이 유효기간으로
    " 거르고, 표준 예외에도 같은 validto 를 넘겼다). 표준 예외를 명시적으로 지우는
    " 이유는 set_validity_date 가 반영되지 않았을 때 두 저장소가 조용히 어긋나기 때문이다.
    SELECT * FROM ztatcexempt
      WHERE exemptstat = @zif_atc_exemption=>status-approved
        AND validto    < @sy-datum
      INTO TABLE @DATA(lt_overdue).

    GET TIME STAMP FIELD DATA(lv_now).

    LOOP AT lt_overdue INTO DATA(ls_overdue).

      SELECT * FROM ztatcexempti
        WHERE exemptuuid = @ls_overdue-exemptuuid
        INTO TABLE @DATA(lt_item).

      " 배치는 RAP 의 interaction phase 가 아니라서 표준 반영을 직접 돌려도 된다.
      " 상신 철회와 같은 경로로 지운다. 못 지운 줄은 ID 가 남고 이력에 사유가 적힌다.
      DATA(lo_sync) = NEW zcl_atc_exempt_sync( is_exemption = ls_overdue
                                               it_item      = lt_item
                                               iv_operation = zcl_atc_exempt_sync=>operation-withdraw ).
      lo_sync->if_abap_parallel~do( ).
      DATA(ls_sync) = lo_sync->get_result( ).

      LOOP AT ls_sync-items INTO DATA(ls_res).
        UPDATE ztatcexempti
          SET extexemptid = @ls_res-extexemptid,
              stdstatus   = @ls_res-stdstatus
          WHERE itemuuid = @ls_res-itemuuid.
      ENDLOOP.

      UPDATE ztatcexempt
        SET exemptstat   = @zif_atc_exemption=>status-expired,
            changedat    = @lv_now,
            loclastchgat = @lv_now
        WHERE exemptuuid = @ls_overdue-exemptuuid.

      " 이력이 있어야 "왜 갑자기 면제가 풀렸는지" 를 나중에 추적할 수 있다.
      SELECT MAX( seqnr ) FROM ztatcexemptlog
        WHERE exemptuuid = @ls_overdue-exemptuuid
        INTO @DATA(lv_max).

      INSERT ztatcexemptlog FROM @( VALUE #(
        loguuid    = cl_system_uuid=>create_uuid_x16_static( )
        exemptuuid = ls_overdue-exemptuuid
        seqnr      = lv_max + 1
        actioncode = zif_atc_exemption=>logaction-expire
        fromstat   = ls_overdue-exemptstat
        tostat     = zif_atc_exemption=>status-expired
        commenttxt = |유효기간 경과로 자동 만료 { ls_sync-message }|
        actionby   = sy-uname
        actionat   = lv_now ) ).

      COMMIT WORK.

    ENDLOOP.

    rs_result-expired = lines( lt_overdue ).

    " 만료 임박 건수. 알림 채널이 정해지면 이 대상에게 보낸다(신청자 + 승인자).
    DATA(lv_limit) = CONV d( sy-datum + c_notify_days ).
    SELECT COUNT( * ) FROM ztatcexempt
      WHERE exemptstat = @zif_atc_exemption=>status-approved
        AND validto   >= @sy-datum
        AND validto   <= @lv_limit
      INTO @rs_result-expiring.

  ENDMETHOD.

ENDCLASS.
