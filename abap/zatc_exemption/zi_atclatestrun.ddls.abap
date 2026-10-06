@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Latest ATC Run per Object'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #X,
  sizeCategory: #S,
  dataClass: #MIXED
}
// 오브젝트마다 가장 최근 ATC 실행이 언제였는지.
//
// ATC 는 실행할 때마다 결과를 새 result 로 쌓고 이전 회차도 남긴다. 필터가 없으면
// 같은 위반이 회차만큼 보이고, 예외 승인 전 회차와 후 회차가 나란히 떠서 예외가
// 안 먹는 것처럼 보인다.
//
// SATC_API_RESULT_HEADERS 의 isactiveresult 를 쓰려 했으나 값이 서지 않는다
// (확인함 - isinbaseline / isactiveresult 는 비어 있고 iscentralrun 만 채워진다).
// 그래서 실행 시각으로 직접 고른다.
//
// 실행 목록은 finding 이 아니라 **실행별 검사 오브젝트(SATC_AC_OBJ_V)** 에서 뽑는다.
// finding 에서 뽑으면 위반 0건으로 끝난 실행이 빠져서, 고친 오브젝트의 예전 위반이
// 계속 최신으로 남는다(확인함). 이 테이블은 위반 유무와 상관없이 검사한 오브젝트를
// 모두 들고 있어서 표준 체크의 고쳐진 위반도 같이 사라진다.
//
//   SATC_AC_OBJ      object_ix -> obj_type / obj_name   (오브젝트 번호표)
//   SATC_AC_OBJ_V    check_run_ix + object_ix           (실행별 검사 오브젝트)
//   SATC_AC_RESULTH  check_run_ix -> display_id         (실행 헤더)
//
// 변형 단위가 아니라 **오브젝트 단위**로 최신을 잡는다. 같은 변형으로 패키지를
// 나눠 돌리는 운영이 흔하고, 변형 단위로 잡으면 먼저 돌린 패키지의 위반이
// 통째로 사라진다.
//
// 변형이 아니라 **체크 그룹(ZTATCCFG)** 으로 묶는다. 같은 오브젝트를 네이밍 변형
// 두 개로 번갈아 돌리면 변형별로 최신이 따로 잡혀서, 고친 뒤 다른 변형으로 돌린
// 실행이 예전 위반을 못 덮었다(확인함). 컨트롤 테이블에 없는 변형으로 돌린 실행은
// 우리 체크를 돌린 게 아니므로 세지 않는다.
define view entity ZI_AtcLatestRun
  as select from satc_ac_obj_v as RunObj

  inner join satc_ac_obj as Obj
    on Obj.object_ix = RunObj.object_ix

  inner join satc_ac_resulth as Run
    on Run.check_run_ix = RunObj.check_run_ix

  // 실행 시각과 변형은 ZI_AtcFinding 과 같은 헤더에서 읽어야 서로 비교가 된다.
  // SATC_AC_RESULTH.display_id 가 SATC_API_RESULT_HEADERS.resultid 다(확인함).
  // obj_type 도 finding 의 objecttype 과 같은 R3TR 타입이다(확인함).
  inner join satc_api_result_headers as Hdr
    on Hdr.resultid = Run.display_id

  inner join ztatccfg as Cfg
    on  Cfg.checkvariant = Hdr.checkvariant
    and Cfg.activeflg    = 'X'

{
  key Obj.obj_type     as ObjectType,
  key Obj.obj_name     as ObjectName,
  key Cfg.checkgroup   as CheckGroup,

      // 🔴 scheduledontimestamp 가 실행 순서를 나타낸다고 본다.
      //   changedontimestamp 가 더 늦게 갱신되는 경우가 있으면 그것으로 바꾼다.
      max( Hdr.scheduledontimestamp ) as LatestRunTs
}
group by
  Obj.obj_type,
  Obj.obj_name,
  Cfg.checkgroup
