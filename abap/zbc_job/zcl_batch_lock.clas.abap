"! <p class="shorttext synchronized">배치 중복 실행 방지 잠금</p>
"!
"! 돌고 있는 배치를 다시 돌리지 못하게 한다. 그것만 한다.
"!
"!   METHOD if_apj_rt_exec_object~execute.
"!
"!     DATA(lo_lock) = NEW zcl_batch_lock( 'BATCH_SAMPLE' ).
"!
"!     IF lo_lock->acquire( ) = abap_false.
"!       MESSAGE '이미 실행 중이라 건너뜁니다' TYPE 'I'.
"!       RETURN.
"!     ENDIF.
"!
"!     " ... 업무 로직 ...
"!
"!   ENDMETHOD.
"!
"! 잠금을 푸는 코드가 없는 것이 맞다. 배치 잡은 세션 하나이고,
"! 잠금은 그 세션이 끝나면 자동으로 풀린다. 잡이 죽어도 마찬가지라
"! 고아 잠금이 남지 않는다. 잡이 끝나기 전에 먼저 풀고 싶을 때만
"! RELEASE( ) 를 부른다.
"!
"! ** 왜 상태 컬럼이 아니라 잠금인가 **
"!   상태 컬럼으로 막으면 잡이 죽었을 때 그 값이 남아 영원히 스킵된다.
"!   그래서 "몇 초 지나면 죽은 걸로 본다" 는 타임아웃이 필요해지는데,
"!   짧으면 도는 잡을 또 돌리고 길면 죽은 잡이 오래 막는다.
"!
"! ** 전제 **
"!   잠금 오브젝트 EZBATCH_LOCK (테이블 ZTBATCH_LOCK, 키 LOCK_KEY, 모드 E)
CLASS zcl_batch_lock DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! @parameter iv_key | 잠금 단위. 같은 키끼리 겹치지 않는다.
    "!                     배치 종류로 막으려면 배치 이름, 건별로 막으려면
    "!                     그 건의 키를 넣는다.
    METHODS constructor
      IMPORTING iv_key TYPE ztbatch_lock-lock_key.

    "! 잠금을 잡는다. 이미 누가 들고 있으면 기다리지 않고 FALSE 를 준다.
    METHODS acquire
      RETURNING VALUE(rv_ok) TYPE abap_bool
      RAISING   cx_abap_lock_failure.

    "! 잡이 끝나기 전에 먼저 풀 때만 쓴다. 안 불러도 세션 종료 시 풀린다.
    METHODS release
      RAISING cx_abap_lock_failure.

  PRIVATE SECTION.

    DATA mv_key   TYPE ztbatch_lock-lock_key.
    DATA mo_lock  TYPE REF TO if_abap_lock_object.
    DATA mt_param TYPE if_abap_lock_object=>tt_parameter.

ENDCLASS.


CLASS zcl_batch_lock IMPLEMENTATION.

  METHOD constructor.

    " TODO: 시그니처 확인 - TT_PARAMETER 의 컴포넌트명 (name / value)
    mv_key   = iv_key.
    mo_lock  = cl_abap_lock_object_factory=>get_instance( iv_name = 'EZBATCH_LOCK' ).
    mt_param = VALUE #( ( name = 'LOCK_KEY' value = REF #( mv_key ) ) ).

  ENDMETHOD.


  METHOD acquire.

*   SCOPE 1 - 세션이 잠금을 들고 있다. 업무 로직이 커밋해도 풀리지 않는다.
*             기본값 2 는 커밋 시점에 넘기고 해제하므로 쓸 수 없다.
    TRY.
        " TODO: 시그니처 확인 - ENQUEUE 의 파라미터명과 SCOPE 값
        mo_lock->enqueue( it_parameter = mt_param
                          iv_scope     = '1'
                          iv_wait      = abap_false ).
        rv_ok = abap_true.

      CATCH cx_abap_foreign_lock.
        " 다른 세션이 들고 있다 = 그 배치가 돌고 있다. 정상 상황이다.
        rv_ok = abap_false.
    ENDTRY.

  ENDMETHOD.


  METHOD release.

    mo_lock->dequeue( it_parameter = mt_param ).

  ENDMETHOD.

ENDCLASS.
