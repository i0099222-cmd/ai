"! 예시: TADIR을 래핑한 기존 오브젝트 조회 RAP BO(draft 사용)에 동적 업로드를 붙이는 구현.
"! example_tadir_upload.bdef.asbdef 의 behavior definition과 짝을 이룬다.
"!
"! 역할 분담:
"!   - 이 핸들러  : 업무 정책 판단(TABL인가/CBO인가/draft인가) + 스테이징 엔터티 읽고 쓰기
"!   - 엔진 클래스 : 기술 판단(쓰기 가능한 DB 테이블인가) + 템플릿/JSON/마이그레이션
"!
"! 파일은 자식 엔터티(Staging)의 스트림 필드에 담긴다. 액션은 그 필드를 채우거나 읽을 뿐이고,
"! 실제 업/다운로드 UI는 Fiori Elements가 @UI.fileUpload / @Semantics.largeObject 로 그려준다.
CLASS lhc_tadirobject DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    "! TADIR-OBJECT 중 테이블만 업로드 대상이 된다.
    "! DDIC 데이터 엘리먼트(TROBJTYPE/SOBJ_NAME)는 ABAP Cloud에 릴리즈되어 있지 않을 수
    "! 있으므로 내장 타입만 쓴다. 엔터티 필드에서 넘어올 때 자동 변환된다.
    CONSTANTS mc_object_table TYPE string VALUE 'TABL'.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR tadirobject RESULT result.

    METHODS generatetemplate FOR MODIFY
      IMPORTING keys FOR ACTION tadirobject~generatetemplate RESULT result.

    METHODS uploaddata FOR MODIFY
      IMPORTING keys FOR ACTION tadirobject~uploaddata RESULT result.

    "! 업무 정책상 이 오브젝트가 업로드 대상인지 판정한다.
    METHODS is_upload_candidate
      IMPORTING
        iv_object    TYPE string
        iv_obj_name  TYPE string
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
    rv_ok = NEW zcl_dynamic_table_upload( )->is_uploadable( iv_obj_name ).

  ENDMETHOD.


  METHOD get_instance_features.

    READ ENTITIES OF zi_tadirobject IN LOCAL MODE
      ENTITY tadirobject
        FIELDS ( pgmid object objname )
        WITH CORRESPONDING #( keys )
      RESULT DATA(lt_tadir).

    result = VALUE #(
      FOR ls_tadir IN lt_tadir
      LET lv_candidate = is_upload_candidate( iv_object   = ls_tadir-object
                                              iv_obj_name = ls_tadir-objname )

          " 템플릿 생성은 EML로 RAP 관리 데이터만 쓰므로 draft 상태에서도 안전하다.
          lv_template  = COND #( WHEN lv_candidate = abap_true
                                 THEN if_abap_behv=>fc-o-enabled
                                 ELSE if_abap_behv=>fc-o-disabled )

          " 업로드는 대상 CBO 테이블에 직접 Open SQL MODIFY를 날린다. RAP 트랜잭션 버퍼를
          " 거치지 않으므로 draft에서 실행한 뒤 Discard해도 데이터가 되돌아가지 않는다.
          " => 활성(active) 인스턴스에서만 실행 가능하게 막는다.
          lv_upload    = COND #( WHEN lv_candidate = abap_true
                                  AND ls_tadir-%is_draft = if_abap_behv=>mk-off
                                 THEN if_abap_behv=>fc-o-enabled
                                 ELSE if_abap_behv=>fc-o-disabled )
      IN ( %tky                     = ls_tadir-%tky
           %action-generatetemplate = lv_template
           %action-uploaddata       = lv_upload ) ).

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

      DATA(ls_template) = lo_engine->create_excel_template( ls_tadir-objname ).

      IF ls_template-success = abap_false.

        APPEND VALUE #( %tky = ls_tadir-%tky ) TO failed-tadirobject.
        APPEND VALUE #(
          %tky = ls_tadir-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = ls_template-message ) )
          TO reported-tadirobject.
        CONTINUE.

      ENDIF.

      IF line_exists( lt_staging[ pgmid   = ls_tadir-pgmid
                                  object  = ls_tadir-object
                                  objname = ls_tadir-objname ] ).

        APPEND VALUE #( %tky                 = ls_tadir-%tky
                        templatefile         = ls_template-file
                        templatefilename     = ls_template-filename
                        templatefilemimetype = ls_template-mimetype )
               TO lt_update.

      ELSE.

        APPEND VALUE #(
          %tky    = ls_tadir-%tky
          %target = VALUE #( ( %cid                 = |TPL_{ sy-tabix }|
                               pgmid                = ls_tadir-pgmid
                               object               = ls_tadir-object
                               objname              = ls_tadir-objname
                               templatefile         = ls_template-file
                               templatefilename     = ls_template-filename
                               templatefilemimetype = ls_template-mimetype ) ) )
          TO lt_create.

      ENDIF.

      APPEND VALUE #( %tky = ls_tadir-%tky ) TO result.

      APPEND VALUE #(
        %tky = ls_tadir-%tky
        %msg = new_message_with_text(
                 severity = if_abap_behv_message=>severity-success
                 text     = |{ ls_template-filename } 생성 완료. 다운로드 링크에서 받으세요.| ) )
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

      " feature control로 이미 막았지만, 액션은 OData로 직접 호출될 수 있다.
      " draft에서 실행되면 Discard로 되돌릴 수 없는 DB 변경이 남으므로 여기서 다시 막는다.
      IF ls_tadir-%is_draft = if_abap_behv=>mk-on.

        APPEND VALUE #( %tky = ls_tadir-%tky ) TO failed-tadirobject.
        APPEND VALUE #(
          %tky = ls_tadir-%tky
          %msg = new_message_with_text(
                   severity = if_abap_behv_message=>severity-error
                   text     = '먼저 저장한 뒤 업로드를 실행하세요. '
                           && '편집 중 상태에서는 마이그레이션을 실행할 수 없습니다.' ) )
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

      " RAP save 시퀀스 안이므로 COMMIT/ROLLBACK은 프레임워크에 맡긴다.
      DATA(ls_result) = lo_engine->upload_and_migrate(
                          iv_table_name = ls_tadir-objname
                          iv_file       = ls_staging-uploadfile
                          iv_commit     = abap_false ).

      GET TIME STAMP FIELD DATA(lv_now).

      APPEND VALUE #( %tky            = ls_staging-%tky
                      lasttotalrows   = ls_result-total_rows
                      lastsuccessrows = ls_result-success_rows
                      lasterrorrows   = ls_result-error_rows
                      lastrunat       = lv_now )
             TO lt_update.

      IF ls_result-success = abap_true.
        APPEND VALUE #( %tky = ls_tadir-%tky ) TO result.
      ELSE.
        APPEND VALUE #( %tky = ls_tadir-%tky ) TO failed-tadirobject.
      ENDIF.

      APPEND VALUE #(
        %tky = ls_tadir-%tky
        %msg = new_message_with_text(
                 severity = COND #( WHEN ls_result-success = abap_true
                                    THEN if_abap_behv_message=>severity-success
                                    ELSE if_abap_behv_message=>severity-error )
                 text     = |{ ls_tadir-objname }: 총 { ls_result-total_rows }건 중 | &&
                            |성공 { ls_result-success_rows }건, 오류 { ls_result-error_rows }건| &&
                            COND #( WHEN ls_result-message IS NOT INITIAL
                                    THEN | / { ls_result-message }| ) ) )
        TO reported-tadirobject.

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
