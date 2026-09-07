@EndUserText.label : '배치잡 스케줄 등록부'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
@AbapCatalog.tableCategory : #TRANSPARENT
@AbapCatalog.deliveryClass : #A
@AbapCatalog.dataMaintenance : #RESTRICTED
define table ztbatch_sched {

  key client       : abap.clnt not null;
  key run_uuid     : sysuuid_x16 not null;

  // --- 스케줄 대상 -------------------------------------------------------
  @EndUserText.label : 'APJ 잡 템플릿'
  template         : abap.char(60);
  @EndUserText.label : '잡 텍스트 (논리 잡명)'
  jobtext          : abap.char(64);
  // 실행 대상은 TEMPLATE 이 결정한다.
  //   잡 템플릿 -> 잡 카탈로그 엔트리 -> 실행 클래스
  // 별도의 실행 클래스 컬럼을 두지 않는 이유다.

  // 잡 파라미터 값. SCHEDULE_JOB 의 IT_JOB_PARAMETER_VALUE 타입을 그대로
  // /UI2/CL_JSON 으로 직렬화한 것이라, 스케줄할 때 역직렬화만 하면 된다.
  //   [{"name":"P_MODU","t_value":[{"sign":"I","option":"EQ","low":"SD"}]}]
  // 시작일시·반복주기·타임존은 여기 없다. APJ 가 갖고 있으므로 저장하지 않는다.
  @EndUserText.label : '잡 파라미터 값 (JSON)'
  param            : abap.string(0);

  // --- APJ 포인터 --------------------------------------------------------
  // 비어 있으면 아직 스케줄 안 한 상태. 차 있으면 스케줄된 상태.
  // 상태 컬럼 없이 이 두 필드만으로 액션 활성/비활성을 판단한다.
  @EndUserText.label : '백그라운드 잡 이름 (SM37)'
  jobname          : abap.char(32);
  // APJ 잡의 키는 jobname + jobcount 다. 이게 없으면
  // GET_JOB_STATUS / CANCEL_JOB 을 호출할 수 없다.
  @EndUserText.label : '백그라운드 잡 카운트 (SM37)'
  jobcount         : abap.char(8);

  // --- RAP 관리 필드 -----------------------------------------------------
  // 요청자/요청시각은 이 둘이 대신한다.
  // 실행 상태와 로그는 이 테이블에 없다. 별도 로그 기능이 담당한다.
  @Semantics.user.createdBy : true
  created_by            : abp_creation_user;
  @Semantics.systemDateTime.createdAt : true
  created_at            : abp_creation_tmstmp;
  @Semantics.systemDateTime.localInstanceLastChangedAt : true
  local_last_changed_at : abp_locinst_lastchange_tmstmp;

}
