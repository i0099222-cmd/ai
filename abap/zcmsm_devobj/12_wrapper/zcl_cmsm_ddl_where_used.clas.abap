"! [Standard ABAP · Cloud 개발용 릴리즈(C1)] CDS 사용처 찾기 래퍼
"!
"! 표준 테이블 DDLS_RIS_INDEX(CDS 사용처 인덱스 — ADT·SE11 사용처 목록이 읽는 테이블)를 읽는다.
"!   CDS 를 활성화할 때 SAP(CL_WB_DDLS_RIS_INDEXER)가 'DDL 소스 → 그 소스가 쓰는 오브젝트'를 한 줄씩 적어 둔다
"!   → 오브젝트 이름 하나로 바로 찾는다 (소스 텍스트 검색 아님). view entity, select from·join·연관·composition 다 들어 있다
"!   1) 인덱스에서 오브젝트를 쓰는 Z DDL 소스 이름
"!   2) 인덱스엔 '어떻게' 쓰는지가 없어서, 걸린 소스 몇 개만 원문(DDDDLSRC)을 읽어 쓰는 방식 구분: 데이터 소스 / join / 연관 / 기타
"! 인덱스에 빠진 CDS 가 있으면: 개발 시스템에서 SE38 SDDIC_DDLS_INDEX_ALL_SOURCES 를 한 번 실행 (CDS 인덱스 다시 만듦, 배치 등록 아님)
"! 만드는 곳: ABAP 언어 버전 'Standard ABAP' 패키지 (앱 패키지(ABAP Cloud)에서는 두 테이블 다 못 읽음)
"! 릴리즈: ADT → Properties → API State → Use in Cloud Development = Released
"! 기술부채로 등록: 개발 오브젝트 ZCL_CMSM_DDL_WHERE_USED, 부채 구분 TAB(미릴리즈 테이블 조회), Debt Level C, 래핑 여부 W
CLASS zcl_cmsm_ddl_where_used DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_usage,
        ddlname TYPE c LENGTH 40,   " 쓰는 CDS (DDL 소스 이름)
        kind    TYPE c LENGTH 20,   " 데이터 소스 / join / 연관 / 기타 (여러 개면 · 로)
      END OF ty_usage,
      tt_usage TYPE STANDARD TABLE OF ty_usage WITH EMPTY KEY.

    "! 오브젝트(테이블·CDS 등)를 쓰는 Z CDS 목록
    CLASS-METHODS find
      IMPORTING iv_name         TYPE string
      RETURNING VALUE(rt_usage) TYPE tt_usage.

ENDCLASS.


CLASS zcl_cmsm_ddl_where_used IMPLEMENTATION.

  METHOD find.

    DATA lt_kind TYPE string_table.
    DATA lr_ddl  TYPE RANGE OF ddlname.

    DATA(lv_name) = to_upper( condense( iv_name ) ).
    IF lv_name IS INITIAL OR strlen( lv_name ) > 40.
      RETURN.
    ENDIF.
    DATA(lv_self) = CONV ddlname( lv_name ).

    " 1) 사용처 인덱스: 이 오브젝트를 쓰는 Z DDL 소스
    "    USED_ARTIFACT_FULLNAME = '\TY:' + 이름 (예: \TY:ZT0001, 테이블·CDS 는 TY). 백따옴표라 \ 그대로
    DATA(lv_full) = `\TY:` && lv_name.
    SELECT DISTINCT ddlsrc_name
      FROM ddls_ris_index
      WHERE used_artifact_fullname = @lv_full
        AND ddlsrc_name LIKE 'Z%'
        AND ddlsrc_name <> @lv_self                       " 자기 자신(자기 연관 등)은 뺀다
      INTO TABLE @DATA(lt_ddl).
    IF lt_ddl IS INITIAL.
      RETURN.
    ENDIF.

    " 2) 걸린 소스만 원문을 읽는다 (몇 건)
    lr_ddl = VALUE #( FOR ls_d IN lt_ddl ( sign = 'I' option = 'EQ' low = ls_d-ddlsrc_name ) ).
    SELECT ddlname, source
      FROM ddddlsrc
      WHERE ddlname  IN @lr_ddl
        AND as4local = 'A'
      INTO TABLE @DATA(lt_source).

    " 쓰는 방식 정규식 — 이름 뒤가 이름 글자(A-Z 0-9 _ /)가 아니어야 (ZT0001 ≠ ZT00010). 백따옴표라 \ 그대로
    DATA(lv_from) = `\b(from|projection\s+on)\s+` && lv_name && `(?![A-Z0-9_/])`.   " select from / as projection on
    DATA(lv_join) = `\bjoin\s+` && lv_name && `(?![A-Z0-9_/])`.
    DATA(lv_to)   = `\b(to\s+(parent\s+)?|of\s+)` && lv_name && `(?![A-Z0-9_/])`.  " association … to / composition … of

    LOOP AT lt_ddl INTO DATA(ls_ddl).

      CLEAR lt_kind.
      READ TABLE lt_source INTO DATA(ls_source) WITH KEY ddlname = ls_ddl-ddlsrc_name.
      IF sy-subrc = 0.
        FIND FIRST OCCURRENCE OF PCRE lv_from IN ls_source-source IGNORING CASE.
        IF sy-subrc = 0.
          APPEND `데이터 소스` TO lt_kind.
        ENDIF.
        FIND FIRST OCCURRENCE OF PCRE lv_join IN ls_source-source IGNORING CASE.
        IF sy-subrc = 0.
          APPEND `join` TO lt_kind.
        ENDIF.
        FIND FIRST OCCURRENCE OF PCRE lv_to IN ls_source-source IGNORING CASE.
        IF sy-subrc = 0.
          APPEND `연관` TO lt_kind.
        ENDIF.
      ENDIF.
      IF lt_kind IS INITIAL.
        APPEND `기타` TO lt_kind.                          " 어노테이션(값 도움말 등)·캐스트 등
      ENDIF.

      APPEND VALUE #( ddlname = ls_ddl-ddlsrc_name
                      kind    = concat_lines_of( table = lt_kind sep = `·` ) ) TO rt_usage.

    ENDLOOP.

    SORT rt_usage BY ddlname.

  ENDMETHOD.

ENDCLASS.
