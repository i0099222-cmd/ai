"! Value Help 용 미공개 테이블 읽기 · Tier 2
"!
"! 패키지 언어 버전 = Standard ABAP (classic). ABAP Cloud 의 zcl_cmup_value_help 가 부른다.
"! release: API State → Use System-Internally (Contract C1) + Use in Cloud Development
CLASS zcl_cmup_vh_tier2 DEFINITION PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_value,
        code TYPE c LENGTH 40,
        text TYPE c LENGTH 80,
      END OF ty_value,
      tt_value TYPE STANDARD TABLE OF ty_value WITH EMPTY KEY.

    "! 로그온 언어 (T002 / T002T)
    "! 코드 = SAP 언어 키 (3, E …) = BAPI 가 주고받는 값, 텍스트 = 이름 + ISO (한국어 (KO))
    "! 설치된 언어만 보여줘야 하면 여기에 조건을 추가한다
    CLASS-METHODS get_languages
      RETURNING VALUE(rt_value) TYPE tt_value.

    "! 타임존 (TTZZ 활성 / TTZZT)
    CLASS-METHODS get_time_zones
      RETURNING VALUE(rt_value) TYPE tt_value.
ENDCLASS.


CLASS zcl_cmup_vh_tier2 IMPLEMENTATION.

  METHOD get_languages.
    SELECT l~spras AS code, l~laiso, t~sptxt
      FROM t002 AS l
        LEFT OUTER JOIN t002t AS t
          ON  t~sprsl = l~spras
          AND t~spras = @sy-langu
      WHERE l~laiso <> @space
      ORDER BY l~laiso
      INTO TABLE @DATA(lt_language).

    rt_value = VALUE #( FOR ls_language IN lt_language
                        ( code = ls_language-code
                          text = |{ ls_language-sptxt } ({ ls_language-laiso })| ) ).
  ENDMETHOD.


  METHOD get_time_zones.
    SELECT z~tzone AS code, t~descript AS text
      FROM ttzz AS z
        LEFT OUTER JOIN ttzzt AS t
          ON  t~tzone = z~tzone
          AND t~langu = @sy-langu
      WHERE z~flagactive = @abap_true
      ORDER BY z~tzone
      INTO CORRESPONDING FIELDS OF TABLE @rt_value.
  ENDMETHOD.

ENDCLASS.
