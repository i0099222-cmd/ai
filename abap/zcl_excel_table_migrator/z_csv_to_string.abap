*&---------------------------------------------------------------------*
*& Function Module Z_CSV_TO_STRING
*&---------------------------------------------------------------------*
*& 업로드된 파일 바이트를 지정한 SAP 코드페이지로 문자열 변환한다.
*&
*& ABAP Cloud의 CL_ABAP_CONV_CODEPAGE는 한국어 코드페이지를 받지 않는다.
*& 클래식 CL_ABAP_CONV_IN_CE는 SAP 코드페이지 번호를 그대로 받으므로
*& 그 부분만 이 FM으로 분리한다.
*&
*& SE37에서 아래대로 생성:
*&   Function Group : (신규, 예: Z_CSV_UTIL)
*&   Function Module: Z_CSV_TO_STRING
*&
*&   Import 탭 : IV_BYTES    TYPE XSTRING
*&               IV_CODEPAGE TYPE ABAP_ENCODING  DEFAULT '8500'
*&   Export 탭 : EV_TEXT     TYPE STRING
*&   Exceptions 탭 : CONVERSION_FAILED
*&
*&   반드시 Standard ABAP 언어버전 패키지에 두고, SE37 > API State에서
*&   Local API로 Release해야 ABAP Cloud 쪽에서 호출할 수 있다.
*&   (zcl_parked_doc_poster / z_fi_parked_doc_post_bdc 와 같은 패턴)
*&
*&   주요 SAP 코드페이지 번호
*&     4110  UTF-8
*&     8500  한국어 (KSC5601 / CP949 계열)
*&     8000  일본어
*&     8400  중국어 간체
*&---------------------------------------------------------------------*
FUNCTION z_csv_to_string.

  DATA lo_conv TYPE REF TO cl_abap_conv_in_ce.

  TRY.
      lo_conv = cl_abap_conv_in_ce=>create( encoding = iv_codepage
                                            input    = iv_bytes ).

      lo_conv->read( IMPORTING data = ev_text ).

    CATCH cx_root.
      RAISE conversion_failed.
  ENDTRY.

ENDFUNCTION.
