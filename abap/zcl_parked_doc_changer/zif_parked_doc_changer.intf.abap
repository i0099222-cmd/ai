"! 임시전표(파킹 문서) 수정(FBV2 BDC)용 타입 정의.
"! 수정 허용 필드는 아래 구조에 정의된 것만이며,
"! 여기에 없는 필드는 Z_FI_PARKED_DOC_CHANGE_BDC 에서 화면에 전송되지 않는다.
INTERFACE zif_parked_doc_changer
  PUBLIC.

  "! 처리 결과 메시지 타입 상수
  CONSTANTS:
    BEGIN OF gc_msgtype,
      success TYPE symsgty VALUE 'S',
      error   TYPE symsgty VALUE 'E',
    END OF gc_msgtype.

  "! 처리 결과 메시지 텍스트 상수
  CONSTANTS:
    gc_text_success TYPE string VALUE `Document has been updated`,
    gc_text_error   TYPE string VALUE `Failed to update the document`.

*----------------------------------------------------------------------*
* 헤더
*----------------------------------------------------------------------*
  "! 헤더 필드별 변경 지시자.
  "! abap_true 로 표시한 필드만 화면에 전송된다(공란 지정 = 값 삭제).
  TYPES:
    BEGIN OF ty_header_upd,
      bktxt TYPE abap_bool,
      xblnr TYPE abap_bool,
    END OF ty_header_upd.

  "! 수정 대상 임시전표 키 + 수정할 헤더 필드
  TYPES:
    BEGIN OF ty_header,
      bukrs TYPE bkpf-bukrs,
      belnr TYPE bkpf-belnr,
      gjahr TYPE bkpf-gjahr,
      bktxt TYPE bkpf-bktxt,
      xblnr TYPE bkpf-xblnr,
      "! 비워두면 "값이 채워진 필드만 변경" 으로 동작한다.
      upd   TYPE ty_header_upd,
    END OF ty_header.

*----------------------------------------------------------------------*
* 명세(라인 아이템)
*----------------------------------------------------------------------*
  "! 명세 필드별 변경 지시자
  TYPES:
    BEGIN OF ty_item_upd,
      sgtxt TYPE abap_bool,
      zuonr TYPE abap_bool,
      hzuon TYPE abap_bool,
      xref1 TYPE abap_bool,
      xref2 TYPE abap_bool,
      xref3 TYPE abap_bool,
      bvtyp TYPE abap_bool,
      hbkid TYPE abap_bool,
      zterm TYPE abap_bool,
      zfbdt TYPE abap_bool,
      zbd1t TYPE abap_bool,
      zbd1p TYPE abap_bool,
      zbd2t TYPE abap_bool,
      zbd2p TYPE abap_bool,
      zbd3t TYPE abap_bool,
      zlsch TYPE abap_bool,
      zlspr TYPE abap_bool,
      zbfix TYPE abap_bool,
      rstgr TYPE abap_bool,
    END OF ty_item_upd.

  "! 수정할 명세 1건.
  "! 요청 필드 목록의 ZBD3R / BD1PM 은 표준 필드명 기준으로
  "! 각각 BSEG-ZBD3T(3차 기한) / BSEG-ZBD1P(1차 할인율)로 매핑했다.
  TYPES:
    BEGIN OF ty_item,
      buzei TYPE bseg-buzei,
      "! 개요화면 테이블컨트롤의 행 번호. 미지정 시 BUZEI 를 행 번호로 사용한다.
      posid TYPE i,
      sgtxt TYPE bseg-sgtxt,
      zuonr TYPE bseg-zuonr,
      hzuon TYPE bseg-hzuon,
      xref1 TYPE bseg-xref1,
      xref2 TYPE bseg-xref2,
      xref3 TYPE bseg-xref3,
      bvtyp TYPE bseg-bvtyp,
      hbkid TYPE bseg-hbkid,
      zterm TYPE bseg-zterm,
      zfbdt TYPE bseg-zfbdt,
      zbd1t TYPE bseg-zbd1t,
      zbd1p TYPE bseg-zbd1p,
      zbd2t TYPE bseg-zbd2t,
      zbd2p TYPE bseg-zbd2p,
      zbd3t TYPE bseg-zbd3t,
      zlsch TYPE bseg-zlsch,
      zlspr TYPE bseg-zlspr,
      zbfix TYPE bseg-zbfix,
      rstgr TYPE bseg-rstgr,
      "! 비워두면 "값이 채워진 필드만 변경" 으로 동작한다.
      upd   TYPE ty_item_upd,
    END OF ty_item,
    tt_item TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

*----------------------------------------------------------------------*
* 결과
*----------------------------------------------------------------------*
  "! CALL TRANSACTION 'FBV2' ... MESSAGES INTO 결과 메시지 테이블
  TYPES tt_message TYPE STANDARD TABLE OF bdcmsgcoll WITH DEFAULT KEY.

  "! 전표 1건 수정 결과
  TYPES:
    BEGIN OF ty_result,
      bukrs       TYPE bkpf-bukrs,
      belnr       TYPE bkpf-belnr,
      gjahr       TYPE bkpf-gjahr,
      messagetype TYPE symsgty,
      messagetext TYPE string,
      t_message   TYPE tt_message,
    END OF ty_result.

  "! 임시전표 1건의 헤더/명세 필드를 수정한다(FBV2 BDC 호출).
  METHODS change
    IMPORTING
      is_header        TYPE ty_header
      it_item          TYPE tt_item OPTIONAL
    RETURNING
      VALUE(rs_result) TYPE ty_result.

ENDINTERFACE.
