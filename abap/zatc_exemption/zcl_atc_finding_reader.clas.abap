"! ATC finding 조회 어댑터.
"!
"! ATC 표준 오브젝트에 대한 의존을 이 클래스 하나로 격리한다. 표준 테이블/뷰의
"! 필드명이나 릴리즈 상태가 바뀌어도 수정 지점은 여기뿐이다. 다른 클래스나
"! behavior pool 은 SATC_* 를 직접 SELECT 하지 않는다.
"!
"! 대상 범위는 컨트롤 테이블의 활성 체크 변형이 정한다. 체크 ID 를 코드에
"! 열거하지 않는다.
"!
"! 읽기 경로는 두 개다.
"!   경로 1 (개발자)      : only_mine = X  -> contactperson/responsible = sy-uname
"!   경로 2 (승인자/조회) : only_mine 공란 -> 담당자 필터 없음. 호출자가 권한을 검증한다.
"! 경로 2 가 없으면 승인자가 타인의 finding 을 볼 수 없어 승인 자체가 불가능하고,
"! 패키지 영향도 시뮬레이션도 성립하지 않는다.
CLASS zcl_atc_finding_reader DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    "! 조건에 맞는 ATC finding 을 읽는다.
    METHODS select
      IMPORTING is_selection      TYPE zif_atc_exemption=>ty_selection
                iv_max_rows       TYPE i DEFAULT 0
      RETURNING VALUE(rt_finding) TYPE zif_atc_exemption=>tt_finding.

    "! 예외 1건이 현재 몇 건의 finding 을 덮는지 계산한다.
    "! 패키지 스코프 승인 전에 승인자에게 보여주는 영향도의 근거이며,
    "! 신청 시 근거 텍스트에 자동 기입하는 데에도 쓴다.
    METHODS simulate_impact
      IMPORTING iv_checkvariant   TYPE char30
                iv_scopetype      TYPE char4
                iv_devclass       TYPE devclass
                iv_inclsubpkg     TYPE abap_boolean DEFAULT abap_false
                iv_objecttype     TYPE trobjtype OPTIONAL
                iv_objectname     TYPE sobj_name OPTIONAL
                iv_checkid        TYPE char30 OPTIONAL
                iv_messageid      TYPE char30 OPTIONAL
      RETURNING VALUE(rt_finding) TYPE zif_atc_exemption=>tt_finding.

  PRIVATE SECTION.

    "! 하위 패키지까지 펼친 패키지 목록
    METHODS expand_packages
      IMPORTING iv_devclass         TYPE devclass
                iv_inclsubpkg       TYPE abap_boolean
      RETURNING VALUE(rt_devclass)  TYPE zif_atc_exemption=>tt_devclass.

ENDCLASS.


