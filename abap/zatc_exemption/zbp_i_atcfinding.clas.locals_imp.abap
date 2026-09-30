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

    DATA lt_action TYPE TABLE FOR ACTION IMPORT zr_atcexemption\\exemption~createfromfinding.

    " 같은 그룹은 신청서 하나로 묶는다.
    "   PCKG : 패키지 + 체크 클래스가 같으면 한 건. 패키지 신청은 규칙 범위가
    "          CHK 라 체크 코드를 가리지 않고 덮으므로, 코드가 달라도 신청서를
    "          더 만들 이유가 없다. 코드별로 만들면 같은 범위를 덮는 신청서가
    "          여러 장 생기고 중복 검증에 걸린다.
    "   그 외 : 오브젝트 + 체크 코드마다 한 건. 규칙 범위가 MSG 다.
    DATA lt_seen TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.

    LOOP AT keys INTO DATA(ls_key).

      READ TABLE lt_finding INTO DATA(ls_finding)
        WITH KEY resultid      = ls_key-%tky-ResultId
                 itemid        = ls_key-%tky-ItemId
                 checkrunindex = ls_key-%tky-CheckRunIndex.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      DATA(ls_param) = ls_key-%param.

      DATA(lv_group) = COND string(
        WHEN ls_param-scopetype = zif_atc_exemption=>scope-pckg
        THEN |{ ls_param-scopetype }/{ ls_finding-checkvariant }|
          && |/{ ls_finding-devclass }|
          && |/{ ls_finding-checkclass }|
        ELSE |{ ls_param-scopetype }/{ ls_finding-checkvariant }|
          && |/{ ls_finding-devclass }|
          && |/{ ls_finding-objecttype }/{ ls_finding-objectname }|
          && |/{ ls_finding-checkclass }/{ ls_finding-checkcode }| ).

      IF line_exists( lt_seen[ table_line = lv_group ] ).
        CONTINUE.
      ENDIF.
      INSERT lv_group INTO TABLE lt_seen.

      APPEND VALUE #(
        %cid  = |RE{ lines( lt_action ) + 1 }|
        %param = VALUE #( checkvariant = ls_finding-checkvariant
                          devclass     = ls_finding-devclass
                          objecttype   = ls_finding-objecttype
                          objectname   = ls_finding-objectname
                          checkclass   = ls_finding-checkclass
                          checkcode    = ls_finding-checkcode
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
      MAPPED DATA(lt_mapped)
      FAILED DATA(lt_failed)
      REPORTED DATA(lt_reported).

    " 생성 쪽에서 나온 메시지를 그대로 화면에 올린다. 몇 건 중 몇 건이
    " 실패했는지는 사용자가 알아야 한다.
    LOOP AT lt_reported-exemption INTO DATA(ls_rep).
      APPEND VALUE #( %tky = keys[ 1 ]-%tky
                      %msg = ls_rep-%msg ) TO reported-finding.
    ENDLOOP.

    " 성공도 알린다. 신청서는 다른 앱에 초안 상태로 생기고 finding 은 승인 전까지
    " 바뀌지 않아서, 이 메시지가 없으면 화면에서는 아무 일도 없었던 것처럼 보인다.
    " 다음에 할 일(상신)과 가는 길까지 같이 적는다.
    IF lt_mapped-exemption IS NOT INITIAL.
      APPEND VALUE #( %tky = keys[ 1 ]-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-success
                               text     = |{ lines( lt_mapped-exemption ) } exemption request(s) | &&
                                          |created. Submit them in My Exemption Requests.| ) )
             TO reported-finding.
    ENDIF.

    " 선택한 행을 그대로 돌려준다. finding 은 승인 전까지 바뀌지 않는다.
    result = VALUE #( FOR ls_res IN keys ( %tky = ls_res-%tky ) ).

  ENDMETHOD.

ENDCLASS.
