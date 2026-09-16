"! 저장 전 변경분을 담아두는 트랜잭션 버퍼 (unmanaged 이므로 직접 관리)
CLASS lcl_review_buffer DEFINITION.
  PUBLIC SECTION.
    TYPES tt_review TYPE SORTED TABLE OF zdq_tprdrev WITH UNIQUE KEY product.
    CLASS-DATA changes TYPE tt_review.
ENDCLASS.

CLASS lcl_review_buffer IMPLEMENTATION.
ENDCLASS.


CLASS lhc_productreview DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    CONSTANTS c_status_approved TYPE zdq_tprdrev-reviewstatus VALUE '03'.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR ProductReview RESULT result.

    METHODS read FOR READ
      IMPORTING keys FOR READ ProductReview RESULT result.

    METHODS lock FOR LOCK
      IMPORTING keys FOR LOCK ProductReview.

    METHODS approvereview FOR MODIFY
      IMPORTING keys FOR ACTION ProductReview~approveReview RESULT result.

ENDCLASS.


CLASS lhc_productreview IMPLEMENTATION.

  METHOD get_global_authorizations.
    " 템플릿은 전역 허용. 실제 프로젝트에서는 AUTHORITY-CHECK 결과로 대체한다.
    result-%action-approveReview = if_abap_behv=>auth-allowed.
  ENDMETHOD.


  METHOD read.
    SELECT FROM I_Product AS prd
           LEFT OUTER JOIN zdq_tprdrev AS rev
             ON rev~product = prd~Product
           LEFT OUTER JOIN I_ProductDescription AS txt
             ON  txt~Product  = prd~Product
             AND txt~Language = @sy-langu
      FIELDS prd~Product            AS product,
             txt~ProductDescription AS productdescription,
             prd~ProductType        AS producttype,
             rev~reviewstatus       AS reviewstatus,
             rev~reviewnote         AS reviewnote,
             rev~last_changed_by    AS lastchangedby,
             rev~last_changed_at    AS lastchangedat
      FOR ALL ENTRIES IN @keys
      WHERE prd~Product = @keys-Product
      INTO CORRESPONDING FIELDS OF TABLE @result.

    " 아직 저장되지 않은 변경분을 덮어쓴다.
    LOOP AT result ASSIGNING FIELD-SYMBOL(<review>).
      READ TABLE lcl_review_buffer=>changes INTO DATA(buffered)
           WITH TABLE KEY product = <review>-Product.
      IF sy-subrc = 0.
        <review>-ReviewStatus  = buffered-reviewstatus.
        <review>-ReviewNote    = buffered-reviewnote.
        <review>-LastChangedBy = buffered-last_changed_by.
        <review>-LastChangedAt = buffered-last_changed_at.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD lock.
    " 잠금 오브젝트 EZDQ_TPRDREV 필요 (00_common/ezdq_tprdrev.enqu.md 참고).
    " 파라미터명은 생성된 함수모듈 시그니처에 맞춘다.
    LOOP AT keys INTO DATA(key).
      CALL FUNCTION 'ENQUEUE_EZDQ_TPRDREV'
        EXPORTING
          mode_zdq_tprdrev = 'E'
          product          = key-Product
        EXCEPTIONS
          foreign_lock     = 1
          system_failure   = 2
          OTHERS           = 3.

      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = key-%tky ) TO failed-productreview.
        APPEND VALUE #( %tky = key-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = '다른 사용자가 처리 중인 자재입니다.' ) )
               TO reported-productreview.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD approvereview.
    DATA changed_at TYPE timestampl.

    GET TIME STAMP FIELD changed_at.
    DATA(changed_by) = cl_abap_context_info=>get_user_technical_name( ).

    " DB 쓰기는 saver 에서 수행하고, 여기서는 버퍼에만 반영한다.
    LOOP AT keys INTO DATA(key).
      DELETE lcl_review_buffer=>changes WHERE product = key-Product.
      INSERT VALUE #( product               = key-Product
                      reviewstatus          = c_status_approved
                      last_changed_by       = changed_by
                      last_changed_at       = changed_at
                      local_last_changed_at = changed_at )
             INTO TABLE lcl_review_buffer=>changes.
    ENDLOOP.

    READ ENTITIES OF zdq_ce_custom_ent_action IN LOCAL MODE
      ENTITY ProductReview
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(reviews).

    result = VALUE #( FOR review IN reviews ( %tky   = review-%tky
                                              %param = review ) ).
  ENDMETHOD.

ENDCLASS.


CLASS lsc_zdq_ce_custom_ent_action DEFINITION INHERITING FROM cl_abap_behavior_saver.

  PROTECTED SECTION.

    METHODS save    REDEFINITION.
    METHODS cleanup REDEFINITION.

ENDCLASS.


CLASS lsc_zdq_ce_custom_ent_action IMPLEMENTATION.

  METHOD save.
    DATA reviews TYPE STANDARD TABLE OF zdq_tprdrev WITH EMPTY KEY.

    DATA(changes) = lcl_review_buffer=>changes.
    CHECK changes IS NOT INITIAL.

    SELECT * FROM zdq_tprdrev
      FOR ALL ENTRIES IN @changes
      WHERE product = @changes-product
      INTO TABLE @DATA(db_reviews).

    LOOP AT changes INTO DATA(change).
      DATA(review) = change.

      READ TABLE db_reviews INTO DATA(db_review) WITH KEY product = change-product.
      IF sy-subrc = 0.
        review-created_by  = db_review-created_by.
        review-created_at  = db_review-created_at.
        review-reviewnote  = db_review-reviewnote.
      ELSE.
        review-created_by  = change-last_changed_by.
        review-created_at  = change-last_changed_at.
      ENDIF.

      APPEND review TO reviews.
    ENDLOOP.

    MODIFY zdq_tprdrev FROM TABLE @reviews.

    CLEAR lcl_review_buffer=>changes.
  ENDMETHOD.


  METHOD cleanup.
    " 잠금은 COMMIT / ROLLBACK WORK 시 자동 해제된다.
    CLEAR lcl_review_buffer=>changes.
  ENDMETHOD.

ENDCLASS.
