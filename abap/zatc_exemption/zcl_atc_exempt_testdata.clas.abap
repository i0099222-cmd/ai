"! 테스트 데이터 생성/삭제.
"!
"! 운영 이송 대상이 아니다. 개발/품질 시스템에서만 실행한다.
"!
"! 만드는 것은 대장(ztatcexempt / ztatcexempti / ztatcexemptlog) 데이터다.
"! ATC finding 은 만들 수 없다 - 그건 실제 ATC 실행 결과이므로, finding 목록
"! 화면을 보려면 대상 패키지에 ATC 를 한 번 돌려야 한다.
"! 이 데이터로 확인할 수 있는 것은 신청 목록, 오브젝트 페이지, 상태별 버튼
"! 노출, 증빙/이력 탭, 그리고 정합성 지표(ExemptionMismatch)다.
"!
"! 대상 오브젝트는 지어내지 않고 TADIR 에서 실제로 읽는다. 지어낸 이름을 쓰면
"! 화면에서 승인/반려를 눌렀을 때 validateScope 가 "오브젝트 없음"으로 막아
"! 정작 테스트하려던 상태 전이를 볼 수 없다.
"!
"! 테스트 행은 사유 텍스트가 '[TEST]' 로 시작하고, cleanup( ) 은 그것만 지운다.
"! 표식을 reasoncode 에 둘 수 없는 이유: 그 필드는 표준이 값 목록을 가지며
"! (SATC_CI_REASONS) 임의 값을 넣으면 표준 반영이 거부된다.
CLASS zcl_atc_exempt_testdata DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! 테스트 행 표식. 사유 텍스트의 접두어이고 cleanup( ) 의 유일한 기준이다.
    CONSTANTS c_marker TYPE string VALUE '[TEST]'.

    "! 컨트롤 테이블 1행. 이게 없으면 ZI_AtcFinding 이 inner join 에서 전부
    "! 걸러내므로 조회 화면이 빈 채로 뜬다. 가장 먼저 실행한다.
    CLASS-METHODS setup_config
      IMPORTING iv_checkvariant TYPE c.

    "! 상태별 신청서 7건 + 증빙 + 이력.
    "! iv_devclass 는 실재하는 커스텀 패키지여야 한다.
    "! 승인대기 건의 신청자.
    "!
    "! 기본값(본인)으로 두면 그 건은 **승인 테스트에 쓸 수 없다**. 앱이
    "! 자기 신청 승인을 막기 때문에(메시지 014) 승인 버튼에서 바로 걸린다.
    "! 승인 경로를 보려면 본인이 아닌 값을 넘긴다. 실재하는 사용자가 아니어도
    "! 된다 - 신청자 존재 여부를 보는 검증은 없다.
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

    "! 대상 패키지에서 실재하는 오브젝트를 읽어 온다.
    CLASS-METHODS read_objects
      IMPORTING iv_devclass   TYPE devclass
      RETURNING VALUE(rt_obj) TYPE tt_obj.

    CLASS-METHODS insert_request
      IMPORTING iv_checkvariant TYPE c
                iv_devclass     TYPE devclass
                iv_scopetype    TYPE c
                is_obj          TYPE ty_obj
                iv_checkclass   TYPE c
                iv_checkcode    TYPE c
                iv_status       TYPE c
                iv_validto      TYPE d
                iv_approver     TYPE c      OPTIONAL
                iv_extexemptid  TYPE c      OPTIONAL
                iv_prereg       TYPE abap_boolean DEFAULT abap_false
                iv_requester    TYPE syuname DEFAULT sy-uname
                iv_reasontext   TYPE string
      RETURNING VALUE(rv_uuid)  TYPE sysuuid_x16.

    CLASS-METHODS insert_item
      IMPORTING iv_exemptuuid TYPE sysuuid_x16
                iv_itemno     TYPE i
                is_obj        TYPE ty_obj
                iv_checkclass TYPE c
                iv_checkcode  TYPE c
                iv_priority   TYPE i
                iv_msgtext    TYPE c.

    CLASS-METHODS insert_log
      IMPORTING iv_exemptuuid TYPE sysuuid_x16
                iv_seqnr      TYPE i
                iv_action     TYPE c
                iv_from       TYPE c
                iv_to         TYPE c
                iv_comment    TYPE string.

ENDCLASS.


