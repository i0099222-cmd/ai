"! 엑셀 업로드 접수 공통 클래스 (ABAP Cloud 언어버전).
"! 이 클래스는 화이트리스트 조회(ZEXCEL_MIGR_WL), 권한체크(S_TABU_NAM),
"! 스테이징 테이블 저장(ZEXCEL_MIGR_REQ)까지만 담당한다 - 전부 정적
"! 테이블명/릴리즈 API만 사용하므로 ABAP Cloud에서 그대로 동작한다.
"!
"! 실제 엑셀 바이너리 파싱 + 대상 테이블 동적 INSERT는 이 클래스가 아니라
"! Z_EXCEL_TABLE_MIGRATOR 리포트(Standard ABAP, Local Release)에서 백그라운드
"! 잡으로 수행한다. 잡 예약(JOB_OPEN/SUBMIT/JOB_CLOSE)도 Standard ABAP
"! 전용 API이므로 Z_EXCEL_MIGR_SCHEDULE_JOB 함수모듈에 위임한다.
"! (zcl_parked_doc_poster가 CALL TRANSACTION을 FM으로 분리한 것과 동일한 이유)
CLASS zcl_excel_table_migrator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_excel_table_migrator.

ENDCLASS.


CLASS zcl_excel_table_migrator IMPLEMENTATION.

  METHOD zif_excel_table_migrator~check_table_allowed.

    rv_allowed = abap_false.

    " 1) 화이트리스트 조회 - 등록/활성화된 테이블만 대상으로 허용.
    "    임의 테이블명을 검증 없이 동적 INSERT에 쓰지 않기 위한 1차 방어.
    SELECT SINGLE @abap_true
      FROM zexcel_migr_wl
      WHERE tabname = @iv_tabname
        AND active  = @abap_true
      INTO @DATA(lv_whitelisted).

    IF lv_whitelisted <> abap_true.
      RETURN.
    ENDIF.

    " 2) 표준 권한 오브젝트 S_TABU_NAM으로 2차 방어.
    "    화이트리스트에 있어도 이 사용자가 해당 테이블에 대한 변경 권한이
    "    없으면 거부한다 (테이블 권한 관리 정책과 이중으로 어긋나지 않도록).
    AUTHORITY-CHECK OBJECT 'S_TABU_NAM'
      ID 'TABLE' FIELD iv_tabname
      ID 'ACTVT' FIELD iv_activity.

    IF sy-subrc = 0.
      rv_allowed = abap_true.
    ENDIF.

  ENDMETHOD.


  METHOD zif_excel_table_migrator~accept_request.

    " 대상 테이블 검증 - 여기서 막으면 스테이징 저장/잡 예약 자체를 하지 않는다.
    IF zif_excel_table_migrator~check_table_allowed( iv_tabname = is_request-tabname ) = abap_false.
      RAISE EXCEPTION TYPE zcx_excel_migr_error
        EXPORTING
          textid  = zcx_excel_migr_error=>table_not_allowed
          tabname = is_request-tabname.
    ENDIF.

    DATA(lv_request_id) = cl_system_uuid=>create_uuid_x16_static( ).

    " 스테이징 테이블은 우리가 만든 Z 테이블(정적 이름)이므로 ABAP Cloud에서
    " 문제 없이 바로 INSERT 가능하다 - 동적 INSERT가 필요한 건 대상 테이블뿐.
    INSERT zexcel_migr_req FROM @( VALUE #(
      request_id   = lv_request_id
      tabname      = is_request-tabname
      filename     = is_request-filename
      file_content = is_request-file_content
      status       = 'N'
      created_by   = cl_abap_context_info=>get_user_technical_name( )
      created_at   = utclong_current( ) ) ).

    " 실제 파싱/마이그레이션은 백그라운드 잡으로 위임 (LUW/타임아웃 회피).
    " request_id를 잡 파라미터로 넘겨, 리포트가 해당 건만 다시 읽어 처리하게 한다.
    CALL FUNCTION 'Z_EXCEL_MIGR_SCHEDULE_JOB'
      EXPORTING
        iv_request_id = lv_request_id
      IMPORTING
        ev_job_name   = DATA(lv_job_name)
        ev_job_count  = DATA(lv_job_count)
      EXCEPTIONS
        schedule_failed = 1
        OTHERS           = 2.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_excel_migr_error
        EXPORTING
          textid = zcx_excel_migr_error=>job_schedule_failed.
    ENDIF.

    rs_result = VALUE #(
      request_id = lv_request_id
      job_name   = lv_job_name
      job_count  = lv_job_count ).

  ENDMETHOD.

ENDCLASS.
