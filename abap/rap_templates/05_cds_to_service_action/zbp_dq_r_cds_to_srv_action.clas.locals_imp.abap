CLASS lhc_productreview DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    CONSTANTS c_status_approved TYPE zdq_r_cds_to_srv_action-ReviewStatus VALUE '03'.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR ProductReview RESULT result.

    METHODS approvereview FOR MODIFY
      IMPORTING keys FOR ACTION ProductReview~approveReview RESULT result.

ENDCLASS.


CLASS lhc_productreview IMPLEMENTATION.

  METHOD get_global_authorizations.
    " 템플릿은 전역 허용. 실제 프로젝트에서는 AUTHORITY-CHECK 결과로 대체한다.
    result-%update               = if_abap_behv=>auth-allowed.
    result-%action-approveReview = if_abap_behv=>auth-allowed.
  ENDMETHOD.


  METHOD approvereview.
    MODIFY ENTITIES OF zdq_r_cds_to_srv_action IN LOCAL MODE
      ENTITY ProductReview
        UPDATE FIELDS ( ReviewStatus )
        WITH VALUE #( FOR key IN keys ( %tky         = key-%tky
                                        ReviewStatus = c_status_approved ) )
      FAILED failed
      REPORTED reported.

    READ ENTITIES OF zdq_r_cds_to_srv_action IN LOCAL MODE
      ENTITY ProductReview
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(reviews).

    result = VALUE #( FOR review IN reviews ( %tky   = review-%tky
                                              %param = review ) ).
  ENDMETHOD.

ENDCLASS.


CLASS lsc_zdq_r_cds_to_srv_action DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save_modified REDEFINITION.

ENDCLASS.


CLASS lsc_zdq_r_cds_to_srv_action IMPLEMENTATION.

  METHOD save_modified.
    DATA reviews    TYPE STANDARD TABLE OF zdq_tprdrev WITH EMPTY KEY.
    DATA changed_at TYPE timestampl.

    DATA(changes) = update-productreview.
    CHECK changes IS NOT INITIAL.

    " 검토 레코드가 아직 없는 자재도 있으므로 현재 DB 상태를 먼저 읽는다.
    SELECT * FROM zdq_tprdrev
      FOR ALL ENTRIES IN @changes
      WHERE product = @changes-Product
      INTO TABLE @DATA(db_reviews).

    GET TIME STAMP FIELD changed_at.
    DATA(changed_by) = cl_abap_context_info=>get_user_technical_name( ).

    LOOP AT changes INTO DATA(changed).
      DATA(review) = VALUE zdq_tprdrev( product = changed-Product ).

      READ TABLE db_reviews INTO DATA(db_review) WITH KEY product = changed-Product.
      IF sy-subrc = 0.
        review = db_review.
      ELSE.
        review-created_by = changed_by.
        review-created_at = changed_at.
      ENDIF.

      " %control 이 켜진 필드만 반영한다.
      IF changed-%control-ReviewStatus = if_abap_behv=>mk-on.
        review-review_status = changed-ReviewStatus.
      ENDIF.
      IF changed-%control-ReviewNote = if_abap_behv=>mk-on.
        review-review_note = changed-ReviewNote.
      ENDIF.

      review-last_changed_by       = changed_by.
      review-last_changed_at       = changed_at.
      review-local_last_changed_at = changed_at.

      APPEND review TO reviews.
    ENDLOOP.

    " 신규/변경을 한 번에 처리 (upsert)
    MODIFY zdq_tprdrev FROM TABLE @reviews.
  ENDMETHOD.

ENDCLASS.
