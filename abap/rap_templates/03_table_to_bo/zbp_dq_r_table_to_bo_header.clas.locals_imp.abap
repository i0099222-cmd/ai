CLASS lhc_orderheader DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    CONSTANTS c_status_closed TYPE zdq_r_table_to_bo_header-OrderStatus VALUE '03'.
    CONSTANTS c_nr_object     TYPE cl_numberrange_runtime=>nr_object    VALUE 'ZDQ_ORDER'.
    CONSTANTS c_nr_range      TYPE cl_numberrange_runtime=>nr_range_nr  VALUE '01'.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR OrderHeader RESULT result.

    METHODS checksupplier FOR VALIDATE ON SAVE
      IMPORTING keys FOR OrderHeader~checkSupplier.

    METHODS setordernumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR OrderHeader~setOrderNumber.

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


  METHOD setordernumber.
    DATA updates TYPE TABLE FOR UPDATE zdq_r_table_to_bo_header\\OrderHeader.

    " 키는 UUID 이므로 업무 번호는 저장 시점에 번호범위에서 채번한다.
    READ ENTITIES OF zdq_r_table_to_bo_header IN LOCAL MODE
      ENTITY OrderHeader
        FIELDS ( OrderId )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DELETE orders WHERE OrderId IS NOT INITIAL.
    CHECK orders IS NOT INITIAL.

    TRY.
        cl_numberrange_runtime=>number_get(
          EXPORTING
            nr_range_nr       = c_nr_range
            object            = c_nr_object
            quantity          = CONV #( lines( orders ) )
          IMPORTING
            number            = DATA(last_number)
            returned_quantity = DATA(assigned_quantity) ).

      CATCH cx_number_ranges INTO DATA(number_error).
        LOOP AT orders INTO DATA(rejected).
          APPEND VALUE #( %tky = rejected-%tky ) TO failed-orderheader.
          APPEND VALUE #( %tky = rejected-%tky
                          %msg = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = number_error->get_text( ) ) )
                 TO reported-orderheader.
        ENDLOOP.
        RETURN.
    ENDTRY.

    " 채번은 블록의 '마지막' 번호를 돌려주므로 시작 번호를 역산한다.
    DATA(number) = CONV i( last_number ) - CONV i( assigned_quantity ).

    LOOP AT orders INTO DATA(order).
      number += 1.
      APPEND VALUE #( %tky    = order-%tky
                      OrderId = |{ number WIDTH = 10 PAD = '0' ALIGN = RIGHT }| )
             TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zdq_r_table_to_bo_header IN LOCAL MODE
      ENTITY OrderHeader
        UPDATE FIELDS ( OrderId )
        WITH updates
      REPORTED DATA(update_reported).
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

    METHODS setitemnumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR OrderItem~setItemNumber.

    METHODS calctotalamount FOR DETERMINE ON SAVE
      IMPORTING keys FOR OrderItem~calcTotalAmount.

ENDCLASS.


CLASS lhc_orderitem IMPLEMENTATION.

  METHOD setitemnumber.
    DATA header_keys TYPE TABLE FOR READ IMPORT zdq_r_table_to_bo_header\\OrderHeader.
    DATA updates     TYPE TABLE FOR UPDATE      zdq_r_table_to_bo_header\\OrderItem.

    " 아이템 키가 UUID 이므로 업무 번호는 저장 시점에 부여한다.
    READ ENTITIES OF zdq_r_table_to_bo_header IN LOCAL MODE
      ENTITY OrderItem
        FIELDS ( ItemNo )
        WITH CORRESPONDING #( keys )
      RESULT DATA(new_items).

    DELETE new_items WHERE ItemNo IS NOT INITIAL.
    CHECK new_items IS NOT INITIAL.

    header_keys = VALUE #( FOR item IN new_items ( OrderUUID = item-OrderUUID ) ).
    SORT header_keys BY OrderUUID.
    DELETE ADJACENT DUPLICATES FROM header_keys COMPARING OrderUUID.

    " 같은 헤더의 기존 아이템 번호(버퍼 포함)를 읽어 최대값 다음부터 부여한다.
    READ ENTITIES OF zdq_r_table_to_bo_header IN LOCAL MODE
      ENTITY OrderHeader BY \_Item
        FIELDS ( ItemNo )
        WITH CORRESPONDING #( header_keys )
      RESULT DATA(all_items).

    LOOP AT header_keys INTO DATA(header).
      DATA(next_no) = REDUCE i(
        INIT max = 0
        FOR existing IN all_items WHERE ( OrderUUID = header-OrderUUID )
        NEXT max = COND i( WHEN existing-ItemNo > max THEN CONV i( existing-ItemNo ) ELSE max ) ).

      LOOP AT new_items INTO DATA(new_item) WHERE OrderUUID = header-OrderUUID.
        next_no += 10.
        APPEND VALUE #( %tky = new_item-%tky ItemNo = next_no ) TO updates.
      ENDLOOP.
    ENDLOOP.

    MODIFY ENTITIES OF zdq_r_table_to_bo_header IN LOCAL MODE
      ENTITY OrderItem
        UPDATE FIELDS ( ItemNo )
        WITH updates
      REPORTED DATA(update_reported).
  ENDMETHOD.


  METHOD calctotalamount.
    DATA header_keys TYPE TABLE FOR READ IMPORT zdq_r_table_to_bo_header\\OrderHeader.
    DATA updates     TYPE TABLE FOR UPDATE      zdq_r_table_to_bo_header\\OrderHeader.

    " OrderUUID 가 아이템 키의 일부이므로 삭제된 아이템도 부모를 알 수 있다.
    header_keys = VALUE #( FOR key IN keys ( OrderUUID = key-OrderUUID ) ).
    SORT header_keys BY OrderUUID.
    DELETE ADJACENT DUPLICATES FROM header_keys COMPARING OrderUUID.

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
      DATA(total) = REDUCE zdq_tordhdr-totalamount(
                      INIT sum = CONV zdq_tordhdr-totalamount( 0 )
                      FOR item IN items WHERE ( OrderUUID = header-OrderUUID )
                      NEXT sum = sum + item-NetAmount ).

      APPEND VALUE #( OrderUUID = header-OrderUUID TotalAmount = total ) TO updates.
    ENDLOOP.

    MODIFY ENTITIES OF zdq_r_table_to_bo_header IN LOCAL MODE
      ENTITY OrderHeader
        UPDATE FIELDS ( TotalAmount )
        WITH updates
      REPORTED DATA(update_reported).
  ENDMETHOD.

ENDCLASS.
