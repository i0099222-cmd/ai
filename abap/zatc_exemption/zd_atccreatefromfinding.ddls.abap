@EndUserText.label: 'finding 에서 예외 신청 생성 파라미터'
define abstract entity ZD_AtcCreateFromFinding
{
  // 신청의 출발점이 된 finding. 여기서 패키지/오브젝트를 프리필한다.
  // 라인 정보는 증빙(아이템)으로만 넘기고 판정 키로는 쓰지 않는다.
  @EndUserText.label: '대상 finding'
  FindingUuid : sysuuid_x16;

  // 적용 범위. 선택 가능한 값은 ztatcscope 설정이 정한다.
  @EndUserText.label: '적용범위'
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZI_AtcScopeVH', element: 'ScopeType' }
  }]
  ScopeType : abap.char(3);
}
