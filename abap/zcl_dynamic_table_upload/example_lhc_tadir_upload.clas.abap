"! 예시: TADIR을 래핑한 기존 오브젝트 조회 RAP BO에 동적 업로드를 붙이는 구현 예시.
"! example_tadir_upload.bdef.asbdef 의 behavior definition과 짝을 이룬다.
"!
"! 역할 분담:
"!   - 이 핸들러      : 업무 정책 판단(TABL인가/CBO인가) + 스테이징 엔터티 읽고 쓰기
"!   - 엔진 클래스     : 기술 판단(쓰기 가능한 DB 테이블인가) + 템플릿/JSON/마이그레이션
"!
"! 파일은 자식 엔터티(Staging)의 스트림 필드에 담긴다. 액션은 그 필드를 채우거나 읽을 뿐이고,
"! 실제 업/다운로드 UI는 Fiori Elements가 @UI.fileUpload / @Semantics.largeObject 로 그려준다.
CLASS lhc_tadirobject DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    "! TADIR-OBJECT 중 테이블만 업로드 대상이 된다.
    CONSTANTS mc_object_table TYPE trobjtype VALUE 'TABL'.
    CONSTANTS mc_mime_xls     TYPE string    VALUE 'application/vnd.ms-excel'.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR tadirobject RESULT result.

    METHODS generatetemplate FOR MODIFY
      IMPORTING keys FOR ACTION tadirobject~generatetemplate RESULT result.

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

    " 2) CBO만 허용: 고객 네임스페이스(Z*/Y*//ns/*)만 통과시킨다.
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
      IN ( %tky                     = ls_tadir-%tky
           %action-generatetemplate = lv_enabled
           %action-uploaddata       = lv_enabled ) ).

  ENDMETHOD.


  METHOD generatetemplate.

    READ ENTITIES OF zi_tadirobject IN LOCAL MODE
      ENTITY tadirobject
        FIELDS ( pgmid object objname )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_tadir).

    " 이미 스테이징 행이 있는지 확인해서 CREATE / UPDATE를 가른다.
    READ ENTITIES OF zi_tadirobject IN LOCAL MODE
      ENTITY tadirobject BY \_staging
        FIELDS ( pgmid object objname )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_staging).

    DATA lt_create TYPE TABLE FOR CREATE zi_tadirobject\_staging.
    DATA lt_update TYPE TABLE FOR UPDATE zi_dynuploadstaging.

    DATA(lo_engine) = NEW zcl_dynamic_table_upload( ).

    LOOP AT lt_tadir INTO DATA(ls_tadir).

      " features로 이미 막았지만 액션은 OData로 직접 호출될 수 있으므로 다시 검사한다.
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

      TRY.
          DATA(lv_file) = lo_engine->zif_dynamic_table_upload~create_excel_template(
                             CONV #( ls_tadir-objname ) ).
        CATCH zcx_dynamic_table_upload INTO DATA(lx_error).

          APPEND VALUE #( %tky = ls_tadir-%tky ) TO failed-tadirobject.
          APPEND VALUE #(
            %tky = ls_tadir-%tky
            %msg = new_message_with_text(
                     severity = if_abap_behv_message=>severity-error
                     text     = lx_error->get_text( ) ) )
            TO reported-tadirobject.
          CONTINUE.

      ENDTRY.

      DATA(lv_filename) = |{ ls_tadir-objname }_TEMPLATE.xls|.

      IF line_exists( lt_staging[ pgmid   = ls_tadir-pgmid
                                  object  = ls_tadir-object
                                  objname = ls_tadir-objname ] ).

        APPEND VALUE #( %tky                 = ls_tadir-%tky
                        templatefile         = lv_file
                        templatefilename     = lv_filename
                        templatefilemimetype = mc_mime_xls )
               TO lt_update.

      ELSE.

        APPEND VALUE #(
          %tky    = ls_tadir-%tky
          %target = VALUE #( ( %cid                 = |TPL_{ sy-tabix }|
                               pgmid                = ls_tadir-pgmid
                               object               = ls_tadir-object
                               objname              = ls_tadir-objname
                               templatefile         = lv_file
                               templatefilename     = lv_filename
                               templatefilemimetype = mc_mime_xls ) ) )
          TO lt_create.

      ENDIF.

      APPEND VALUE #( %tky = ls_tadir-%tky ) TO result.

      APPEND VALUE #(
        %tky = ls_tadir-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = |{ lv_filename } 템플릿이 생성되었습니다. 다운로드 링크에서 받으세요.| ) )
        TO reported-tadirobject.

    ENDLOOP.

    " 생성한 템플릿을 스테이징 엔터티에 반영한다.
    " (RAP save 시퀀스가 알아서 커밋하므로 여기서 COMMIT WORK 하지 않는다)
    MODIFY ENTITIES OF zi_tadirobject IN LOCAL MODE
      ENTITY tadirobject
        CREATE BY \_staging
          FIELDS ( pgmid object objname templatefile templatefilename templatefilemimetype )
          WITH lt_create
      ENTITY staging
        UPDATE
          FIELDS ( templatefile templatefilename templatefilemimetype )
          WITH lt_update
      REPORTED DATA(ls_modify_reported).

    reported = CORRESPONDING #( DEEP ls_modify_reported ).

  ENDMETHOD.


  METHOD uploaddata.

    READ ENTITIES OF zi_tadirobject IN LOCAL MODE
      ENTITY tadirobject
        FIELDS ( pgmid object objname )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_tadir).

    " 업로드 파일은 자식 엔터티의 스트림 필드에 이미 올라와 있다.
    READ ENTITIES OF zi_tadirobject IN LOCAL MODE
      ENTITY tadirobject BY \_staging
        FIELDS ( pgmid object objname uploadfile )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_staging).

    DATA lt_update TYPE TABLE FOR UPDATE zi_dynuploadstaging.

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

      DATA(ls_staging) = VALUE #( lt_staging[ pgmid   = ls_tadir-pgmid
                                              object  = ls_tadir-object
                                              objname = ls_tadir-objname ] OPTIONAL ).

      IF ls_staging-uploadfile IS INITIAL.

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
                               iv_file       = ls_staging-uploadfile
                               iv_commit     = abap_false ).

          GET TIME STAMP FIELD DATA(lv_now).

          APPEND VALUE #( %tky            = ls_staging-%tky
                          lasttotalrows   = ls_result-total_rows
                          lastsuccessrows = ls_result-success_rows
                          lasterrorrows   = ls_result-error_rows
                          lastrunat       = lv_now )
                 TO lt_update.

          APPEND VALUE #( %tky = ls_tadir-%tky ) TO result.

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

    " 실행 결과 요약을 스테이징에 남긴다.
    MODIFY ENTITIES OF zi_tadirobject IN LOCAL MODE
      ENTITY staging
        UPDATE
          FIELDS ( lasttotalrows lastsuccessrows lasterrorrows lastrunat )
          WITH lt_update
      REPORTED DATA(ls_modify_reported).

    reported = CORRESPONDING #( DEEP ls_modify_reported ).

  ENDMETHOD.

ENDCLASS.
