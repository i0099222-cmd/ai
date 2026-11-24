@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'CDS가 바로 쓰는 오브젝트'
// [Standard ABAP 패키지 · Cloud 개발용 릴리즈(C1)] 통합 조회 UNION(ZI_CMSM_DevObject)의 소스 줄용.
//   DDL 소스(DdlName) → 그 소스가 바로(1단계) 쓰는 테이블·CDS·DDIC 뷰(UsedName)
//   select from·join·연관을 다 포함하고 쓰는 방식은 구분하지 않는다
//   캐스트에 쓴 데이터 요소 같은 것은 TADIR 오브젝트 유형(TABL·DDLS·VIEW만)으로 걸러 낸다
// 릴리즈: ADT → Properties → API State → Use in Cloud Development = Released
// 기술부채로 등록: 개발 오브젝트 ZI_CMSM_DDLUSE, 부채 구분 TAB(미릴리즈 테이블 조회), Debt Level C, 래핑 여부 W
define view entity ZI_CMSM_DdlUse
  as select from ZI_CMSM_DdlUseRaw as Use
    inner join   tadir             as Obj on  Obj.pgmid    = 'R3TR'
                                          and Obj.obj_name = Use.UsedName
{
      @EndUserText.label: '쓰는 CDS'
  key Use.DdlName,
      @EndUserText.label: '쓰이는 오브젝트'
  key Use.UsedName,
      @EndUserText.label: '오브젝트 유형'
      cast( case Obj.object
              when 'TABL' then 'TABLE'
              when 'DDLS' then 'CDS'
              else ''
            end as abap.char( 10 ) ) as ObjType
}
where
  (    Obj.object  = 'TABL'
    or Obj.object  = 'DDLS'
    or Obj.object  = 'VIEW' )
  and  Obj.delflag = ''
