"! 엑셀 마이그레이션을 RAP LUW 밖에서 실행하기 위한 CL_ABAP_PARALLEL 태스크.
"!
"! RAP은 액션 핸들러에서의 DB 변경과 COMMIT WORK를 금지한다. 이 태스크는
"! 별도 세션에서 돌아 자체 LUW를 가지므로 여기서의 커밋은 허용된다.
"!
"! 대가: 이 커밋은 RAP 트랜잭션과 무관하게 확정된다. 이후 RAP save가 실패하거나
"! 사용자가 취소해도 여기서 넣은 데이터는 롤백되지 않는다.
CLASS zcl_excel_migr_task DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_abap_parallel.
    INTERFACES if_serializable_object.

    METHODS constructor
      IMPORTING
        iv_tabname      TYPE tabname
        iv_file_content TYPE xstring.

    " 별도 세션이라 리턴값으로는 못 넘긴다. do( )가 채우고 호출부가 읽어간다.
    DATA ms_result     TYPE zcl_excel_table_migrator=>ty_result READ-ONLY.
    DATA mv_error_text TYPE string                              READ-ONLY.

  PRIVATE SECTION.

    DATA mv_tabname      TYPE tabname.
    DATA mv_file_content TYPE xstring.

ENDCLASS.


CLASS zcl_excel_migr_task IMPLEMENTATION.

  METHOD constructor.
    mv_tabname      = iv_tabname.
    mv_file_content = iv_file_content.
  ENDMETHOD.


  METHOD if_abap_parallel~do.

    TRY.

        ms_result = NEW zcl_excel_table_migrator( )->migrate(
          iv_tabname      = mv_tabname
          iv_file_content = mv_file_content ).

        IF ms_result-inserted > 0.
          COMMIT WORK AND WAIT.
        ELSE.
          ROLLBACK WORK.
        ENDIF.

      CATCH cx_root INTO DATA(lx_error).
        " 예외는 세션 경계를 넘지 못한다. 안 잡으면 호출부는 단서 없이 0만 받는다.
        ROLLBACK WORK.
        mv_error_text = lx_error->get_text( ).

    ENDTRY.

  ENDMETHOD.

ENDCLASS.
