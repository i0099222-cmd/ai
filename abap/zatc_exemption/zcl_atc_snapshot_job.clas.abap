"! ATC finding 스냅샷 적재 배치.
"!
"! 조회 화면이 ATC 표준 테이블을 직접 읽지 않게 하기 위한 중간 계층이다.
"!   1) 표준 오브젝트 의존을 zcl_atc_finding_reader 한 곳으로 묶는다
"!   2) 대량 건 조회 성능을 확보한다
"!   3) 스냅샷일자가 쌓이므로 월별 위반 추이를 볼 수 있다
"!
"! Phase 2 에서 대상 체크가 늘면 적재량이 수만~수십만 건이 된다.
"! 보관 정책과 인덱스가 없으면 그 시점에 성능 장애로 드러난다.
"!
"! TODO 스케줄링 연결. zcl_atc_expiry_job 과 동일한 방식으로 붙인다.
CLASS zcl_atc_snapshot_job DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! 스냅샷 보관 일수. TODO 설정 테이블로 뺄 것 (상수 하드코딩 금지 원칙).
    CONSTANTS c_retention_days TYPE i VALUE 180.

    TYPES:
      BEGIN OF ty_result,
        loaded TYPE i,
        purged TYPE i,
      END OF ty_result.

    "! 배치 진입점
    METHODS run
      RETURNING VALUE(rs_result) TYPE ty_result.

    "! 활성 체크의 finding 을 읽어 스냅샷 테이블에 적재한다.
    METHODS load
      RETURNING VALUE(rv_count) TYPE i.

    "! 보관 기간이 지난 스냅샷을 정리한다.
    METHODS purge
      IMPORTING iv_days         TYPE i DEFAULT c_retention_days
      RETURNING VALUE(rv_count) TYPE i.

ENDCLASS.


CLASS zcl_atc_snapshot_job IMPLEMENTATION.

  METHOD run.

    rs_result-loaded = load( ).
    rs_result-purged = purge( ).

  ENDMETHOD.


  METHOD load.

    DATA lt_snapshot TYPE STANDARD TABLE OF ztatcfinding WITH EMPTY KEY.

    " 대상 체크는 설정에서 읽는다. 체크 ID 를 코드에 박으면 Phase 2 에서
    " 이 배치부터 고쳐야 한다.
    SELECT checkid, messageid, checkgroup
      FROM ztatccheck
      WHERE activeflg = @abap_true
      INTO TABLE @DATA(lt_check).

    IF lt_check IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lo_reader) = NEW zcl_atc_finding_reader( ).

    GET TIME STAMP FIELD DATA(lv_now).

    LOOP AT lt_check INTO DATA(ls_check).

      " 적재는 담당자와 무관하게 전체를 읽는다 (경로 2).
      DATA(lt_finding) = lo_reader->select( VALUE #(
                           checkid   = ls_check-checkid
                           messageid = ls_check-messageid
                           only_mine = abap_false ) ).

      LOOP AT lt_finding INTO DATA(ls_finding).
        APPEND VALUE #(
          findinguuid   = cl_system_uuid=>create_uuid_x16_static( )
          snapshotdate  = sy-datum
          devclass      = ls_finding-devclass
          objecttype    = ls_finding-objecttype
          objectname    = ls_finding-objectname
          subobject     = ls_finding-subobject
          lineno        = ls_finding-lineno
          findingkey    = ls_finding-findingkey
          checkid       = ls_finding-checkid
          messageid     = ls_finding-messageid
          checkgroup    = ls_check-checkgroup
          priority      = ls_finding-priority
          msgtext       = ls_finding-msgtext
          contactperson = ls_finding-contactperson
          responsible   = ls_finding-responsible
          createdat     = lv_now ) TO lt_snapshot.
      ENDLOOP.

    ENDLOOP.

    IF lt_snapshot IS INITIAL.
      RETURN.
    ENDIF.

    " 같은 날 재실행하면 그날 분을 갈아엎는다. 중복 적재를 막는다.
    DELETE FROM ztatcfinding WHERE snapshotdate = @sy-datum.
    INSERT ztatcfinding FROM TABLE @lt_snapshot.

    rv_count = lines( lt_snapshot ).

    COMMIT WORK.

  ENDMETHOD.


  METHOD purge.

    DATA(lv_cutoff) = CONV d( sy-datum - iv_days ).

    DELETE FROM ztatcfinding WHERE snapshotdate < @lv_cutoff.
    rv_count = sy-dbcnt.

    COMMIT WORK.

  ENDMETHOD.

ENDCLASS.
