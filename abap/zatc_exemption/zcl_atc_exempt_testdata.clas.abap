"! 테스트 데이터 생성/삭제. 개발/품질 시스템 전용이며 운영 이송 대상이 아니다.
"!
"! 대장(ztatcexempt / ztatcexempti / ztatcexemptlog) 데이터만 만든다. ATC finding 은
"! 실제 실행 결과라 만들 수 없다 - 대상 값 도움에 위반이 보이려면 ATC 를 돌린다.
"! 대상 오브젝트는 TADIR 에서 실제로 읽는다. 지어낸 이름은 대상 검증(008)에 걸린다.
"!
"! 테스트 행은 사유 텍스트가 '[TEST]' 로 시작하고, cleanup( ) 은 그것만 지운다.
"! 사유 코드는 표준이 값 목록을 가져서(SATC_CI_REASONS) 표식으로 쓸 수 없다.
CLASS zcl_atc_exempt_testdata DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! 테스트 행 표식. 사유 텍스트의 접두어이고 cleanup( ) 의 유일한 기준이다.
    CONSTANTS c_marker TYPE string VALUE '[TEST]'.

    "! 상태별 요청서 6건 + 대상 줄 + 이력. iv_devclass 는 오브젝트가 든 실재 패키지여야 한다.
    "! iv_requester 는 승인대기 건의 신청자다. 본인으로 두면 자기승인 금지(014)에 걸린다.
    "! 승인대기 건은 표준 ID 가 없어 승인하면 "표준 예외 없음" 으로 멈춘다. 승인까지 보려면
    "! 계정 둘로 화면에서 직접 만든다 - A 로 상신하고 B 로 승인한다.
    CLASS-METHODS create_requests
      IMPORTING iv_checkvariant TYPE c
                iv_devclass     TYPE devclass
                iv_requester    TYPE syuname DEFAULT sy-uname
      RETURNING VALUE(rv_count) TYPE i.

    "! 표식이 붙은 행만 지운다. 실제 신청 데이터는 건드리지 않는다.
    CLASS-METHODS cleanup
      RETURNING VALUE(rv_count) TYPE i.

  PRIVATE SECTION.

    TYPES: BEGIN OF ty_obj,
             objecttype TYPE trobjtype,
             objectname TYPE sobj_name,
           END OF ty_obj,
           tt_obj TYPE STANDARD TABLE OF ty_obj WITH EMPTY KEY.

    CLASS-METHODS insert_request
      IMPORTING iv_checkvariant TYPE c
                iv_title        TYPE c
                iv_checkclass   TYPE c
                iv_status       TYPE c
                iv_validto      TYPE d
                iv_approver     TYPE c      OPTIONAL
                iv_requester    TYPE syuname DEFAULT sy-uname
                iv_reasontext   TYPE string
      RETURNING VALUE(rv_uuid)  TYPE sysuuid_x16.

    "! 대상 한 줄. is_obj 가 비면 패키지 대상이다.
    CLASS-METHODS insert_item
      IMPORTING iv_exemptuuid  TYPE sysuuid_x16
                iv_itemno      TYPE i
                iv_devclass    TYPE devclass
                is_obj         TYPE ty_obj OPTIONAL
                iv_checkclass  TYPE c
                iv_checkcode   TYPE c
                iv_extexemptid TYPE c OPTIONAL
                iv_stdstatus   TYPE c OPTIONAL.

    CLASS-METHODS insert_log
      IMPORTING iv_exemptuuid TYPE sysuuid_x16
                iv_seqnr      TYPE i
                iv_action     TYPE c
                iv_from       TYPE c
                iv_to         TYPE c
                iv_comment    TYPE string.

ENDCLASS.


