"! [Standard ABAP · Cloud 개발용 릴리즈(C1)] CDS 사용처 찾기 래퍼
"!
"! ABAP Cloud 에서는 못 읽는 표준 테이블 DDDDLSRC(CDS 소스 원문)를 대신 읽는다.
"!   이름이 Z 로 시작하는 활성 CDS 소스 전부에서 오브젝트 이름을 '단어'로 찾아(ZT0001 ≠ ZT00010),
"!   쓰는 CDS 와 쓰는 방식(데이터 소스 / join / 연관 / 기타)을 돌려준다. join·연관·주석도 소스에 있으면 걸린다.
"! 만드는 곳: ABAP 언어 버전 'Standard ABAP' 패키지 (앱 패키지(ABAP Cloud)에서는 DDDDLSRC 를 못 읽음)
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

    DATA(lv_name) = to_upper( condense( iv_name ) ).
    IF lv_name IS INITIAL.
      RETURN.
    ENDIF.

    " 정규식 (대소문자 무시). 앞뒤가 이름 글자(A-Z 0-9 _ /)가 아니어야 '단어'로 본다
    "   백따옴표 리터럴이라 \ 를 그대로 쓴다
    DATA(lv_any)  = `(?<![A-Z0-9_/])` && lv_name && `(?![A-Z0-9_/])`.
    DATA(lv_from) = `\b(from|projection\s+on)\s+` && lv_name && `(?![A-Z0-9_/])`.   " select from / as projection on
    DATA(lv_join) = `\bjoin\s+` && lv_name && `(?![A-Z0-9_/])`.
    DATA(lv_to)   = `\bto\s+(parent\s+)?` && lv_name && `(?![A-Z0-9_/])`.         " association / composition … to

    " 활성(A) Z CDS 소스를 500 건씩 읽으며 찾는다 (소스가 길어서 한 번에 다 안 올린다)
    SELECT ddlname, source
      FROM ddddlsrc
      WHERE as4local = 'A'
        AND ddlname  LIKE 'Z%'
      INTO TABLE @DATA(lt_src)
      PACKAGE SIZE 500.

      LOOP AT lt_src INTO DATA(ls_src).

        IF ls_src-ddlname = lv_name.                 " 자기 자신은 뺀다
          CONTINUE.
        ENDIF.

        FIND FIRST OCCURRENCE OF PCRE lv_any IN ls_src-source IGNORING CASE.
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.

        CLEAR lt_kind.
        FIND FIRST OCCURRENCE OF PCRE lv_from IN ls_src-source IGNORING CASE.
        IF sy-subrc = 0.
          APPEND `데이터 소스` TO lt_kind.
        ENDIF.
        FIND FIRST OCCURRENCE OF PCRE lv_join IN ls_src-source IGNORING CASE.
        IF sy-subrc = 0.
          APPEND `join` TO lt_kind.
        ENDIF.
        FIND FIRST OCCURRENCE OF PCRE lv_to IN ls_src-source IGNORING CASE.
        IF sy-subrc = 0.
          APPEND `연관` TO lt_kind.
        ENDIF.
        IF lt_kind IS INITIAL.
          APPEND `기타` TO lt_kind.                    " 어노테이션·주석 등에만 이름이 있음
        ENDIF.

        APPEND VALUE #( ddlname = ls_src-ddlname
                        kind    = concat_lines_of( table = lt_kind sep = `·` ) ) TO rt_usage.

      ENDLOOP.

    ENDSELECT.

    SORT rt_usage BY ddlname.

  ENDMETHOD.

ENDCLASS.
