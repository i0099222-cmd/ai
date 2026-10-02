@EndUserText.label: 'Pre-Register Target'
// ZD_AtcPreRegister 의 대상 행. 범위는 행이 정한다.
//   Object Name 이 비어 있음 : 패키지 신청(PCKG). Package 필수, * 허용(예: ZSD*).
//   Object Name 이 있음      : 오브젝트 신청(OBJ). Object Type, Check Code 필수,
//                              이름에 * 허용(예: ZCL_CM*). 패키지는 TADIR 에서 파생한다.
define abstract entity ZD_AtcPreRegisterTgt
{
  @EndUserText.label: 'Package'
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZI_AtcPackageVH', element: 'Devclass' }
  }]
  Devclass     : devclass;

  @EndUserText.label: 'Object Type'
  ObjectType   : trobjtype;

  @EndUserText.label: 'Object Name'
  ObjectName   : sobj_name;

  @EndUserText.label: 'Check Message Code'
  @Consumption.valueHelpDefinition: [{
    entity: { name: 'ZI_AtcCheckCodeVH', element: 'CheckCode' }
  }]
  CheckCode    : abap.char(10);

  _PreRegister : association to parent ZD_AtcPreRegister;
}
