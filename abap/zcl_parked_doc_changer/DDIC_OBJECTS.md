# SE11 DDIC 오브젝트 (FM 인터페이스용)

FM 파라미터는 전역 타입만 쓸 수 있으므로, 인터페이스/클래스 타입 대신
DDIC 오브젝트 3개를 만든다. (TABLES 파라미터는 ABAP Cloud에서 호출 불가라 안 씀)

> 데이터 엘리먼트가 확실하지 않으면 SE11에서 BKPF / BSEG 를 열어
> 해당 필드의 데이터 엘리먼트를 그대로 복사해 넣으면 된다.

## 1. 구조 ZSFI_PARKED_HDR (헤더)

| 컴포넌트 | 데이터 엘리먼트 / 타입 | 설명 |
|---|---|---|
| BUKRS  | BUKRS      | 회사코드 |
| BELNR  | BELNR_D    | 전표번호 |
| GJAHR  | GJAHR      | 회계연도 |
| BKTXT  | BKTXT      | 전표헤더텍스트 |
| XBLNR  | XBLNR1     | 참조 (BKPF-XBLNR 과 동일 엘리먼트) |
| CHGFLD | CHAR255 (직접 입력) | 변경할 필드명 목록. 예: `BKTXT,XBLNR` |

## 2. 구조 ZSFI_PARKED_ITM (명세)

| 컴포넌트 | 데이터 엘리먼트 / 타입 | 설명 |
|---|---|---|
| BUZEI  | BUZEI   | 전표라인 |
| POSID  | INT4 (직접 입력) | 개요화면 테이블컨트롤 행번호. 비우면 BUZEI 사용 |
| SGTXT  | SGTXT   | 명세텍스트 |
| ZUONR  | DZUONR  | 지정 |
| HZUON  | HZUON   | 헤더지정 |
| XREF1  | XREF1   | 참조키1 |
| XREF2  | XREF2   | 참조키2 |
| XREF3  | XREF3   | 참조키3 |
| BVTYP  | BVTYP   | 은행유형 |
| HBKID  | HBKID   | 하우스뱅크 |
| ZTERM  | DZTERM  | 지급조건 |
| ZFBDT  | DZFBDT  | 기산일 |
| ZBD1T  | DZBD1T  | 1차 현금할인일수 |
| ZBD1P  | DZBD1P  | 1차 현금할인율 |
| ZBD2T  | DZBD2T  | 2차 현금할인일수 |
| ZBD2P  | DZBD2P  | 2차 현금할인율 |
| ZBD3T  | DZBD3T  | 지급기한 |
| ZLSCH  | DZLSCH  | 지급방법 |
| ZLSPR  | DZLSPR  | 지급보류키 |
| ZBFIX  | ZBFIX   | 지급조건 고정 (BSEG-ZBFIX) |
| RSTGR  | RSTGR   | 사유코드 |
| CHGFLD | CHAR255 (직접 입력) | 변경할 필드명 목록. 예: `SGTXT,ZLSPR` |

> 요청 목록의 ZBD3R / BD1PM 은 표준 필드명 기준으로 각각
> BSEG-ZBD3T(지급기한) / BSEG-ZBD1P(1차 할인율)로 매핑했다.

## 3. 테이블 타입 ZTFI_PARKED_ITM

- 라인 타입: `ZSFI_PARKED_ITM`
- 액세스: Standard Table / 키: Standard(또는 Not Specified)

## 4. ET_MESSAGE 타입

- 표준 테이블 타입 `TAB_BDCMSGCOLL`(라인타입 BDCMSGCOLL)을 쓴다.
- 시스템에 없으면 라인타입 `BDCMSGCOLL` 로 `ZTFI_BDCMSG` 를 하나 만들거나,
  ET_MESSAGE 파라미터 자체를 빼고 FM 본문의 `et_message = lt_message.` 만 지우면 된다.
