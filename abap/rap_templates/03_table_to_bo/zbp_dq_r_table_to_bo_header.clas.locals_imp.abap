CLASS lhc_orderheader DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    CONSTANTS c_status_closed TYPE zdq_r_table_to_bo_header-OrderStatus VALUE '03'.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR OrderHeader RESULT result.

    METHODS checksupplier FOR VALIDATE ON SAVE
      IMPORTING keys FOR OrderHeader~checkSupplier.

    METHODS closeorder FOR MODIFY
      IMPORTING keys FOR ACTION OrderHeader~closeOrder RESULT result.

ENDCLASS.


CLASS lhc_orderheader IMPLEMENTATION.

  METHOD get_global_authorizations.
    " 템플릿은 전역 허용. 실제 프로젝트에서는 AUTHORITY-CHECK 결과로 대체한다.
    result-%create            = if_abap_behv=>auth-allowed.
    result-%update            = if_abap_behv=>auth-allowed.
    result-%delete            = if_abap_behv=>auth-allowed.
    result-%action-closeOrder = if_abap_behv=>auth-allowed.
    result-%assoc-_Item       = if_abap_behv=>auth-allowed.
  ENDMETHOD.


  METHOD checksupplier.
    READ ENTITIES OF zdq_r_table_to_bo_header IN LOCAL MODE
      ENTITY OrderHeader
        FIELDS ( Supplier )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    LOOP AT orders INTO DATA(order) WHERE Supplier IS INITIAL.
      APPEND VALUE #( %tky = order-%tky ) TO failed-orderheader.
      APPEND VALUE #( %tky              = order-%tky
                      %state_area       = 'CHECK_SUPPLIER'
                      %element-Supplier = if_abap_behv=>mk-on
                      %msg              = new_message_with_text(
                                            severity = if_abap_behv_message=>severity-error
                                            text     = '공급업체를 입력하십시오.' ) )
             TO reported-orderheader.
    ENDLOOP.
  ENDMETHOD.


  METHOD closeorder.
    MODIFY ENTITIES OF zdq_r_table_to_bo_header IN LOCAL MODE
      ENTITY OrderHeader
        UPDATE FIELDS ( OrderStatus )
        WITH VALUE #( FOR key IN keys ( %tky        = key-%tky
                                        OrderStatus = c_status_closed ) )
      FAILED failed
      REPORTED reported.

    READ ENTITIES OF zdq_r_table_to_bo_header IN LOCAL MODE
      ENTITY OrderHeader
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    result = VALUE #( FOR order IN orders ( %tky   = order-%tky
                                            %param = order ) ).
  ENDMETHOD.

ENDCLASS.


CLASS lhc_orderitem DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS calctotalamount FOR DETERMINE ON SAVE
      IMPORTING keys FOR OrderItem~calcTotalAmount.

ENDCLASS.


CLASS lhc_orderitem IMPLEMENTATION.

  METHOD calctotalamount.
    DATA header_keys TYPE TABLE FOR READ IMPORT zdq_r_table_to_bo_header\\OrderHeader.
    DATA updates     TYPE TABLE FOR UPDATE      zdq_r_table_to_bo_header\\OrderHeader.

    " 변경/삭제된 아이템이 속한 헤더만 골라낸다.
    header_keys = VALUE #( FOR key IN keys ( OrderId = key-OrderId ) ).
    SORT header_keys BY OrderId.
    DELETE ADJACENT DUPLICATES FROM header_keys COMPARING OrderId.

    " 헤더까지 삭제된 경우(하위 아이템 연쇄 삭제)는 재계산 대상에서 빠진다.
    READ ENTITIES OF zdq_r_table_to_bo_header IN LOCAL MODE
      ENTITY OrderHeader
        FIELDS ( OrderId )
        WITH CORRESPONDING #( header_keys )
      RESULT DATA(headers).

    CHECK headers IS NOT INITIAL.

    READ ENTITIES OF zdq_r_table_to_bo_header IN LOCAL MODE
      ENTITY OrderHeader BY \_Item
        FIELDS ( NetAmount )
        WITH CORRESPONDING #( headers )
      RESULT DATA(items).

    LOOP AT headers INTO DATA(header).
      DATA(total) = REDUCE zdq_tordhdr-total_amount(
                      INIT sum = CONV zdq_tordhdr-total_amount( 0 )
                      FOR item IN items WHERE ( OrderId = header-OrderId )
                      NEXT sum = sum + item-NetAmount ).

      APPEND VALUE #( OrderId = header-OrderId TotalAmount = total ) TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zdq_r_table_to_bo_header IN LOCAL MODE
      ENTITY OrderHeader
        UPDATE FIELDS ( TotalAmount )
        WITH updates
      REPORTED DATA(update_reported).
  ENDMETHOD.

ENDCLASS.
