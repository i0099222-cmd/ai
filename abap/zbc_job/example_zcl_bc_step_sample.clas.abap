"! <p class="shorttext synchronized">예시: 배치 실행 클래스</p>
"!
"! 기존 배치 리포트(ZR_XXX)를 APJ 로 이관할 때의 형태.
"! ZTJOB_RUN-EXEC_CLASS 에 이 클래스 이름을 넣으면 런처가 동적 생성해서 실행한다.
"!
"! 이관 방법:
"!   리포트의 START-OF-SELECTION 로직 -> EXECUTE 메서드
"!   셀렉션 스크린 파라미터           -> IV_PARAM (JSON). 배리언트를 대신한다.
"!   WRITE 리스트                     -> MESSAGE 또는 반환 문자열 (잡 로그로)
"!
"! 이 클래스는 실제 오브젝트가 아니라 참고용 예시다.
CLASS zcl_bc_step_sample DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_bc_job_step.

  PRIVATE SECTION.

    "! 이 배치가 받는 업무 파라미터. 리포트의 셀렉션 스크린에 해당한다.
    TYPES:
      BEGIN OF ty_app_param,
        company_code TYPE c LENGTH 4,
        posting_date TYPE d,
        test_run     TYPE abap_bool,
      END OF ty_app_param.

ENDCLASS.


CLASS zcl_bc_step_sample IMPLEMENTATION.

  METHOD zif_bc_job_step~execute.

    " 1) 파라미터 파싱 - 리포트의 셀렉션 스크린 자리
    DATA ls_param TYPE ty_app_param.

    IF iv_param IS NOT INITIAL.
      TRY.
          xco_cp_json=>data->from_string( iv_param )->write_to( REF #( ls_param ) ).
        CATCH cx_root INTO DATA(lx_parse).
          RAISE EXCEPTION NEW zcx_bc_job(
            message  = |Parameter parse failed: { lx_parse->get_text( ) }|
            previous = lx_parse ).
      ENDTRY.
    ENDIF.

    IF ls_param-company_code IS INITIAL.
      RAISE EXCEPTION NEW zcx_bc_job( message = 'Company code is required' ).
    ENDIF.

    " 2) 업무 로직 - 리포트의 START-OF-SELECTION 자리
    "    WRITE 대신 MESSAGE 로 남기면 잡 로그에 수집된다.
    MESSAGE |Sample step start: bukrs={ ls_param-company_code } | &&
            |testrun={ ls_param-test_run }| TYPE 'I'.

    " ... 실제 처리 ...
    DATA(lv_processed) = 0.

    " 3) 결과 요약 반환 - 런처가 잡 로그에 남긴다
    rv_message = |Sample step done: processed={ lv_processed }|.

  ENDMETHOD.

ENDCLASS.
