"! [Standard ABAP · Cloud 개발용 릴리즈(C1)] CDS 사용처·데이터 소스 래퍼
"!
"! find         : 오브젝트를 쓰는 Z CDS (매핑 상세 '사용처')
"!   표준 테이블 DDLS_RIS_INDEX(CDS 사용처 인덱스 — ADT·SE11 사용처 목록이 읽는 테이블)를 읽는다.
"!   CDS 를 활성화할 때 SAP(CL_WB_DDLS_RIS_INDEXER)가 'DDL 소스 → 그 소스가 쓰는 오브젝트'를 한 줄씩 적어 둔다
"!   → 오브젝트 이름 하나로 바로 찾는다 (소스 텍스트 검색 아님). view entity, select from·join·연관·composition 다 들어 있다
"!   1) 인덱스에서 오브젝트를 쓰는 Z DDL 소스 이름
"!   2) 인덱스엔 '어떻게' 쓰는지가 없어서, 걸린 소스 몇 개만 원문(DDDDLSRC)을 읽어 쓰는 방식 구분: 데이터 소스 / join / 연관 / 기타
"!   인덱스에 빠진 CDS 가 있으면: 개발 시스템에서 SE38 SDDIC_DDLS_INDEX_ALL_SOURCES 를 한 번 실행 (CDS 인덱스 다시 만듦, 배치 등록 아님)
"! source_chain : CDS 의 메인 데이터 소스를 최하위(테이블)까지 (매핑 상세 'To-Be 데이터 소스')
"!   CDS 소스 원문(DDDDLSRC)에서 'as select from X' / 'as projection on X' 의 X 를 읽고, X 도 CDS 면 X 의 원문을 또… 반복
"!   view entity·DDIC 기반 define view·projection·표준 SAP CDS(I_Product → MARA 등) 다 된다. 테이블인지는 DD02L 로 본다
"! 만드는 곳: ABAP 언어 버전 'Standard ABAP' 패키지 (앱 패키지(ABAP Cloud)에서는 이 테이블들을 못 읽음)
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
      tt_usage TYPE STANDARD TABLE OF ty_usage WITH EMPTY KEY,

      BEGIN OF ty_source,
        srclevel TYPE i,            " 단계 (1 = 바로 아래 소스)
        srckind  TYPE c LENGTH 20,  " CDS / 테이블 / DDIC 뷰 / 도메인 고정값 / 기타
        srcname  TYPE c LENGTH 40,  " 데이터 소스 이름 (도메인 고정값이면 도메인 이름)
        usedby   TYPE c LENGTH 40,  " 그 소스를 읽는 CDS (한 단계 위)
      END OF ty_source,
      tt_source TYPE STANDARD TABLE OF ty_source WITH EMPTY KEY.

    "! 오브젝트(테이블·CDS 등)를 쓰는 Z CDS 목록
    CLASS-METHODS find
      IMPORTING iv_name         TYPE string
      RETURNING VALUE(rt_usage) TYPE tt_usage.

    "! CDS 의 메인 데이터 소스를 최하위(테이블 등)까지 따라 내려간 목록 (단계 순, 최대 10단계)
    CLASS-METHODS source_chain
      IMPORTING iv_name          TYPE string
      RETURNING VALUE(rt_source) TYPE tt_source.

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


  METHOD source_chain.

    DATA lv_text   TYPE string.
    DATA lv_src    TYPE string.
    DATA lv_domain TYPE string.

    DATA(lv_cur) = to_upper( condense( iv_name ) ).

    DO 10 TIMES.                                           " 최대 10단계

      " 1) 지금 CDS 의 소스 원문 (없으면 CDS 가 아님 → 끝)
      IF lv_cur IS INITIAL OR strlen( lv_cur ) > 40.
        EXIT.
      ENDIF.
      CLEAR lv_text.
      SELECT SINGLE source
        FROM ddddlsrc
        WHERE ddlname  = @lv_cur
          AND as4local = 'A'
        INTO @lv_text.
      IF sy-subrc <> 0.
        EXIT.
      ENDIF.
      " 주석(// …, /* … */)은 지운다 — 주석 처리한 옛 select from 을 잡지 않게
      REPLACE ALL OCCURRENCES OF PCRE `//[^\n]*|/\*[\s\S]*?\*/` IN lv_text WITH ``.

      " 2) 메인 데이터 소스: 'as select [distinct] from X' / 'as projection on X' 의 X (union 이면 첫 번째)
      CLEAR lv_src.
      FIND FIRST OCCURRENCE OF PCRE `\bas\s+(?:select\s+(?:distinct\s+)?from|projection\s+on)\s+([A-Z0-9_/]+)`
        IN lv_text IGNORING CASE SUBMATCHES lv_src.
      IF sy-subrc <> 0.
        EXIT.                                              " custom entity·table function·hierarchy 등
      ENDIF.
      lv_src = to_upper( lv_src ).
      IF lv_src = lv_cur OR line_exists( rt_source[ srcname = lv_src ] ).
        EXIT.                                              " 순환
      ENDIF.

      " 3) 유형: CDS 면 계속 내려가고, 아니면 최하위
      SELECT SINGLE @abap_true
        FROM ddddlsrc
        WHERE ddlname  = @lv_src
          AND as4local = 'A'
        INTO @DATA(lv_found).
      DATA(lv_is_cds) = xsdbool( sy-subrc = 0 ).

      DATA(lv_name) = lv_src.
      DATA(lv_kind) = `CDS`.
      IF lv_src CP 'DDCDS_CUSTOMER_DOMAIN_VALUE*'.
        lv_kind = `도메인 고정값`.                            " 이름 칸엔 도메인 이름 (p_domain_name: 'ZDO_…')
        CLEAR lv_domain.
        FIND FIRST OCCURRENCE OF PCRE `p_domain_name\s*:\s*'([^']+)'` IN lv_text IGNORING CASE SUBMATCHES lv_domain.
        IF sy-subrc = 0.
          lv_name = to_upper( lv_domain ).
        ENDIF.
      ELSEIF lv_is_cds = abap_false.
        SELECT SINGLE tabclass
          FROM dd02l
          WHERE tabname  = @lv_src
            AND as4local = 'A'
          INTO @DATA(lv_tabclass).
        lv_kind = COND #( WHEN sy-subrc <> 0       THEN `기타`
                          WHEN lv_tabclass = 'VIEW' THEN `DDIC 뷰`
                          ELSE                           `테이블` ).
      ENDIF.

      APPEND VALUE #( srclevel = lines( rt_source ) + 1
                      srckind  = lv_kind
                      srcname  = lv_name
                      usedby   = lv_cur ) TO rt_source.

      IF lv_kind <> `CDS`.
        EXIT.                                              " 최하위
      ENDIF.
      lv_cur = lv_src.

    ENDDO.

  ENDMETHOD.

ENDCLASS.
