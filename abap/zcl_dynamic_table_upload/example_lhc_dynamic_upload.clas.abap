"! 예시: CBO 등 임의의 대상 테이블에 대해 동적 업로드를 수행하는 RAP BO 액션 구현 예시.
"! 실제 프로젝트에서는 대상 BO(예: ZI_DynamicUpload)의 CDS behavior definition에 아래와 같이
"! factory/instance action을 정의하고, 이 handler에서 zcl_dynamic_table_upload를 호출한다.
"!
"!   action ( features : instance ) downloadTemplate parameter ZI_DynTemplateParam result [1] $self;
"!   action uploadData parameter ZI_DynUploadParam result [1] $self;
"!
"! 파라미터 구조체(ZI_DynTemplateParam: table_name / file / file_name,
"! ZI_DynUploadParam: table_name / file, 결과 파라미터: table_name / total_rows /
"! success_rows / error_rows)와 %param 매핑은 프로젝트 CDS 정의에 맞게 조정한다.
CLASS lhc_dynamicupload DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS downloadtemplate FOR MODIFY
      IMPORTING keys FOR ACTION dynamicupload~downloadtemplate RESULT result.

    METHODS uploaddata FOR MODIFY
      IMPORTING keys FOR ACTION dynamicupload~uploaddata RESULT result.

ENDCLASS.


CLASS lhc_dynamicupload IMPLEMENTATION.

  METHOD downloadtemplate.

    " 1) 대상 CBO 테이블 구조에 맞는 Excel 템플릿 생성
    DATA(lo_engine) = NEW zcl_dynamic_table_upload( ).

    LOOP AT keys INTO DATA(ls_key).

      TRY.
          DATA(lv_file) = lo_engine->zif_dynamic_table_upload~create_excel_template(
                             ls_key-%param-table_name ).

          APPEND VALUE #(
            %tky   = ls_key-%tky
            %param = VALUE #( table_name = ls_key-%param-table_name
                               file       = lv_file
                               file_name  = |{ ls_key-%param-table_name }_TEMPLATE.xls| ) )
            TO result.

        CATCH zcx_dynamic_table_upload INTO DATA(lx_error).

          APPEND VALUE #( %tky = ls_key-%tky ) TO failed-dynamicupload.

          APPEND VALUE #(
            %tky = ls_key-%tky
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-error
                     text     = lx_error->get_text( ) ) )
            TO reported-dynamicupload.

      ENDTRY.

    ENDLOOP.

  ENDMETHOD.


  METHOD uploaddata.

    " 2) 업로드 파일 -> JSON 변환 -> 대상 테이블로 마이그레이션
    DATA(lo_engine) = NEW zcl_dynamic_table_upload( ).

    LOOP AT keys INTO DATA(ls_key).

      TRY.
          " RAP save 시퀀스 안에서 호출되는 액션이므로 COMMIT/ROLLBACK WORK는 프레임워크에
          " 맡기고 여기서는 직접 커밋하지 않는다(iv_commit = abap_false).
          DATA(ls_result) = lo_engine->zif_dynamic_table_upload~upload_and_migrate(
                               iv_table_name = ls_key-%param-table_name
                               iv_file       = ls_key-%param-file
                               iv_commit     = abap_false ).

          APPEND VALUE #(
            %tky   = ls_key-%tky
            %param = VALUE #( table_name   = ls_key-%param-table_name
                               total_rows   = ls_result-total_rows
                               success_rows = ls_result-success_rows
                               error_rows   = ls_result-error_rows ) )
            TO result.

          LOOP AT ls_result-t_message INTO DATA(ls_msg).
            APPEND VALUE #(
              %tky = ls_key-%tky
              %msg = new_message_with_text(
                       severity = COND #( WHEN ls_msg-msgty = 'E'
                                           THEN if_abap_behv_message=>severity-error
                                           ELSE if_abap_behv_message=>severity-warning )
                       text     = |[{ ls_msg-row }:{ ls_msg-fieldname }] { ls_msg-message }| ) )
              TO reported-dynamicupload.
          ENDLOOP.

        CATCH zcx_dynamic_table_upload INTO DATA(lx_error).

          APPEND VALUE #( %tky = ls_key-%tky ) TO failed-dynamicupload.

          APPEND VALUE #(
            %tky = ls_key-%tky
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-error
                     text     = lx_error->get_text( ) ) )
            TO reported-dynamicupload.

      ENDTRY.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
