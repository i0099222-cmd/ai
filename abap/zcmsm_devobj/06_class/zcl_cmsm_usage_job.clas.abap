"! CDS 사용처 인덱스 배치 잡 — ztcmsm00250 을 통째로 다시 만든다
"!
"! 시스템의 Z CDS(DDLS) 를 전부 XCO 로 읽어서, 각 CDS 가 데이터 소스(select from …)·연관(association) 대상으로
"!   쓰는 오브젝트를 한 줄씩 쌓는다. 매핑 상세 '사용처 (Z CDS)' 는 이 테이블만 읽는다 (ZI_CMSM_CdsUsage).
"! 실행: Application Job (잡 카탈로그 ZCMSM_CDS_USAGE → 템플릿 → Application Jobs 앱에서 매일 반복)
"!       F9(콘솔)로도 돌릴 수 있지만 Z CDS 가 많으면 대화 시간 제한에 걸릴 수 있다 → 처음 채울 때도 잡 '즉시 실행'
"! 못 읽는 것: join 대상, view entity 가 아닌 CDS(DDIC 기반 define view, custom entity 등), 컴포지션 대상
CLASS zcl_cmsm_usage_job DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_apj_dt_exec_object.
    INTERFACES if_apj_rt_exec_object.
    INTERFACES if_oo_adt_classrun.

ENDCLASS.


CLASS zcl_cmsm_usage_job IMPLEMENTATION.

  METHOD if_apj_dt_exec_object~get_parameters.
    " 파라미터 없음
    CLEAR: et_parameter_def, et_parameter_val.
  ENDMETHOD.


  METHOD if_oo_adt_classrun~main.
    " F9 로 바로 돌릴 때 (시험용)
    TRY.
        if_apj_rt_exec_object~execute( VALUE #( ) ).
        SELECT COUNT( * ) FROM ztcmsm00250 INTO @DATA(lv_count).
        out->write( |사용처 인덱스를 다시 만들었습니다: { lv_count }건| ).
      CATCH cx_apj_rt_content INTO DATA(lx_apj).
        out->write( lx_apj->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD if_apj_rt_exec_object~execute.

    " 쓰이는 오브젝트 + 쓰는 CDS 가 키 (같은 CDS 가 데이터 소스이자 연관이면 한 줄로 '데이터 소스·연관')
    DATA lt_index  TYPE HASHED TABLE OF ztcmsm00250 WITH UNIQUE KEY usedobject usedby.
    DATA lt_target TYPE string_table.
    DATA lv_main   TYPE string.

    DATA(lv_now) = utclong_current( ).

    " DATA_SOURCE 안에서 이름을 찾아볼 항목 (VH 데이터 소스 조회와 같음. 빈 값 = DATA_SOURCE 자체가 이름)
    DATA(lt_component) = VALUE string_table( ( `` ) ( `ENTITY` ) ( `NAME` ) ( `VIEW_ENTITY` ) ( `VIEW` )
                                             ( `DATABASE_TABLE` ) ( `TABLE_FUNCTION` ) ).

    " 1) 시스템의 Z CDS 전부
    SELECT ABAPObject, ABAPPackage
      FROM I_CustABAPObjDirectoryEntry
      WHERE ABAPObjectType = 'DDLS'
        AND ABAPObject     LIKE 'Z%'
      INTO TABLE @DATA(lt_ddls).

    LOOP AT lt_ddls INTO DATA(ls_ddls).

      DATA(lv_cds) = to_upper( condense( CONV string( ls_ddls-ABAPObject ) ) ).
      IF strlen( lv_cds ) > 30.
        CONTINUE.
      ENDIF.

      CLEAR: lv_main, lt_target.

      " 2) XCO 로 메인 데이터 소스·연관 대상. CDS 하나를 못 읽어도(비활성·깨진 정의 등) 나머지는 계속
      TRY.
          DATA(lo_view) = xco_cp_cds=>view_entity( CONV #( lv_cds ) ).
          IF lo_view->exists( ) = abap_false.
            CONTINUE.
          ENDIF.

          " 2-1) 메인 데이터 소스: content( )->get( ) 결과의 DATA_SOURCE 항목을 동적으로 찾는다
          DATA(ls_content) = lo_view->content( )->get( ).
          ASSIGN COMPONENT 'DATA_SOURCE' OF STRUCTURE ls_content TO FIELD-SYMBOL(<la_ds>).
          IF sy-subrc = 0.
            LOOP AT lt_component INTO DATA(lv_component).
              IF lv_component IS INITIAL.
                ASSIGN <la_ds> TO FIELD-SYMBOL(<la_value>).
              ELSE.
                ASSIGN COMPONENT lv_component OF STRUCTURE <la_ds> TO <la_value>.
                IF sy-subrc <> 0.
                  CONTINUE.
                ENDIF.
              ENDIF.
              " 문자형일 때만 이름으로 본다
              DATA(lv_type_kind) = cl_abap_typedescr=>describe_by_data( <la_value> )->type_kind.
              IF lv_type_kind = cl_abap_typedescr=>typekind_char OR lv_type_kind = cl_abap_typedescr=>typekind_string.
                lv_main = to_upper( condense( CONV string( <la_value> ) ) ).
                IF lv_main IS NOT INITIAL.
                  EXIT.
                ENDIF.
              ENDIF.
            ENDLOOP.
          ENDIF.

          " 2-2) 연관 대상
          LOOP AT lo_view->associations->all->get( ) INTO DATA(lo_assoc).
            DATA(lv_target) = to_upper( condense( CONV string( lo_assoc->content( )->get( )-target ) ) ).
            APPEND lv_target TO lt_target.
          ENDLOOP.

        CATCH cx_root.
          CONTINUE.
      ENDTRY.

      " 3) 인덱스에 쌓기
      IF lv_main IS NOT INITIAL AND lv_main <> lv_cds AND strlen( lv_main ) <= 40.
        INSERT VALUE #( usedobject = lv_main
                        usedby     = lv_cds
                        usekind    = `데이터 소스`
                        devpackage = ls_ddls-ABAPPackage
                        scannedat  = lv_now ) INTO TABLE lt_index.
      ENDIF.

      LOOP AT lt_target INTO lv_target.
        IF lv_target IS INITIAL OR lv_target = lv_cds OR strlen( lv_target ) > 40.
          CONTINUE.
        ENDIF.
        ASSIGN lt_index[ usedobject = lv_target usedby = lv_cds ] TO FIELD-SYMBOL(<ls_index>).
        IF sy-subrc = 0.
          IF <ls_index>-usekind = `데이터 소스`.
            <ls_index>-usekind = `데이터 소스·연관`.
          ENDIF.
        ELSE.
          INSERT VALUE #( usedobject = lv_target
                          usedby     = lv_cds
                          usekind    = `연관`
                          devpackage = ls_ddls-ABAPPackage
                          scannedat  = lv_now ) INTO TABLE lt_index.
        ENDIF.
      ENDLOOP.

    ENDLOOP.

    " 4) 통째로 바꾼다 (읽다가 중간에 죽으면 예전 인덱스가 그대로 남는다)
    DELETE FROM ztcmsm00250.
    INSERT ztcmsm00250 FROM TABLE @lt_index.
    COMMIT WORK.

  ENDMETHOD.

ENDCLASS.
