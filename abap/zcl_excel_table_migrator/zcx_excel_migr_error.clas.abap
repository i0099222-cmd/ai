"! 화이트리스트에 없거나 권한이 없는 테이블 지정, 잡 예약 실패 등
"! 엑셀 마이그레이션 접수 단계에서 발생하는 예외.
CLASS zcx_excel_migr_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_t100_message.

    CONSTANTS:
      BEGIN OF table_not_allowed,
        msgid TYPE symsgid VALUE 'ZEXCEL_MIGR',
        msgno TYPE symsgno VALUE '001',
        attr1 TYPE scx_attrname VALUE 'TABNAME',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF table_not_allowed,

      BEGIN OF job_schedule_failed,
        msgid TYPE symsgid VALUE 'ZEXCEL_MIGR',
        msgno TYPE symsgno VALUE '002',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF job_schedule_failed.

    DATA tabname TYPE tabname.

    METHODS constructor
      IMPORTING
        textid   LIKE if_t100_message=>t100key OPTIONAL
        previous LIKE previous OPTIONAL
        tabname  TYPE tabname OPTIONAL.

ENDCLASS.


CLASS zcx_excel_migr_error IMPLEMENTATION.

  METHOD constructor.
    super->constructor( previous = previous ).
    me->tabname = tabname.

    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
