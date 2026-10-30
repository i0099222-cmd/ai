"=====================================================================
" zcl_cm_if_communication=>run 에 추가할 부분 (기존 공통 래퍼 수정)
"=====================================================================

" 1. 파라미터 추가
"    IMPORTING ...
"              it_multipart TYPE zcl_cm_multipart_util=>tt_part OPTIONAL


" 2. body를 세팅하는 부분을 분기
IF it_multipart IS NOT INITIAL.
  lo_request->set_content_type( 'multipart/form-data' ).          " boundary 자동

  LOOP AT it_multipart INTO DATA(ls_part).
    DATA(lo_part) = lo_request->set_multipart( ).                  " F2로 시그니처 확인

    IF ls_part-filename IS INITIAL.
      " 텍스트 파트
      lo_part->set_header_field( i_name  = 'Content-Disposition'
                                 i_value = |form-data; name="{ ls_part-name }"| ).
      lo_part->set_text( ls_part-text ).
    ELSE.
      " 파일 파트
      lo_part->set_header_field( i_name  = 'Content-Disposition'
                                 i_value = |form-data; name="{ ls_part-name }"; filename="{ ls_part-filename }"| ).
      lo_part->set_content_type( COND #( WHEN ls_part-content_type IS NOT INITIAL THEN ls_part-content_type
                                         ELSE zcl_cm_multipart_util=>get_mime_type( ls_part-filename ) ) ).
      lo_part->set_binary( ls_part-binary ).
    ENDIF.
  ENDLOOP.
ELSE.
  " 기존 JSON body 처리 (그대로)
ENDIF.

" 3. 래퍼가 요청 body를 로그 테이블에 남긴다면,
"    multipart일 때는 파일 바이너리는 빼고 필드명/파일명만 기록할 것
