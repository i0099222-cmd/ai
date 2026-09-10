@EndUserText.label : '배치 실행 잠금 키'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztbatch_lock {

  // 잠금 오브젝트 EZBATCH_LOCK 을 이 테이블 위에 만든다 (키 LOCK_KEY, 모드 E).
  // 잠금은 행 존재와 무관하므로 이 테이블에는 데이터를 넣지 않는다.
  // 테이블이 있는 이유는 잠금 오브젝트가 테이블 위에만 정의되기 때문이다.

  key client   : abap.clnt not null;
  key lock_key : abap.char(60) not null;

}
