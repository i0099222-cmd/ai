"! 예시: TADIR을 래핑한 기존 오브젝트 조회 RAP BO에 동적 업로드 액션을 붙이는 구현 예시.
"! example_tadir_upload.bdef.asbdef 의 behavior definition과 짝을 이룬다.
"!
"! 이 핸들러가 책임지는 것은 "업무 정책" 판단이다:
"!   - 이 행이 업로드 대상이 될 수 있는 오브젝트인가 (TABL 인가, CBO 네임스페이스인가)
"!   - 이 사용자가 이 테이블에 쓸 권한이 있는가
"! "기술적으로 쓰기 가능한 DB 테이블인가"는 엔진(zif_dynamic_table_upload~is_uploadable)이 판단한다.
CLASS lhc_tadirobject DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    "! TADIR-OBJECT 중 테이블만 업로드 대상이 된다.
    CONSTANTS mc_object_table TYPE trobjtype VALUE 'TABL'.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR tadirobject RESULT result.

    METHODS downloadtemplate FOR MODIFY
      IMPORTING keys FOR ACTION tadirobject~downloadtemplate RESULT result.

    METHODS uploaddata FOR MODIFY
      IMPORTING keys FOR ACTION tadirobject~uploaddata RESULT result.

    "! 업무 정책상 이 오브젝트가 업로드 대상인지 판정한다.
    METHODS is_upload_candidate
      IMPORTING
        iv_object    TYPE trobjtype
        iv_obj_name  TYPE sobj_name
      RETURNING
        VALUE(rv_ok) TYPE abap_bool.

ENDCLASS.


