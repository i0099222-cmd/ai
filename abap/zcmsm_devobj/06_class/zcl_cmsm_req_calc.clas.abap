"! 요청 C 뷰(ZC_CMSM_Req) 가상 필드 계산
"!   ProcessHidden : 새로 만드는 중이면 X (요청번호는 저장할 때 채번되니 비어 있으면 아직 저장 전)
"!                   → MDE '처리' 섹션 hidden: #( ProcessHidden )
"!   편집(Edit) 중인 기존 요청은 요청번호가 있어서 처리 섹션이 보인다 (담당자가 처리 내용 입력)
CLASS zcl_cmsm_req_calc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_sadl_exit_calc_element_read.

ENDCLASS.


CLASS zcl_cmsm_req_calc IMPLEMENTATION.

  METHOD if_sadl_exit_calc_element_read~get_calculation_info.

    " ProcessHidden 계산에 요청번호가 필요
    IF line_exists( it_requested_calc_elements[ table_line = 'PROCESSHIDDEN' ] ).
      INSERT `REQID` INTO TABLE et_requested_orig_elements.
    ENDIF.

  ENDMETHOD.


  METHOD if_sadl_exit_calc_element_read~calculate.

    DATA lt_req TYPE STANDARD TABLE OF zc_cmsm_req WITH EMPTY KEY.

    lt_req = CORRESPONDING #( it_original_data ).

    LOOP AT lt_req ASSIGNING FIELD-SYMBOL(<ls_req>).
      <ls_req>-ProcessHidden = xsdbool( <ls_req>-ReqId IS INITIAL ).
    ENDLOOP.

    ct_calculated_data = CORRESPONDING #( lt_req ).

  ENDMETHOD.

ENDCLASS.
