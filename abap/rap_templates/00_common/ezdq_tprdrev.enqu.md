# EZDQ_TPRDREV (잠금 오브젝트) — Case 7 전용

Case 7 은 unmanaged 시나리오이므로 잠금을 직접 구현해야 한다. SE11 / ADT 에서 잠금 오브젝트를 생성한다.

- 이름: `EZDQ_TPRDREV`
- 기본 테이블: `ZDQ_TPRDREV`
- 잠금 모드: `E` (쓰기 잠금)
- 잠금 파라미터: `CLIENT`, `PRODUCT`

생성하면 `ENQUEUE_EZDQ_TPRDREV` / `DEQUEUE_EZDQ_TPRDREV` 함수모듈이 자동 생성되며,
`zbp_dq_ce_custom_ent_action` 의 lock 핸들러가 이를 호출한다.

Case 2 / 3 / 5 는 managed 잠금(`lock master`)을 사용하므로 별도 잠금 오브젝트가 필요 없다.
