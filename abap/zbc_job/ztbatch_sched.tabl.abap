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

  // --- 시작 조건 ---------------------------------------------------------
  // 엔티티 필드로 둔다. save_modified 가 create/update 에서 그대로 읽어
  // APJ 에 넘기므로 별도 버퍼가 필요 없다.
  @EndUserText.label : '즉시 시작'
  start_immediately : abap_boolean;
  // AS-IS 인터페이스 형식 그대로 CHAR(15)(날짜+시각)로 받는다.
  // 어댑터가 숫자만 뽑아 파싱하므로 구분자 유무와 무관하게 동작한다.
  @EndUserText.label : '시작 일시'
  start_datetime    : abap.char(15);
  @EndUserText.label : '타임존'
  timezone          : abap.char(6);

  // 반복 주기. 하나만 채운다. APJ 의 periodic_granularity + periodic_value 로 변환된다.
  prd_mins          : abap.int4;
  prd_hours         : abap.int4;
  @EndUserText.label : '일반복주기'
  prd_days          : abap.int4;
  prd_weeks         : abap.int4;
  @EndUserText.label : '반복주기'
  prd_months        : abap.int4;

  // 종료 일시 - AS-IS 배치잡 close시간. 같은 CHAR(15) 형식.
  // 값이 있으면 APJ END_INFO type = BY, 없으면 NONE(무한 반복)
  @EndUserText.label : '종료 일시 (close)'
  end_datetime      : abap.char(15);

  // --- 제한 조건 (AS-IS SM36 Restrictions) --------------------------------
  // APJ 의 EXCEPTION / MONTH_INFO 로 나뉘어 들어간다. 변환은 어댑터가 한다.
  @EndUserText.label : '공장달력'
  calendar_id       : abap.char(2);
  @EndUserText.label : 'n번째 작업일 (공장근무일수)'
  month_day         : abap.int4;
  @EndUserText.label : '작업일 기준'
  use_working_days  : abap_boolean;
  @EndUserText.label : '월말부터 역순'
  count_from_end    : abap_boolean;
  // 비근무일 처리. D=건너뜀 B=앞당김 A=미룸 N=제한없음 (ZIF_BATCH_JOB=>GC_RESTRICTION)
  @EndUserText.label : '비근무일 처리'
  start_restriction : abap.char(1);

  // --- APJ 포인터 --------------------------------------------------------
  // 비어 있으면 아직 스케줄 안 한 상태. 차 있으면 스케줄된 상태.
  // 상태 컬럼 없이 이 두 필드만으로 액션 활성/비활성을 판단한다.
  @EndUserText.label : '백그라운드 잡 이름 (SM37)'
  jobname          : abap.char(32);
  // APJ 잡의 키는 jobname + jobcount 다. 이게 없으면
  // GET_JOB_STATUS / CANCEL_JOB 을 호출할 수 없다.
  @EndUserText.label : '백그라운드 잡 카운트 (SM37)'
  jobcount         : abap.char(8);

  // --- 잡의 끝 ---------------------------------------------------------
  // APJ 잡 하나 = 이 테이블의 행 하나다. 잡이 끝나면(취소되거나 changeJob
  // 으로 교체되면) 행을 고치지 않고 이 플래그만 세운다. JOBNAME 이 남아
  // 있어야 지나간 잡의 SM37 로그를 찾을 수 있기 때문이다.
  // changeJob 도 APJ 상으로는 취소이므로 여기 걸린다.
  // 끝난 시각은 LOCAL_LAST_CHANGED_AT 이 갖는다 - 닫는 것이 마지막 갱신이다.
  @EndUserText.label : '취소됨'
  is_canceled      : abap_boolean;

  // --- APJ 호출 결과 -----------------------------------------------------
  // 스케줄/취소는 save 시퀀스(saver)에서 일어난다. 그 단계에서는 reported 로
  // 메시지를 돌려줄 수 없어서, APJ 응답을 여기 남긴다.
  // 실패하면 jobname 이 비어 있고 사유가 여기 적힌다.
  @EndUserText.label : 'APJ 응답 메시지'
  message          : abap.char(255);

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
