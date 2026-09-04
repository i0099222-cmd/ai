*&---------------------------------------------------------------------*
*& Function Module Z_BC_RUN_REPORT
*&---------------------------------------------------------------------*
*& 런처가 "임의의 리포트"를 실행하기 위한 유일한 통로.
*&
*& SUBMIT 은 ABAP for Cloud Development 에서 금지되므로, 이 FM 만
*& Standard ABAP 언어버전에 두고 Local API 로 release 해서
*& ZCL_BC_JOB_RUNNER(Cloud) 가 호출한다.
*&
*& ** 이 FM 하나가 "APJ 는 임의 프로그램을 못 돌린다"는 제약을 푼다. **
*&
*& SE37 생성:
*&   Function Group : Z_BC_JOB_RUN  (신규, Standard ABAP 언어버전 패키지)
*&   Import : IV_PROGRAM TYPE PROGRAMM
*&            IV_VARIANT TYPE RALDB_VARI  (선택)
*&   Export : EV_SUBRC   TYPE SY-SUBRC
*&            EV_MESSAGE TYPE STRING
*&   생성 후 SE37 > Goto > API State > "Use in Cloud Development" release
*&
*& NOTE - 실행 사용자
*&   SUBMIT 은 현재 세션 사용자 권한으로 실행된다. SM36 의 스텝별 사용자
*&   (AUTHCKNAM)처럼 스텝마다 다른 사용자로 돌릴 수 없다. (COMPARISON #2)
*&   AS-IS 에서 스텝별 사용자를 실제로 쓰고 있으면 이 부분이 기능 손실이다.
*&---------------------------------------------------------------------*
FUNCTION z_bc_run_report.

  CLEAR: ev_subrc, ev_message.

  IF iv_program IS INITIAL.
    ev_subrc   = 4.
    ev_message = 'Program name is empty'.
    RETURN.
  ENDIF.

  " 없는 프로그램을 SUBMIT 하면 짧은 덤프가 난다. 미리 막는다.
  SELECT SINGLE @abap_true FROM trdir
    WHERE name = @iv_program
    INTO @DATA(lv_exists).

  IF lv_exists <> abap_true.
    ev_subrc   = 4.
    ev_message = |Program { iv_program } does not exist|.
    RETURN.
  ENDIF.

  IF iv_variant IS NOT INITIAL.
    SELECT SINGLE @abap_true FROM varid
      WHERE report = @iv_program AND variant = @iv_variant
      INTO @DATA(lv_var_exists).

    IF lv_var_exists <> abap_true.
      ev_subrc   = 4.
      ev_message = |Variant { iv_variant } not found for { iv_program }|.
      RETURN.
    ENDIF.
  ENDIF.

  TRY.
      IF iv_variant IS NOT INITIAL.
        SUBMIT (iv_program) USING SELECTION-SET iv_variant AND RETURN.
      ELSE.
        SUBMIT (iv_program) AND RETURN.
      ENDIF.

      ev_subrc   = sy-subrc.
      ev_message = COND #(
        WHEN sy-subrc = 0 THEN |{ iv_program } executed|
        ELSE |{ iv_program } returned subrc={ sy-subrc }| ).

    CATCH cx_root INTO DATA(lx_error).
      ev_subrc   = 8.
      ev_message = |{ iv_program }: { lx_error->get_text( ) }|.
  ENDTRY.

ENDFUNCTION.
