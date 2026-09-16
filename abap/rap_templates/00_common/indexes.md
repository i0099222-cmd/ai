# 인덱스

CBO 테이블의 키는 UUID 이므로 업무 키는 인덱스로 유일성을 보장한다.
ADT 의 DDL 테이블 정의에는 인덱스를 적을 수 없으므로 SE11 에서 해당 테이블을 열어 생성한다.

| 테이블 | 인덱스 | 필드 | 유일 |
|--------|--------|------|------|
| `ZDQ_TORDHDR` | `ORD` | `CLIENT`, `ORDERID` | O |

`ZDQ_TORDITM` 은 `ORDERUUID` 가 키의 일부라 헤더 기준 조회에 기본 키가 그대로 쓰인다. 별도 인덱스 불필요.

## 주문번호 채번

템플릿에서는 주문번호 `ORDERID` 를 **사용자가 입력**한다 (`field ( mandatory : create )`).

번호범위로 자동 채번하려면 SNRO 에 번호범위 오브젝트를 만들고
`determination setOrderNumber on save { create; }` 를 추가해
`cl_numberrange_runtime=>number_get( )` 을 호출하면 된다. 템플릿 범위에서는 제외했다.
