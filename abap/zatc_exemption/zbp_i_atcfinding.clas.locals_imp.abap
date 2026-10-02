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
    DATA lt_action TYPE zbp_i_atcfinding=>tt_create.
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

    zbp_i_atcfinding=>create_requests( EXPORTING it_action  = lt_action
                                       IMPORTING et_message = DATA(lt_message)
                                                 ev_created = DATA(lv_created) ).

    LOOP AT lt_message INTO DATA(lo_message).
      APPEND VALUE #( %tky = keys[ 1 ]-%tky %msg = lo_message ) TO reported-finding.
    ENDLOOP.

    " 신청서는 다른 앱에 생기고 finding 은 승인 전까지 바뀌지 않아서, 이 메시지가
    " 없으면 화면에서는 아무 일도 없었던 것처럼 보인다.
    IF lv_created > 0.
      APPEND VALUE #( %tky = keys[ 1 ]-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-success
                               text     = |{ lv_created } exemption request(s) | &&
                                          |created. Submit them in My Exemption Requests.| ) )
             TO reported-finding.
    ENDIF.

    " 선택한 행을 그대로 돌려준다. finding 은 승인 전까지 바뀌지 않는다.
    result = VALUE #( FOR ls_res IN keys ( %tky = ls_res-%tky ) ).

  ENDMETHOD.

ENDCLASS.
