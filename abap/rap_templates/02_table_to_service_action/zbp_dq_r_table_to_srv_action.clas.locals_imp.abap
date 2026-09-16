CLASS lhc_purchaseorder DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    CONSTANTS:
      BEGIN OF c_status,
        created  TYPE zdq_r_table_to_srv_action-OrderStatus VALUE '01',
        released TYPE zdq_r_table_to_srv_action-OrderStatus VALUE '02',
      END OF c_status.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR PurchaseOrder RESULT result.

    METHODS setinitialstatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR PurchaseOrder~setInitialStatus.

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