CLASS lhc_tadirobject IMPLEMENTATION.

  METHOD is_upload_candidate.

    " 1) TADIR 오브젝트 타입이 테이블이어야 한다.
    "    (TADIR 대부분은 PROG/CLAS/DDLS/FUGR 등이라 이 체크가 제일 많이 걸러낸다)
    IF iv_object <> mc_object_table.
      RETURN.
    ENDIF.

    " 2) CBO만 허용: 고객 네임스페이스(Z*/Y*/ /ns/ *)만 통과시킨다.
    "    SAP 표준 테이블에 임의로 업로드하는 사고를 막는 핵심 방어선이다.
    IF NOT ( iv_obj_name CP 'Z*' OR iv_obj_name CP 'Y*' OR iv_obj_name CP '/*/*' ).
      RETURN.
    ENDIF.

    " 3) 기술 판정(구조체 INTTAB / 뷰 / 오타 제거)은 엔진에 위임한다.
    DATA(lo_engine) = NEW zcl_dynamic_table_upload( ).
    rv_ok = lo_engine->zif_dynamic_table_upload~is_uploadable( CONV #( iv_obj_name ) ).

  ENDMETHOD.


  METHOD get_instance_features.

    READ ENTITIES OF zi_tadirobject IN LOCAL MODE
      ENTITY tadirobject
        FIELDS ( pgmid object objname )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_tadir).

    result = VALUE #(
      FOR ls_tadir IN lt_tadir
      LET lv_enabled = COND #(
            WHEN is_upload_candidate( iv_object   = ls_tadir-object
                                       iv_obj_name = ls_tadir-objname ) = abap_true
            THEN if_abap_behv=>fc-o-enabled
            ELSE if_abap_behv=>fc-o-disabled )
      IN ( %tky                      = ls_tadir-%tky
           %action-downloadtemplate  = lv_enabled
           %action-uploaddata        = lv_enabled ) ).

  ENDMETHOD.


  METHOD downloadtemplate.

    READ ENTITIES OF zi_tadirobject IN LOCAL MODE
      ENTITY tadirobject
        FIELDS ( pgmid object objname )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_tadir).

    LOOP AT lt_tadir INTO DATA(ls_tadir).

      " features로 이미 막았지만, 액션은 OData로 직접 호출될 수도 있으므로 다시 검사한다.
      IF is_upload_candidate( iv_object   = ls_tadir-object
                               iv_obj_name = ls_tadir-objname ) = abap_false.

        APPEND VALUE #( %tky = ls_tadir-%tky ) TO failed-tadirobject.
        APPEND VALUE #(
          %tky = ls_tadir-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |{ ls_tadir-objname }은(는) 업로드 가능한 CBO 테이블이 아닙니다.| ) )
          TO reported-tadirobject.
        CONTINUE.

      ENDIF.

      " 실제 파일 스트리밍은 HTTP 서비스가 담당하고, 여기서는 그 URL만 돌려준다.
      " (액션 결과의 xstring은 Fiori Elements가 브라우저 다운로드로 처리해주지 않는다)
      APPEND VALUE #(
        %tky   = ls_tadir-%tky
        %param = VALUE #( pgmid       = ls_tadir-pgmid
                          object      = ls_tadir-object
                          objname     = ls_tadir-objname
                          templateurl = |/sap/bc/http/sap/zdyn_upload_template?table={ ls_tadir-objname }| ) )
        TO result.

    ENDLOOP.

  ENDMETHOD.


  METHOD uploaddata.

    " 파일은 @UI.fileUpload 스트림 필드(UploadFile)로 이미 스테이징 테이블에 올라와 있다는 전제.
    READ ENTITIES OF zi_tadirobject IN LOCAL MODE
      ENTITY tadirobject
        FIELDS ( pgmid object objname uploadfile )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_tadir).

    DATA(lo_engine) = NEW zcl_dynamic_table_upload( ).

    LOOP AT lt_tadir INTO DATA(ls_tadir).

      IF is_upload_candidate( iv_object   = ls_tadir-object
                               iv_obj_name = ls_tadir-objname ) = abap_false.

        APPEND VALUE #( %tky = ls_tadir-%tky ) TO failed-tadirobject.
        APPEND VALUE #(
          %tky = ls_tadir-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = |{ ls_tadir-objname }은(는) 업로드 가능한 CBO 테이블이 아닙니다.| ) )
          TO reported-tadirobject.
        CONTINUE.

      ENDIF.

      IF ls_tadir-uploadfile IS INITIAL.

        APPEND VALUE #( %tky = ls_tadir-%tky ) TO failed-tadirobject.
        APPEND VALUE #(
          %tky = ls_tadir-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = '업로드할 파일이 없습니다. 먼저 파일을 첨부하세요.' ) )
          TO reported-tadirobject.
        CONTINUE.

      ENDIF.

      TRY.
          " RAP save 시퀀스 안이므로 COMMIT/ROLLBACK은 프레임워크에 맡긴다.
          DATA(ls_result) = lo_engine->zif_dynamic_table_upload~upload_and_migrate(
                               iv_table_name = CONV #( ls_tadir-objname )
                               iv_file       = ls_tadir-uploadfile
                               iv_commit     = abap_false ).

          APPEND VALUE #(
            %tky   = ls_tadir-%tky
            %param = VALUE #( pgmid        = ls_tadir-pgmid
                              object       = ls_tadir-object
                              objname      = ls_tadir-objname
                              total_rows   = ls_result-total_rows
                              success_rows = ls_result-success_rows
                              error_rows   = ls_result-error_rows ) )
            TO result.

          APPEND VALUE #(
            %tky = ls_tadir-%tky
            %msg = new_message_with_text(
                     severity = COND #( WHEN ls_result-error_rows > 0
                                         THEN if_abap_behv_message=>severity-error
                                         ELSE if_abap_behv_message=>severity-success )
                     text     = |{ ls_tadir-objname }: 총 { ls_result-total_rows }건 중 | &&
                                |성공 { ls_result-success_rows }건, 오류 { ls_result-error_rows }건| ) )
            TO reported-tadirobject.

          LOOP AT ls_result-t_message INTO DATA(ls_msg).
            APPEND VALUE #(
              %tky = ls_tadir-%tky
              %msg = new_message_with_text(
                       severity = if_abap_behv_message=>severity-error
                       text     = ls_msg-message ) )
              TO reported-tadirobject.
          ENDLOOP.

        CATCH zcx_dynamic_table_upload INTO DATA(lx_error).

          APPEND VALUE #( %tky = ls_tadir-%tky ) TO failed-tadirobject.
          APPEND VALUE #(
            %tky = ls_tadir-%tky
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-error
                     text     = lx_error->get_text( ) ) )
            TO reported-tadirobject.

      ENDTRY.

    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