CLASS zcl_atc_exempt_testdata IMPLEMENTATION.

  METHOD setup_config.

    " 설정을 쓰는 곳은 zcl_atc_config_setup 하나다. 여기서 또 INSERT 하면
    " 검증을 우회하게 되고, 두 곳의 기본값이 갈라진다.
    DATA(ls_result) = zcl_atc_config_setup=>set_variant(
                        iv_checkvariant = iv_checkvariant
                        " 표준이 승인자를 필수로 받는다. 테스트는 본인으로 둔다.
                        " 단, 본인이 신청한 건은 자기승인 금지(014)에 걸리므로
                        " 승인 단계까지 보려면 계정이 둘 필요하다.
                        iv_defapprover  = sy-uname ).

    IF ls_result-success = abap_false.
      " 설정이 없으면 나머지 테스트가 전부 빈 화면으로 끝난다. 조용히 넘기지 않는다.
      ASSERT 1 = 0.
    ENDIF.

  ENDMETHOD.


  METHOD read_objects.

    SELECT object AS objecttype,
           obj_name AS objectname
      FROM tadir
      WHERE pgmid    = 'R3TR'
        AND devclass = @iv_devclass
        AND delflag  = @abap_false
      ORDER BY object, obj_name
      INTO CORRESPONDING FIELDS OF TABLE @rt_obj
      UP TO 4 ROWS.

  ENDMETHOD.


  METHOD create_requests.

    DATA(lt_obj) = read_objects( iv_devclass ).

    IF lt_obj IS INITIAL.
      " 지어낸 오브젝트로 만들지 않는다. 위 클래스 주석의 이유다.
      RETURN.
    ENDIF.

    " 목록이 4건보다 적어도 돌도록 인덱스를 되감아 쓴다.
    " 테이블 식 안에서 계산하지 않고 변수로 빼 둔다.
    DATA(lv_n)  = lines( lt_obj ).
    DATA(lv_i2) = ( 1 MOD lv_n ) + 1.
    DATA(lv_i3) = ( 2 MOD lv_n ) + 1.

    DATA(ls_o1) = lt_obj[ 1 ].
    DATA(ls_o2) = lt_obj[ lv_i2 ].
    DATA(ls_o3) = lt_obj[ lv_i3 ].

    DATA(lv_cls)  = CONV string( 'CL_CI_TEST_NAMING_CONVENTIONS' ).
    DATA(lv_code) = CONV string( 'NAMING01' ).

    " 날짜 산술의 결과를 그대로 파라미터로 넘기면 정수로 전달된다.
    " TYPE d 변수에 담아 날짜로 확정한 뒤 넘긴다.
    DATA: lv_d180 TYPE d, lv_d90  TYPE d, lv_d365 TYPE d,
          lv_d200 TYPE d, lv_d30  TYPE d, lv_d60  TYPE d, lv_dpast TYPE d.
    lv_d180  = sy-datum + 180.
    lv_d90   = sy-datum + 90.
    lv_d365  = sy-datum + 365.
    lv_d200  = sy-datum + 200.
    lv_d30   = sy-datum + 30.
    lv_d60   = sy-datum + 60.
    lv_dpast = sy-datum - 10.

    " --- 1. 초안. 아직 제출하지 않은 건. 증빙 없이 선등록한 패키지 예외다.
    DATA(lv_u) = insert_request(
      iv_checkvariant = iv_checkvariant  iv_devclass  = iv_devclass
      iv_scopetype    = zif_atc_exemption=>scope-pckg
      is_obj          = ls_o1
      iv_checkclass   = lv_cls           iv_checkcode = lv_code
      iv_status       = zif_atc_exemption=>status-draft
      iv_validto      = lv_d180
      iv_prereg       = abap_true
      iv_reasontext   = |[TEST] 레거시 이관 패키지. 개명 시 인터페이스 영향이 커 유예 신청.| ).
    insert_log( iv_exemptuuid = lv_u iv_seqnr = 1
                iv_action = zif_atc_exemption=>logaction-create
                iv_from = space iv_to = zif_atc_exemption=>status-draft
                iv_comment = |[TEST] 초안 생성| ).
    rv_count = rv_count + 1.

    " --- 2. 승인대기. 승인/반려 버튼이 보여야 하는 상태다.
    lv_u = insert_request(
      iv_checkvariant = iv_checkvariant  iv_devclass  = iv_devclass
      iv_scopetype    = zif_atc_exemption=>scope-obj
      is_obj          = ls_o2
      iv_checkclass   = lv_cls           iv_checkcode = lv_code
      iv_status       = zif_atc_exemption=>status-pending
      iv_validto      = lv_d90
      iv_approver     = sy-uname
      iv_requester    = iv_requester
      iv_reasontext   = |[TEST] 표준 연동 구조체명을 상대 시스템 규격에 맞춰야 함.| ).
    insert_item( iv_exemptuuid = lv_u iv_itemno = 1 is_obj = ls_o2
                 iv_checkclass = lv_cls iv_checkcode = lv_code
                 iv_priority = 2 iv_msgtext = 'Name does not match the naming convention' ).
    insert_log( iv_exemptuuid = lv_u iv_seqnr = 1
                iv_action = zif_atc_exemption=>logaction-create
                iv_from = space iv_to = zif_atc_exemption=>status-draft
                iv_comment = |[TEST] 초안 생성| ).
    insert_log( iv_exemptuuid = lv_u iv_seqnr = 2
                iv_action = zif_atc_exemption=>logaction-submit
                iv_from = zif_atc_exemption=>status-draft
                iv_to   = zif_atc_exemption=>status-pending
                iv_comment = |[TEST] 승인 요청| ).
    rv_count = rv_count + 1.

    " --- 3. 승인 + 표준 반영 완료. 정상 상태의 기준선이다.
    lv_u = insert_request(
      iv_checkvariant = iv_checkvariant  iv_devclass  = iv_devclass
      iv_scopetype    = zif_atc_exemption=>scope-pckg
      is_obj          = ls_o1
      iv_checkclass   = lv_cls           iv_checkcode = lv_code
      iv_status       = zif_atc_exemption=>status-approved
      iv_validto      = lv_d365
      iv_approver     = sy-uname
      iv_extexemptid  = '00000000000000000000000000000001'
      iv_reasontext   = |[TEST] 패키지 전체 유예. 차기 리팩토링 과제로 등록됨.| ).
    insert_item( iv_exemptuuid = lv_u iv_itemno = 1 is_obj = ls_o1
                 iv_checkclass = lv_cls iv_checkcode = lv_code
                 iv_priority = 3 iv_msgtext = 'Name does not match the naming convention' ).
    insert_log( iv_exemptuuid = lv_u iv_seqnr = 1
                iv_action = zif_atc_exemption=>logaction-approve
                iv_from = zif_atc_exemption=>status-pending
                iv_to   = zif_atc_exemption=>status-approved
                iv_comment = |[TEST] 승인| ).
    insert_log( iv_exemptuuid = lv_u iv_seqnr = 2
                iv_action = zif_atc_exemption=>logaction-sync
                iv_from = zif_atc_exemption=>status-approved
                iv_to   = zif_atc_exemption=>status-approved
                iv_comment = |[TEST] 표준 예외 저장소 반영 성공| ).
    rv_count = rv_count + 1.

    " --- 4. 승인했는데 표준 반영 실패(extexemptid 가 비어 있다).
    "     ZI_AtcFinding 의 ExemptionMismatch 가 'X' 로 잡혀야 하는 건이다.
    "     실제로는 여전히 ATC 에서 차단되므로, 이 지표가 없으면 조용히 묻힌다.
    lv_u = insert_request(
      iv_checkvariant = iv_checkvariant  iv_devclass  = iv_devclass
      iv_scopetype    = zif_atc_exemption=>scope-obj
      is_obj          = ls_o3
      iv_checkclass   = lv_cls           iv_checkcode = lv_code
      iv_status       = zif_atc_exemption=>status-approved
      iv_validto      = lv_d200
      iv_approver     = sy-uname
      iv_reasontext   = |[TEST] 승인은 되었으나 표준 반영이 실패한 건. 정합성 점검 대상.| ).
    insert_log( iv_exemptuuid = lv_u iv_seqnr = 1
                iv_action = zif_atc_exemption=>logaction-approve
                iv_from = zif_atc_exemption=>status-pending
                iv_to   = zif_atc_exemption=>status-approved
                iv_comment = |[TEST] 승인| ).
    insert_log( iv_exemptuuid = lv_u iv_seqnr = 2
                iv_action = zif_atc_exemption=>logaction-sync
                iv_from = zif_atc_exemption=>status-approved
                iv_to   = zif_atc_exemption=>status-approved
                iv_comment = |[TEST] 표준 반영 실패 - create_exemption 오류| ).
    rv_count = rv_count + 1.

    " --- 5. 반려.
    lv_u = insert_request(
      iv_checkvariant = iv_checkvariant  iv_devclass  = iv_devclass
      iv_scopetype    = zif_atc_exemption=>scope-obj
      is_obj          = ls_o2
      iv_checkclass   = lv_cls           iv_checkcode = lv_code
      iv_status       = zif_atc_exemption=>status-rejected
      iv_validto      = lv_d30
      iv_approver     = sy-uname
      iv_reasontext   = |[TEST] 신규 개발 건이라 규칙을 지킬 수 있다고 판단되어 반려.| ).
    insert_log( iv_exemptuuid = lv_u iv_seqnr = 1
                iv_action = zif_atc_exemption=>logaction-reject
                iv_from = zif_atc_exemption=>status-pending
                iv_to   = zif_atc_exemption=>status-rejected
                iv_comment = |[TEST] 신규 개발은 예외 대상이 아님| ).
    rv_count = rv_count + 1.

    " --- 6. 철회.
    lv_u = insert_request(
      iv_checkvariant = iv_checkvariant  iv_devclass  = iv_devclass
      iv_scopetype    = zif_atc_exemption=>scope-obj
      is_obj          = ls_o3
      iv_checkclass   = lv_cls           iv_checkcode = lv_code
      iv_status       = zif_atc_exemption=>status-revoked
      iv_validto      = lv_d60
      iv_approver     = sy-uname
      iv_reasontext   = |[TEST] 대상 오브젝트를 규칙에 맞게 개명하여 예외가 불필요해짐.| ).
    insert_log( iv_exemptuuid = lv_u iv_seqnr = 1
                iv_action = zif_atc_exemption=>logaction-revoke
                iv_from = zif_atc_exemption=>status-approved
                iv_to   = zif_atc_exemption=>status-revoked
                iv_comment = |[TEST] 개명 완료로 철회| ).
    rv_count = rv_count + 1.

    " --- 7. 만료. validto 가 과거다. 만료 배치가 만든 결과와 같은 모양이다.
    lv_u = insert_request(
      iv_checkvariant = iv_checkvariant  iv_devclass  = iv_devclass
      iv_scopetype    = zif_atc_exemption=>scope-pckg
      is_obj          = ls_o1
      iv_checkclass   = lv_cls           iv_checkcode = lv_code
      iv_status       = zif_atc_exemption=>status-expired
      iv_validto      = lv_dpast
      iv_approver     = sy-uname
      iv_extexemptid  = '00000000000000000000000000000002'
      iv_reasontext   = |[TEST] 유효기간이 지나 자동 만료된 건.| ).
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
      checkvariant = iv_checkvariant
      checkgroup   = 'NAMING'
      scopetype    = iv_scopetype
      devclass     = iv_devclass
      inclsubpkg   = abap_false
      " 패키지 스코프도 출발점 오브젝트를 채운다. 표준 create_exemption 이
      " 오브젝트를 필수로 받고 set_object_scope( ) 로 범위를 넓히기 때문이다.
      objecttype   = is_obj-objecttype
      objectname   = is_obj-objectname
      checkclass   = iv_checkclass
      checkcode    = iv_checkcode
      rulescope    = zif_atc_exemption=>rulescope-message
      " 표준이 받는 사유 코드다. c_marker 는 테스트 표식이라 여기 쓸 수 없다.
      reasoncode   = zif_atc_exemption=>reason-other
      reasontext   = iv_reasontext
      validfrom    = sy-datum
      validto      = iv_validto
      exemptstat   = iv_status
      requester    = iv_requester
      approver     = iv_approver
      approvedat   = COND timestampl( WHEN iv_approver IS NOT INITIAL THEN lv_ts )
      extexemptid  = iv_extexemptid
      preregflag   = iv_prereg
      loclastchgat = lv_ts ) ).

  ENDMETHOD.


  METHOD insert_item.

    GET TIME STAMP FIELD DATA(lv_ts).

    INSERT ztatcexempti FROM @( VALUE #(
      itemuuid     = cl_system_uuid=>create_uuid_x16_static( )
      exemptuuid   = iv_exemptuuid
      itemno       = iv_itemno
      objecttype   = is_obj-objecttype
      objectname   = is_obj-objectname
      " 실제 ATC 의 checksum 이 아니다. 목록 표시 확인용 값이다.
      checksum     = 100000 + iv_itemno
      checkclass   = iv_checkclass
      checkcode    = iv_checkcode
      priority     = iv_priority
      msgtext      = iv_msgtext
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
