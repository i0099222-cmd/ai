"! Value Help 테스트 · ADT 에서 F9 (Run As → ABAP Application (Console))
"!
"! 지원하는 파라미터 전부 + 없는 파라미터(ZZZ) 하나를 읽어서 건수와 앞 10건을 보여준다.
"! ZZZ 는 에러 메시지가 나와야 정상.
CLASS zcl_cmup_test_vh DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.


CLASS zcl_cmup_test_vh IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.
    DATA(lt_param_id) = VALUE string_table( ( `BUK` ) ( `CAC` ) ( `EKO` ) ( `VKO` ) ( `WRK` ) ( `ZZZ` ) ).

    LOOP AT lt_param_id INTO DATA(lv_param_id).
      TRY.
          DATA(lt_value) = zcl_cmup_value_help=>read_source( CONV #( lv_param_id ) ).
          out->write( |===== { lv_param_id } : { lines( lt_value ) }건 (앞 10건) =====| ).
          out->write( VALUE zcl_cmup_value_help=>tt_value( FOR ls_value IN lt_value TO 10 ( ls_value ) ) ).
        CATCH zcx_cmup_query INTO DATA(lx_error).
          out->write( |===== { lv_param_id } : 에러 - { lx_error->get_text( ) }| ).
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
