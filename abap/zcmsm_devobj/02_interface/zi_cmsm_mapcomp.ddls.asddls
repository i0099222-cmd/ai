@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: '매핑 구성요소'
// 매핑 한 건 아래의 하위 단위(메서드·필드·폼 등) 매핑. 예: As-Is ZCL_A=>GET_DATA → To-Be ZCL_B=>READ_DATA
define view entity ZI_CMSM_MapComp
  as select from ztcmsm00250
{
      @EndUserText.label: '구성요소 UUID'
  key compuuid           as CompUuid,
      @EndUserText.label: '매핑 UUID'
      mapuuid            as MapUuid,
      @EndUserText.label: 'As-Is 구성요소'
      asiscomp           as AsisComp,
      @EndUserText.label: 'To-Be 구성요소'
      tobecomp           as TobeComp,
      @EndUserText.label: '설명'
      compdesc           as CompDesc,
      locallastchangedat as LocalLastChangedAt
}
