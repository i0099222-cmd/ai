"! [Standard ABAP · Cloud 개발용 릴리즈(C1)] CDS 사용처 찾기 래퍼
"!
"! ABAP Cloud 에서는 못 읽는 표준 테이블 DDDDLSRC(CDS 소스 원문)를 대신 읽는다.
"!   1) DB(HANA)가 활성 Z CDS 소스 중 오브젝트 이름이 '단어'로 들어간 것만 골라 준다 (AMDP, 대소문자 무시)
"!      → Z CDS 소스 전체를 앱 서버로 가져오지 않는다
"!   2) 걸린 소스만 ABAP 에서 쓰는 방식 구분: 데이터 소스 / join / 연관 / 기타
"! 만드는 곳: ABAP 언어 버전 'Standard ABAP' 패키지 (앱 패키지(ABAP Cloud)에서는 DDDDLSRC·AMDP 를 못 씀)
"! 릴리즈: ADT → Properties → API State → Use in Cloud Development = Released
"! 기술부채로 등록: 개발 오브젝트 ZCL_CMSM_DDL_WHERE_USED, 부채 구분 TAB(미릴리즈 테이블 조회), Debt Level C, 래핑 여부 W
CLASS zcl_cmsm_ddl_where_used DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_amdp_marker_hdb.

    TYPES:
      BEGIN OF ty_usage,
        ddlname TYPE c LENGTH 40,   " 쓰는 CDS (DDL 소스 이름)
        kind    TYPE c LENGTH 20,   " 데이터 소스 / join / 연관 / 기타 (여러 개면 · 로)
      END OF ty_usage,
      tt_usage TYPE STANDARD TABLE OF ty_usage WITH EMPTY KEY,

      BEGIN OF ty_source,
        ddlname TYPE c LENGTH 40,
        source  TYPE string,
      END OF ty_source,
      tt_source TYPE STANDARD TABLE OF ty_source WITH EMPTY KEY.

    "! 오브젝트(테이블·CDS 등)를 쓰는 Z CDS 목록
    CLASS-METHODS find
      IMPORTING iv_name         TYPE string
      RETURNING VALUE(rt_usage) TYPE tt_usage.

    "! (find 안에서만 씀) DB 에서 소스 원문을 정규식으로 걸러 일치하는 Z CDS 소스만 — AMDP 는 메서드로 따로 둬야 해서
    CLASS-METHODS select_sources
      IMPORTING VALUE(iv_pattern) TYPE string
      EXPORTING VALUE(et_source)  TYPE tt_source.

ENDCLASS.


CLASS zcl_cmsm_ddl_where_used IMPLEMENTATION.

  METHOD find.

    DATA lt_kind TYPE string_table.

    DATA(lv_name) = to_upper( condense( iv_name ) ).
    IF lv_name IS INITIAL.
      RETURN.
    ENDIF.

    " 정규식 — 앞뒤가 이름 글자(A-Z 0-9 _ /)가 아니어야 '단어'로 본다 (ZT0001 ≠ ZT00010). 백따옴표라 \ 그대로
    DATA(lv_any)  = `(?<![A-Z0-9_/])` && lv_name && `(?![A-Z0-9_/])`.
    DATA(lv_from) = `\b(from|projection\s+on)\s+` && lv_name && `(?![A-Z0-9_/])`.   " select from / as projection on
    DATA(lv_join) = `\bjoin\s+` && lv_name && `(?![A-Z0-9_/])`.
    DATA(lv_to)   = `\bto\s+(parent\s+)?` && lv_name && `(?![A-Z0-9_/])`.         " association / composition … to

    " 1) DB 가 이름이 들어간 소스만 골라 준다
    select_sources( EXPORTING iv_pattern = lv_any
                    IMPORTING et_source  = DATA(lt_source) ).

    " 2) 걸린 소스만 쓰는 방식 구분
    LOOP AT lt_source INTO DATA(ls_source).

      IF to_upper( ls_source-ddlname ) = lv_name.     " 자기 자신은 뺀다
        CONTINUE.
      ENDIF.

      CLEAR lt_kind.
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
      IF lt_kind IS INITIAL.
        APPEND `기타` TO lt_kind.                      " 어노테이션·주석 등에만 이름이 있음
      ENDIF.

      APPEND VALUE #( ddlname = ls_source-ddlname
                      kind    = concat_lines_of( table = lt_kind sep = `·` ) ) TO rt_usage.

    ENDLOOP.

    SORT rt_usage BY ddlname.

  ENDMETHOD.


  METHOD select_sources BY DATABASE PROCEDURE FOR HDB LANGUAGE SQLSCRIPT
                        OPTIONS READ-ONLY
                        USING ddddlsrc.
    -- 활성(A) Z CDS 소스 중 정규식에 걸리는 것만 (FLAG 'i' = 대소문자 무시)
    -- 이 줄에서 에러가 나면(긴 텍스트 칸에 LIKE_REGEXPR 미지원) 아래 주석 줄로 바꾼다:
    --   AND LOCATE( UPPER( source ), UPPER( :iv_pattern_name ) ) > 0   (이 경우 파라미터에 이름만 넘긴다)
    et_source = SELECT ddlname, source
                  FROM ddddlsrc
                 WHERE as4local = 'A'
                   AND ddlname LIKE 'Z%'
                   AND source LIKE_REGEXPR :iv_pattern FLAG 'i';
  ENDMETHOD.

ENDCLASS.
