CLASS lhc_findingpackage DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS requestexemption FOR MODIFY
      IMPORTING keys FOR ACTION findingpackage~requestexemption RESULT result.

ENDCLASS.


CLASS lhc_findingpackage IMPLEMENTATION.

  METHOD requestexemption.

    DATA lt_action TYPE zbp_i_atcfinding=>tt_create.

    LOOP AT keys INTO DATA(ls_key).

      " 표준 create_exemption 은 출발점 오브젝트를 받는다. 패키지의 위반 오브젝트
      " 하나를 넣는다 - 어느 것이든 결과는 같다. 패키지 예외는 i_package_name 과
      " 체크 전체(CHK)로 판정되고, 증빙에는 패키지의 위반 전체가 붙는다.
      SELECT SINGLE objecttype, objectname, checkcode
        FROM zi_atcfinding
        WHERE checkvariant = @ls_key-CheckVariant
          AND devclass     = @ls_key-Devclass
          AND checkclass   = @ls_key-CheckClass
        INTO @DATA(ls_sample).
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      APPEND VALUE #(
        %cid   = |RP{ lines( lt_action ) + 1 }|
        %param = VALUE #( checkvariant = ls_key-CheckVariant
                          devclass     = ls_key-Devclass
                          objecttype   = ls_sample-objecttype
                          objectname   = ls_sample-objectname
                          checkclass   = ls_key-CheckClass
                          checkcode    = ls_sample-checkcode
                          scopetype    = zif_atc_exemption=>scope-pckg
                          reasoncode   = ls_key-%param-reasoncode
                          reasontext   = ls_key-%param-reasontext
                          validto      = ls_key-%param-validto ) ) TO lt_action.

    ENDLOOP.

    zbp_i_atcfinding=>create_requests( EXPORTING it_action  = lt_action
                                       IMPORTING et_message = DATA(lt_message)
                                                 ev_created = DATA(lv_created) ).

    LOOP AT lt_message INTO DATA(lo_message).
      APPEND VALUE #( %tky = keys[ 1 ]-%tky %msg = lo_message ) TO reported-findingpackage.
    ENDLOOP.

    IF lv_created > 0.
      APPEND VALUE #( %tky = keys[ 1 ]-%tky
                      %msg = new_message_with_text(
                               severity = if_abap_behv_message=>severity-success
                               text     = |{ lv_created } package exemption request(s) | &&
                                          |created. Submit them in My Exemption Requests.| ) )
             TO reported-findingpackage.
    ENDIF.

    result = VALUE #( FOR ls_res IN keys ( %tky = ls_res-%tky ) ).

  ENDMETHOD.

ENDCLASS.