CLASS zcl_atc_exempt_testdata IMPLEMENTATION.

  METHOD create_requests.

    " 대상 오브젝트는 지어내지 않고 그 패키지에서 실제로 읽는다.
    DATA lt_obj TYPE tt_obj.
    SELECT object AS objecttype, obj_name AS objectname
      FROM tadir
      WHERE pgmid    = 'R3TR'
        AND devclass = @iv_devclass
        AND delflag  = @abap_false
      ORDER BY object, obj_name
      INTO CORRESPONDING FIELDS OF TABLE @lt_obj
      UP TO 4 ROWS.

    IF lt_obj IS INITIAL.
      " 지어낸 오브젝트로 만들지 않는다. 위 클래스 주석의 이유다.
      RETURN.
    ENDIF.

    " 목록이 4건보다 적어도 돌도록 인덱스를 되감아 쓴다.
    DATA(lv_n)  = lines( lt_obj ).
    DATA(lv_i2) = ( 1 MOD lv_n ) + 1.
    DATA(lv_i3) = ( 2 MOD lv_n ) + 1.

    DATA(ls_o1) = lt_obj[ 1 ].
    DATA(ls_o2) = lt_obj[ lv_i2 ].
    DATA(ls_o3) = lt_obj[ lv_i3 ].

    DATA(lv_cls)  = CONV string( 'CL_CI_TEST_NAMING_CONVENTIONS' ).
    DATA(lv_code) = CONV string( 'NAMING01' ).

    " 날짜 산술의 결과를 그대로 파라미터로 넘기면 정수로 전달된다.
    DATA: lv_d180 TYPE d, lv_d90  TYPE d, lv_d365 TYPE d,
          lv_d200 TYPE d, lv_d30  TYPE d, lv_d60  TYPE d, lv_dpast TYPE d.
    lv_d180  = sy-datum + 180.
    lv_d90   = sy-datum + 90.
    lv_d365  = sy-datum + 365.
    lv_d200  = sy-datum + 200.
    lv_d30   = sy-datum + 30.
    lv_d60   = sy-datum + 60.
    lv_dpast = sy-datum - 10.

    " --- 1. 초안. 패키지 대상 + 오브젝트 대상 두 줄.
    DATA(lv_u) = insert_request(
      iv_checkvariant = iv_checkvariant  iv_title = '[TEST] Legacy package migration'
      iv_checkclass   = lv_cls
      iv_status       = zif_atc_exemption=>status-draft
      iv_validto      = lv_d180
      iv_reasontext   = |[TEST] 레거시 이관 패키지. 개명 시 인터페이스 영향이 커 유예 신청.| ).
    insert_item( iv_exemptuuid = lv_u iv_itemno = 1 iv_devclass = iv_devclass
                 iv_checkclass = lv_cls iv_checkcode = space ).
    insert_item( iv_exemptuuid = lv_u iv_itemno = 2 iv_devclass = iv_devclass is_obj = ls_o1
                 iv_checkclass = lv_cls iv_checkcode = lv_code ).
    insert_log( iv_exemptuuid = lv_u iv_seqnr = 1
                iv_action = zif_atc_exemption=>logaction-create
                iv_from = space iv_to = zif_atc_exemption=>status-draft
                iv_comment = |[TEST] 초안 생성| ).
    rv_count = rv_count + 1.

    " --- 2. 승인대기. 승인/반려 버튼이 보여야 하는 상태다.
    "     표준 ID 가 없어서 승인을 누르면 "표준 예외 없음" 으로 멈춘다. 버튼 확인용이다.
    lv_u = insert_request(
      iv_checkvariant = iv_checkvariant  iv_title = '[TEST] Interface structure names'
      iv_checkclass   = lv_cls
      iv_status       = zif_atc_exemption=>status-pending
      iv_validto      = lv_d90
      iv_requester    = iv_requester
      iv_reasontext   = |[TEST] 표준 연동 구조체명을 상대 시스템 규격에 맞춰야 함.| ).
    insert_item( iv_exemptuuid = lv_u iv_itemno = 1 iv_devclass = iv_devclass is_obj = ls_o2
                 iv_checkclass = lv_cls iv_checkcode = lv_code ).
    insert_item( iv_exemptuuid = lv_u iv_itemno = 2 iv_devclass = iv_devclass is_obj = ls_o3
                 iv_checkclass = lv_cls iv_checkcode = lv_code ).
    insert_log( iv_exemptuuid = lv_u iv_seqnr = 1
                iv_action = zif_atc_exemption=>logaction-submit
                iv_from = zif_atc_exemption=>status-draft
                iv_to   = zif_atc_exemption=>status-pending
                iv_comment = |[TEST] 승인 요청| ).
    rv_count = rv_count + 1.

    " --- 3. 승인 + 표준 반영 완료. 정상 상태의 기준선이다.
    lv_u = insert_request(
      iv_checkvariant = iv_checkvariant  iv_title = '[TEST] Package postponed to refactoring'
      iv_checkclass   = lv_cls
      iv_status       = zif_atc_exemption=>status-approved
      iv_validto      = lv_d365
      iv_approver     = sy-uname
      iv_reasontext   = |[TEST] 패키지 전체 유예. 차기 리팩토링 과제로 등록됨.| ).
    insert_item( iv_exemptuuid = lv_u iv_itemno = 1 iv_devclass = iv_devclass
                 iv_checkclass = lv_cls iv_checkcode = space
                 iv_extexemptid = '00000000000000000000000000000001'
                 iv_stdstatus   = zif_atc_exemption=>stdstatus-approved ).
    insert_log( iv_exemptuuid = lv_u iv_seqnr = 1
                iv_action = zif_atc_exemption=>logaction-approve
                iv_from = zif_atc_exemption=>status-pending
                iv_to   = zif_atc_exemption=>status-approved
                iv_comment = |[TEST] 승인| ).
    rv_count = rv_count + 1.

    " --- 4. 승인했는데 대상 한 줄의 표준 ID 가 비어 있다(정합성 점검 대상).
    "     ZI_AtcFinding 의 ExemptionMismatch 가 'X' 로 잡혀야 한다.
    lv_u = insert_request(
      iv_checkvariant = iv_checkvariant  iv_title = '[TEST] Approved but not in standard'
      iv_checkclass   = lv_cls
      iv_status       = zif_atc_exemption=>status-approved
      iv_validto      = lv_d200
      iv_approver     = sy-uname
      iv_reasontext   = |[TEST] 승인은 되었으나 표준 반영이 빠진 건. 정합성 점검 대상.| ).
    insert_item( iv_exemptuuid = lv_u iv_itemno = 1 iv_devclass = iv_devclass is_obj = ls_o3
                 iv_checkclass = lv_cls iv_checkcode = lv_code ).
    insert_log( iv_exemptuuid = lv_u iv_seqnr = 1
                iv_action = zif_atc_exemption=>logaction-approve
                iv_from = zif_atc_exemption=>status-pending
                iv_to   = zif_atc_exemption=>status-approved
                iv_comment = |[TEST] 승인| ).
    rv_count = rv_count + 1.

    " --- 5. 반려.
    lv_u = insert_request(
      iv_checkvariant = iv_checkvariant  iv_title = '[TEST] New development, rejected'
      iv_checkclass   = lv_cls
      iv_status       = zif_atc_exemption=>status-rejected
      iv_validto      = lv_d30
      iv_approver     = sy-uname
      iv_reasontext   = |[TEST] 신규 개발 건이라 규칙을 지킬 수 있다고 판단되어 반려.| ).
    insert_item( iv_exemptuuid = lv_u iv_itemno = 1 iv_devclass = iv_devclass is_obj = ls_o2
                 iv_checkclass = lv_cls iv_checkcode = lv_code
                 iv_extexemptid = '00000000000000000000000000000003'
                 iv_stdstatus   = zif_atc_exemption=>stdstatus-rejected ).
    insert_log( iv_exemptuuid = lv_u iv_seqnr = 1
                iv_action = zif_atc_exemption=>logaction-reject
                iv_from = zif_atc_exemption=>status-pending
                iv_to   = zif_atc_exemption=>status-rejected
                iv_comment = |[TEST] 신규 개발은 예외 대상이 아님| ).
    rv_count = rv_count + 1.

    " --- 6. 만료. validto 가 과거다. 만료 배치가 만든 결과와 같은 모양이다.
    lv_u = insert_request(
      iv_checkvariant = iv_checkvariant  iv_title = '[TEST] Expired package exemption'
      iv_checkclass   = lv_cls
      iv_status       = zif_atc_exemption=>status-expired
      iv_validto      = lv_dpast
      iv_approver     = sy-uname
      iv_reasontext   = |[TEST] 유효기간이 지나 자동 만료된 건.| ).
    insert_item( iv_exemptuuid = lv_u iv_itemno = 1 iv_devclass = iv_devclass
                 iv_checkclass = lv_cls iv_checkcode = space ).
    insert_log( iv_exemptuuid = lv_u iv_seqnr = 1
                iv_action = zif_atc_exemption=>logaction-expire
                iv_from = zif_atc_exemption=>status-approved
                iv_to   = zif_atc_exemption=>status-expired
                iv_comment = |[TEST] 유효기간 경과| ).
    rv_count = rv_count + 1.

  ENDMETHOD.


  METHOD insert_request.

    GET TIME STAMP FIELD DATA(lv_ts).

    rv_uuid = cl_system_uuid=>create_uuid_x16_static( ).

    INSERT ztatcexempt FROM @( VALUE #(
      exemptuuid   = rv_uuid
      title        = iv_title
      checkvariant = iv_checkvariant
      checkclass   = iv_checkclass
      " 표준이 받는 사유 코드다. c_marker 는 테스트 표식이라 여기 쓸 수 없다.
      reasoncode   = zif_atc_exemption=>reason-other
      reasontext   = iv_reasontext
      validfrom    = sy-datum
      validto      = iv_validto
      exemptstat   = iv_status
      requester    = iv_requester
      approver     = iv_approver
      approvedat   = COND timestampl( WHEN iv_approver IS NOT INITIAL THEN lv_ts )
      loclastchgat = lv_ts ) ).

  ENDMETHOD.


  METHOD insert_item.

    GET TIME STAMP FIELD DATA(lv_ts).

    DATA(lv_is_obj) = xsdbool( is_obj-objectname IS NOT INITIAL ).

    INSERT ztatcexempti FROM @( VALUE #(
      itemuuid     = cl_system_uuid=>create_uuid_x16_static( )
      exemptuuid   = iv_exemptuuid
      itemno       = iv_itemno
      scopetype    = COND #( WHEN lv_is_obj = abap_true THEN zif_atc_exemption=>scope-obj
                             ELSE zif_atc_exemption=>scope-pckg )
      devclass     = iv_devclass
      objecttype   = is_obj-objecttype
      objectname   = is_obj-objectname
      checkclass   = iv_checkclass
      checkcode    = iv_checkcode
      rulescope    = COND #( WHEN lv_is_obj = abap_true THEN zif_atc_exemption=>rulescope-message
                             ELSE zif_atc_exemption=>rulescope-check )
      extexemptid  = iv_extexemptid
      stdstatus    = iv_stdstatus
      loclastchgat = lv_ts ) ).

  ENDMETHOD.


  METHOD insert_log.

    GET TIME STAMP FIELD DATA(lv_ts).

    INSERT ztatcexemptlog FROM @( VALUE #(
      loguuid    = cl_system_uuid=>create_uuid_x16_static( )
      exemptuuid = iv_exemptuuid
      seqnr      = iv_seqnr
      actioncode = iv_action
      fromstat   = iv_from
      tostat     = iv_to
      commenttxt = iv_comment
      actionby   = sy-uname
      actionat   = lv_ts ) ).

  ENDMETHOD.


  METHOD cleanup.

    " 표식이 사유 텍스트 안에 있고 그 컬럼이 STRING 이라, SQL LIKE 대신
    " 읽어서 거른다. 테스트 유틸리티이고 대상 건수가 작아 문제되지 않는다.
    SELECT exemptuuid, reasontext
      FROM ztatcexempt
      INTO TABLE @DATA(lt_all).

    DATA lr_uuid TYPE RANGE OF sysuuid_x16.

    LOOP AT lt_all INTO DATA(ls_row).
      IF ls_row-reasontext CS c_marker.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_row-exemptuuid ) TO lr_uuid.
      ENDIF.
    ENDLOOP.

    IF lr_uuid IS INITIAL.
      RETURN.
    ENDIF.

    " 자식부터 지운다. 헤더를 먼저 지우면 어느 아이템이 테스트 것인지 알 수 없다.
    DELETE FROM ztatcexemptlog WHERE exemptuuid IN @lr_uuid.
    DELETE FROM ztatcexempti   WHERE exemptuuid IN @lr_uuid.
    DELETE FROM ztatcexempt    WHERE exemptuuid IN @lr_uuid.

    COMMIT WORK.

    rv_count = lines( lr_uuid ).

  ENDMETHOD.


ENDCLASS.