CLASS zcl_atc_finding_reader IMPLEMENTATION.

  METHOD select.

    " TODO 확인 필요: SATC_API_FINDINGS 의 실제 필드명과 API State.
    "   - ADT 에서 Properties > API State 를 확인한다.
    "     "Released for Cloud Development" 가 아니면 이 클래스는 클래식 ABAP
    "     패키지에 두고 RAP 쪽에서는 래퍼로 호출해야 한다.
    "   - finding 의 키는 resultid + itemid + checkrunindex 이며 런 단위다.
    "     FND 스코프를 열려면 코드 변경·재실행에도 유지되는 식별자가 필요한데,
    "     이 3종으로는 부족하다. Phase 2 착수 전 표준에 그런 키가 있는지 확인할 것.
    "   아래 SELECT 는 필드명을 확인한 뒤 그대로 채우면 되도록 구조만 잡아 둔 것이다.

    DATA(lt_devclass) = expand_packages( iv_devclass   = is_selection-devclass
                                         iv_inclsubpkg = is_selection-inclsubpkg ).

    " 대상 변형은 컨트롤 테이블이 정한다. 체크 ID 를 코드에 박지 않는 이유가
    " 이것이다 - 무엇을 볼지는 표준의 체크 변형이, 그 변형을 쓸지는 설정이 정한다.
    DATA lt_variant TYPE RANGE OF char30.

    IF is_selection-checkvariant IS NOT INITIAL.
      lt_variant = VALUE #( ( sign = 'I' option = 'EQ'
                              low  = is_selection-checkvariant ) ).
    ELSE.
      lt_variant = VALUE #( FOR ls_cfg IN zcl_atc_config=>get( )->get_active_variants( )
                            ( sign = 'I' option = 'EQ' low = ls_cfg-checkvariant ) ).
    ENDIF.

    " 활성 변형이 하나도 없으면 대상이 없다는 뜻이다. 조건 없이 전체를 읽지 않는다.
    IF lt_variant IS INITIAL.
      RETURN.
    ENDIF.

    SELECT FROM satc_api_findings
      FIELDS checkvariant,
             devclass,
             objecttype,
             objectname,
             lineno,
             resultid,
             itemid,
             checkrunindex,
             checkid,
             messageid,
             priority,
             msgtext,
             contactperson,
             responsible
      WHERE checkvariant IN @lt_variant
        AND ( devclass   IN @lt_devclass      OR @lt_devclass IS INITIAL )
        AND ( objecttype  = @is_selection-objecttype OR @is_selection-objecttype IS INITIAL )
        AND ( objectname  = @is_selection-objectname OR @is_selection-objectname IS INITIAL )
        AND ( checkid     = @is_selection-checkid    OR @is_selection-checkid    IS INITIAL )
        AND ( messageid   = @is_selection-messageid  OR @is_selection-messageid  IS INITIAL )
        " 경로 1 : 담당자 본인 건만. 경로 2 : 조건 자체를 무력화한다.
        AND ( @is_selection-only_mine = @abap_false
              OR contactperson = @sy-uname
              OR responsible   = @sy-uname )
      INTO CORRESPONDING FIELDS OF TABLE @rt_finding
      UP TO @iv_max_rows ROWS.

  ENDMETHOD.


  METHOD simulate_impact.

    DATA ls_selection TYPE zif_atc_exemption=>ty_selection.

    " 영향도는 담당자와 무관하게 범위 전체를 봐야 하므로 항상 경로 2 로 읽는다.
    ls_selection = VALUE #( checkvariant = iv_checkvariant
                            checkid      = iv_checkid
                            messageid    = iv_messageid
                            only_mine    = abap_false ).

    CASE iv_scopetype.

      WHEN zif_atc_exemption=>scope-pckg.
        " 패키지 전체. 여기서 나오는 건수가 곧 "신청서에 없던 건까지 몇 개 풀리는가" 다.
        ls_selection-devclass   = iv_devclass.
        ls_selection-inclsubpkg = iv_inclsubpkg.

      WHEN zif_atc_exemption=>scope-obj.
        ls_selection-devclass   = iv_devclass.
        ls_selection-objecttype = iv_objecttype.
        ls_selection-objectname = iv_objectname.

      WHEN OTHERS.
        " FND 는 신청서에 담긴 그 건 자체이므로 시뮬레이션 대상이 아니다.
        RETURN.

    ENDCASE.

    rt_finding = select( ls_selection ).

  ENDMETHOD.


  METHOD expand_packages.

    " TODO 확인 필요: TDEVC 의 API State. ABAP Cloud 에서 직접 SELECT 가 막히면
    "   패키지 계층 조회용 released CDS 뷰로 교체한다.

    DATA lt_parent TYPE zif_atc_exemption=>tt_devclass.
    DATA lt_child  TYPE zif_atc_exemption=>tt_devclass.
    DATA lt_next   TYPE zif_atc_exemption=>tt_devclass.

    IF iv_devclass IS INITIAL.
      RETURN.
    ENDIF.

    APPEND iv_devclass TO rt_devclass.

    IF iv_inclsubpkg = abap_false.
      RETURN.
    ENDIF.

    lt_parent = rt_devclass.

    " 상위-하위 관계를 한 단계씩 따라 내려간다.
    WHILE lt_parent IS NOT INITIAL.

      CLEAR: lt_child, lt_next.

      SELECT devclass
        FROM tdevc
        FOR ALL ENTRIES IN @lt_parent
        WHERE parentcl = @lt_parent-table_line
        INTO TABLE @lt_child.

      " 이미 담은 패키지는 건너뛴다. 순환 참조가 있어도 루프가 멈춘다.
      LOOP AT lt_child INTO DATA(lv_child).
        IF NOT line_exists( rt_devclass[ table_line = lv_child ] ).
          APPEND lv_child TO rt_devclass.
          APPEND lv_child TO lt_next.
        ENDIF.
      ENDLOOP.

      lt_parent = lt_next.

    ENDWHILE.

  ENDMETHOD.

ENDCLASS.
