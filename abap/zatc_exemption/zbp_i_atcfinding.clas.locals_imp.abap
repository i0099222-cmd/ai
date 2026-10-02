CLASS lhc_finding DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS requestexemption FOR MODIFY
      IMPORTING keys FOR ACTION finding~requestexemption RESULT result.

ENDCLASS.


CLASS lhc_finding IMPLEMENTATION.

  METHOD requestexemption.

    " ZI_AtcFinding 은 unmanaged 이고 read 를 구현하지 않았다. READ ENTITIES 는
    " 빈 결과를 돌려주므로 뷰에서 직접 읽는다. read 를 구현해도 그 안에서 하는
    " 일이 이 SELECT 하나라 메서드만 늘어난다.
    DATA lt_key TYPE STANDARD TABLE OF zi_atcfinding WITH EMPTY KEY.

    LOOP AT keys INTO DATA(ls_sel).
      APPEND VALUE #( resultid      = ls_sel-%tky-ResultId
                      itemid        = ls_sel-%tky-ItemId
                      checkrunindex = ls_sel-%tky-CheckRunIndex ) TO lt_key.
    ENDLOOP.

    IF lt_key IS INITIAL.
      RETURN.
    ENDIF.

    SELECT resultid, itemid, checkrunindex,
           checkvariant, devclass, objecttype, objectname,
           checkclass, checkcode
      FROM zi_atcfinding
      FOR ALL ENTRIES IN @lt_key
      WHERE resultid      = @lt_key-resultid
        AND itemid        = @lt_key-itemid
        AND checkrunindex = @lt_key-checkrunindex
      INTO TABLE @DATA(lt_finding).

    " 이 탭은 오브젝트 단위 신청만 한다. 패키지 단위는 패키지 탭(ZI_AtcFindingPkg)이다.
    " 오브젝트 + 체크 코드마다 한 건. 같은 위반을 여러 줄 골라도 신청서는 하나다.
    DATA lt_action TYPE TABLE FOR ACTION IMPORT zr_atcexemption\\exemption~createfromfinding.
    DATA lt_seen   TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.

    LOOP AT keys INTO DATA(ls_key).

      READ TABLE lt_finding INTO DATA(ls_finding)
        WITH KEY resultid      = ls_key-%tky-ResultId
                 itemid        = ls_key-%tky-ItemId
                 checkrunindex = ls_key-%tky-CheckRunIndex.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      DATA(lv_group) = |{ ls_finding-checkvariant }/{ ls_finding-devclass }|
                    && |/{ ls_finding-objecttype }/{ ls_finding-objectname }|
                    && |/{ ls_finding-checkclass }/{ ls_finding-checkcode }|.
      IF line_exists( lt_seen[ table_line = lv_group ] ).
        CONTINUE.
      ENDIF.
      INSERT lv_group INTO TABLE lt_seen.

      APPEND VALUE #(
        %cid   = |RE{ lines( lt_action ) + 1 }|
        %param = VALUE #( checkvariant = ls_finding-checkvariant
                          devclass     = ls_finding-devclass
                          objecttype   = ls_finding-objecttype
                          objectname   = ls_finding-objectname
                          checkclass   = ls_finding-checkclass
                          checkcode    = ls_finding-checkcode
                          scopetype    = zif_atc_exemption=>scope-obj
                          reasoncode   = ls_key-%param-reasoncode
                          reasontext   = ls_key-%param-reasontext
                          validto      = ls_key-%param-validto ) ) TO lt_action.

    ENDLOOP.

    " 🔴 초안으로 만들지 활성 인스턴스로 만들지는 %is_draft 가 정한다.
    "   여기서는 활성으로 만든다 - 초안으로 만들면 사용자가 신청서를 하나씩
    "   열어 저장해야 하고, 여러 건을 한 번에 만드는 의미가 없어진다.
    MODIFY ENTITIES OF zr_atcexemption
      ENTITY exemption
        EXECUTE createfromfinding FROM lt_action
      MAPPED DATA(lt_mapped)
      FAILED DATA(lt_failed)
      REPORTED DATA(lt_reported).

    " 생성 쪽에서 나온 메시지를 그대로 화면에 올린다. 몇 건 중 몇 건이
    " 실패했는지는 사용자가 알아야 한다.
    LOOP AT lt_reported-exemption INTO DATA(ls_rep) WHERE %msg IS BOUND.
      APPEND VALUE #( %tky = keys[ 1 ]-%tky %msg = ls_rep-%msg ) TO reported-finding.
    ENDLOOP.

    " 여기서 만든 것은 버퍼의 신청서이고, 검증은 저장 단계에서 돈다.
    " 그대로 성공을 알리면 저장에서 실패할 건에도 성공 메시지가 에러와 같이 뜬다.
    " 그래서 checkRequest 로 같은 검증을 지금 돌려 보고, 하나라도 걸리면 성공을
    " 알리지 않는다. 그 에러는 여기서 올리지 않는다 - 저장 단계의 검증이 같은
    " 에러를 다시 올리므로, 여기서도 올리면 두 번 뜬다.
    "
    " 판정은 FAILED 가 아니라 REPORTED 의 에러 메시지로 한다. determine action 은
    " 안에서 돈 validation 이 failed 를 채워도 그것을 호출한 쪽에 돌려주지 않는다
    " (확인함 - validateValidity 가 failed 를 채웠는데 여기서는 비어 있었다).
    DATA(lv_check_error) = abap_false.

    IF lt_mapped-exemption IS NOT INITIAL.
      MODIFY ENTITIES OF zr_atcexemption
        ENTITY exemption
          EXECUTE checkrequest FROM VALUE #( FOR ls_new IN lt_mapped-exemption
                                             ( %tky = ls_new-%tky ) )
        FAILED DATA(lt_check_failed)
        REPORTED DATA(lt_check_reported).

      lv_check_error = xsdbool( lt_check_failed-exemption IS NOT INITIAL ).
      LOOP AT lt_check_reported-exemption INTO DATA(ls_check) WHERE %msg IS BOUND.
        IF ls_check-%msg->m_severity = if_abap_behv_message=>severity-error.
          lv_check_error = abap_true.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " 신청서는 다른 앱에 생기고 finding 은 승인 전까지 바뀌지 않아서, 이 메시지가
    " 없으면 화면에서는 아무 일도 없었던 것처럼 보인다.
    IF lt_mapped-exemption IS NOT INITIAL
   AND lv_check_error = abap_false.
      APPEND VALUE #( %tky = keys[ 1 ]-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-success
                               text     = |{ lines( lt_mapped-exemption ) } exemption request(s) | &&
                                          |created. Submit them in My Exemption Requests.| ) )
             TO reported-finding.
    ENDIF.

    result = VALUE #( FOR ls_res IN keys ( %tky = ls_res-%tky ) ).

  ENDMETHOD.

ENDCLASS.
