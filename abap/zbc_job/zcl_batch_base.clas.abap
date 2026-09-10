"! <p class="shorttext synchronized">배치 공통 베이스 - 중복 실행 방지</p>
"!
"! 돌고 있는 배치를 다시 돌리지 못하게 한다. 그것만 한다.
"!
"! 각 배치는 이 클래스를 상속하고 PROCESS( ) 하나만 구현한다.
"! 잠금 코드는 쓰지 않는다.
"!
"!   CLASS zcl_batch_settle DEFINITION
"!     INHERITING FROM zcl_batch_base ...
"!     INTERFACES if_apj_rt_exec_object.
"!     METHODS process REDEFINITION.
"!
"!   METHOD if_apj_rt_exec_object~execute.
"!     run( 'SETTLE' ).
"!   ENDMETHOD.
"!
"!   METHOD process.
"!     " 업무 로직만
"!   ENDMETHOD.
"!
"! ** 왜 상태 테이블이 아니라 잠금 오브젝트인가 **
"!   상태 컬럼으로 막으면 잡이 죽었을 때 그 값이 남아 영원히 스킵된다.
"!   그래서 "몇 초 지나면 죽은 걸로 본다" 는 타임아웃 추측값이 필요해지는데,
"!   짧으면 도는 잡을 또 돌리고 길면 죽은 잡이 오래 막는다.
"!   잠금은 세션이 끝나면 자동으로 풀려서 그 추측이 필요 없다.
"!
"! ** 전제 **
"!   잠금 오브젝트 EZBATCH_LOCK (테이블 ZTBATCH_LOCK, 키 LOCK_KEY, 모드 E)
CLASS zcl_batch_base DEFINITION
  PUBLIC
  ABSTRACT
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! 잠금을 잡고 PROCESS( ) 를 부른다. 이미 돌고 있으면 아무것도 하지 않는다.
    "!
    "! @parameter iv_lock_key | 잠금 단위. 같은 키끼리 겹치지 않는다.
    "!                          배치 종류로 막으려면 배치 이름, 건별로 막으려면
    "!                          그 건의 키를 넣는다.
    METHODS run
      IMPORTING iv_lock_key TYPE ztbatch_lock-lock_key
      RAISING   zcx_batch_job.

  PROTECTED SECTION.

    "! 실행 중인 잠금 키. 업무 로직에서 필요하면 쓴다.
    DATA mv_lock_key TYPE ztbatch_lock-lock_key.

    "! 각 배치의 업무 로직. 예외를 던지면 잡이 오류 종료된다.
    METHODS process ABSTRACT
      RAISING cx_static_check.

ENDCLASS.


CLASS zcl_batch_base IMPLEMENTATION.

  METHOD run.

    mv_lock_key = iv_lock_key.

    " TODO: 시그니처 확인 - ENQUEUE/DEQUEUE 의 파라미터명과 SCOPE 값
    DATA(lo_lock) = cl_abap_lock_object_factory=>get_instance( iv_name = 'EZBATCH_LOCK' ).

    DATA(lt_key) = VALUE if_abap_lock_object=>tt_parameter(
                     ( name = 'LOCK_KEY' value = REF #( mv_lock_key ) ) ).

*   이미 돌고 있으면 못 잡는다. 기다리지 않고 이번 회차는 거른다.
*   SCOPE 1 - 세션이 잠금을 들고 있어서 업무 로직이 커밋해도 풀리지 않는다.
    TRY.
        lo_lock->enqueue( it_parameter = lt_key
                          iv_scope     = '1'
                          iv_wait      = abap_false ).

      CATCH cx_abap_foreign_lock.
        MESSAGE |이미 실행 중이라 건너뜁니다: { mv_lock_key }| TYPE 'I'.
        RETURN.
    ENDTRY.

    MESSAGE |배치 시작: { mv_lock_key }| TYPE 'I'.

    DATA lv_error TYPE string.

    TRY.
        process( ).
        MESSAGE |배치 완료: { mv_lock_key }| TYPE 'I'.

      CATCH cx_root INTO DATA(lx_error).
        lv_error = lx_error->get_text( ).
    ENDTRY.

*   실패했어도 먼저 푼다. 그 다음에 잡을 실패시킨다.
*   여기까지 못 와도 세션이 끝나면 잠금은 자동으로 풀린다.
    lo_lock->dequeue( it_parameter = lt_key ).

    IF lv_error IS NOT INITIAL.
      RAISE EXCEPTION NEW zcx_batch_job( message = lv_error ).
    ENDIF.

  ENDMETHOD.

ENDCLASS.
