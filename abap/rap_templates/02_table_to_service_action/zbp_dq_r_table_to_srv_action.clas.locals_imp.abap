CLASS lhc_purchaseorder DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF c_status,
        created  TYPE zdq_r_table_to_srv_action-OrderStatus VALUE '01',
        released TYPE zdq_r_table_to_srv_action-OrderStatus VALUE '02',
        closed   TYPE zdq_r_table_to_srv_action-OrderStatus VALUE '03',
      END OF c_status.

    CONSTANTS c_nr_object TYPE cl_numberrange_runtime=>nr_object VALUE 'ZDQ_ORDER'.
    CONSTANTS c_nr_range  TYPE cl_numberrange_runtime=>nr_range_nr VALUE '01'.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR PurchaseOrder RESULT result.

    METHODS setinitialstatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR PurchaseOrder~setInitialStatus.

    METHODS setordernumber FOR DETERMINE ON SAVE
      IMPORTING keys FOR PurchaseOrder~setOrderNumber.

    METHODS releaseorder FOR MODIFY
      IMPORTING keys FOR ACTION PurchaseOrder~releaseOrder RESULT result.

    METHODS changestatus FOR MODIFY
      IMPORTING keys FOR ACTION PurchaseOrder~changeStatus RESULT result.

ENDCLASS.


CLASS lhc_purchaseorder IMPLEMENTATION.

  METHOD get_global_authorizations.
    " 템플릿은 전역 허용. 실제 프로젝트에서는 AUTHORITY-CHECK 결과로 대체한다.
    result-%create              = if_abap_behv=>auth-allowed.
    result-%update              = if_abap_behv=>auth-allowed.
    result-%delete              = if_abap_behv=>auth-allowed.
    result-%action-releaseOrder = if_abap_behv=>auth-allowed.
    result-%action-changeStatus = if_abap_behv=>auth-allowed.
  ENDMETHOD.


  METHOD setinitialstatus.
    " 생성 시 상태가 비어 있으면 '작성중'으로 채운다.
    READ ENTITIES OF zdq_r_table_to_srv_action IN LOCAL MODE
      ENTITY PurchaseOrder
        FIELDS ( OrderStatus )
        WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    DELETE orders WHERE OrderStatus IS NOT INITIAL.
    CHECK orders IS NOT INITIAL.

    MODIFY ENTITIES OF zdq_r_table_to_srv_action IN LOCAL MODE
      ENTITY PurchaseOrder
        UPDATE FIELDS ( OrderStatus )
        WITH VALUE #( FOR ord IN orders ( %tky        = ord-%tky
                                          OrderStatus = c_status-created ) )
      REPORTED DATA(update_reported).
  ENDMETHOD.


  METHOD setordernumber.
    DATA updates TYPE TABLE FOR UPDATE zdq_r_table_to_srv_action.

    " 키는 UUID 이므로 업무 번호는 저장 시점에 번호범위에서 채번한다.
    READ ENTITIES OF zdq_r_table_to_srv_action IN LOCAL MODE
      ENTITY PurchaseOrder
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
          APPEND VALUE #( %tky = rejected-%tky ) TO failed-purchaseorder.
          APPEND VALUE #( %tky = rejected-%tky
                          %msg = new_message_with_text(
                                   severity = if_abap_behv_message=>severity-error
                                   text     = number_error->get_text( ) ) )
                 TO reported-purchaseorder.
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

    MODIFY ENTITIES OF zdq_r_table_to_srv_action IN LOCAL MODE
      ENTITY PurchaseOrder
        UPDATE FIELDS ( OrderId )
        WITH updates
      REPORTED DATA(update_reported).
  ENDMETHOD.


  METHOD releaseorder.
    " IN LOCAL MODE 이므로 BDEF 의 readonly 제한을 받지 않는다.
    MODIFY ENTITIES OF zdq_r_table_to_srv_action IN LOCAL MODE
      ENTITY PurchaseOrder
        UPDATE FIELDS ( OrderStatus )
        WITH VALUE #( FOR key IN keys ( %tky        = key-%tky
                                        OrderStatus = c_status-released ) )
      FAILED failed
      REPORTED reported.

    READ ENTITIES OF zdq_r_table_to_srv_action IN LOCAL MODE
      ENTITY PurchaseOrder
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    result = VALUE #( FOR ord IN orders ( %tky   = ord-%tky
                                          %param = ord ) ).
  ENDMETHOD.


  METHOD changestatus.
    MODIFY ENTITIES OF zdq_r_table_to_srv_action IN LOCAL MODE
      ENTITY PurchaseOrder
        UPDATE FIELDS ( OrderStatus )
        WITH VALUE #( FOR key IN keys ( %tky        = key-%tky
                                        OrderStatus = key-%param-OrderStatus ) )
      FAILED failed
      REPORTED reported.

    READ ENTITIES OF zdq_r_table_to_srv_action IN LOCAL MODE
      ENTITY PurchaseOrder
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(orders).

    result = VALUE #( FOR ord IN orders ( %tky   = ord-%tky
                                          %param = ord ) ).
  ENDMETHOD.

ENDCLASS.
