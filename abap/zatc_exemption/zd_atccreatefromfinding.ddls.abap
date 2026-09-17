@EndUserText.label: 'Create Exemption Request from Finding'
// 조회 화면에서 위반 건을 선택하면 그 finding 의 자연키가 넘어온다.
// 스냅샷 테이블이 없으므로 UUID 대신 자연키를 쓴다.
//
// 라인/인클루드는 파라미터에 없다. 신청서 헤더에 라인을 올리지 않는 것이
// "코드를 고쳐도 예외가 유지되는" 구조의 핵심이기 때문이다.
// 증빙(아이템)에 들어갈 라인 정보는 액션이 finding 을 다시 읽어 채운다.
define abstract entity ZD_AtcCreateFromFinding
{
  @EndUserText.label: 'Check Variant'
  CheckVariant : abap.char(30);

  @EndUserText.label: 'Package'
  Devclass   : devclass;

  @EndUserText.label: 'Object Type'
  ObjectType : trobjtype;

  @EndUserText.label: 'Object Name'
  ObjectName : sobj_name;

  @EndUserText.label: 'Check Class'
  CheckId    : abap.char(30);

  @EndUserText.label: 'Check Message Code'
  MessageId  : abap.char(30);

  // 적용 범위. 선택 가능한 값은 컨트롤 테이블이 정한다.
  @EndUserText.label: 'Object Scope'
  @Consumption.valueHelpDefinition: [{
    entity:            { name: 'ZI_AtcScopeVH', element: 'ScopeType' },
    additionalBinding: [{ localElement: 'CheckVariant', element: 'CheckVariant' }]
  }]
  ScopeType  : abap.char(4);
}
